# universal-wallet PR #707 — code review response (2026-09-16)

**PR under discussion:** [abcfinancial2/universal-wallet #707](https://github.com/abcfinancial2/universal-wallet/pull/707) "Gate the agreement-less MEMBER deduplication key fallback behind a LaunchDarkly flag", base `main`, head `prospect-wallet/review-fixes-dedup-flag` @ `51d71a05` (one commit on top of `8461a012`, the squash of #705). Flag: `universal-wallet-PROSPECT-enable-agreement-less-member-deduplication` (`LaunchDarklyFeatureFlagKey.ENABLE_AGREEMENT_LESS_MEMBER_DEDUPLICATION`), default off.
**Reviewer points (received outside GitHub; the PR has no review comments as of this writing):**
1. "A PROSPECT MEMBER must not have metadata with the key `dt_agreementNumber`; otherwise, it fails. In other words, this needs to be controlled on the client side when creating the member (out of scope this PR)."
2. "`EntryOwnerEntryUserByMetaResolver`: the `resolverPairByMetadata` method must not resolve a pair for a MEMBER with `dt_memberType == PROSPECT`."

**Method:** the PR diff and every class on the dedup path were read at `51d71a05` in the worktree `wallet-repos/universal-wallet-review-fixes` (`DeduplicationJobKeyByWalletEntryOwnerCalculator`, `WalletEntryDeduplicationJobSchedulerService`, `WalletEntryDeduplicationJob`, `DeduplicationService`, `DeduplicationHandlerFactory`, the `common/resolver/multi` facade, factory and five implementations, `WalletEntryOwnerRepository`, `WalletEntryOwnerValidator`, `WalletEntryOwnerHelper`, `WalletEntryOwnerMetadataMapper`, `DtMemberMigrationService`, `DtMemberTransferService`), together with the pin tests and fixtures, the Online Join BFF writer (`online-join-bff` `services/shortTermPass/wallet.ts` and its platform adapter), the wallet-account-sync prospect lane at `7054f24` (`MemberClassifier`, `RoutableComposite`, `ProspectPaymentMethodChangedEventProcessor`, `ProspectBackfillDryRunService`, `MemberMetadataUtil`), and the prior art (`prospects1/docs/semantic-index/themes/agreement-number-and-prosp.md` hazards #4 and #10, `themes/identity-by-member-id.md`, `repos/universal-wallet/identity/owner.md`, `repos/universal-wallet/walletentry/deduplication.md`, `prospects1/docs/prd/prospect-wallet-decisions.md` D-02 clarifications, and the 2026-09-15 review response, points 1–4). `AbstractFactory.getService` was checked in `common-core-63.18.0.jar` (`javap`). Paths below are relative to `universal-wallet/src/main/java/com/abcfinancial/api/universalwallet/` unless stated; `L` numbers are at `51d71a05`.

**Disposition key:** **Accept** = fix as asked · **Accept, adjusted** = fix, but not exactly as proposed · **Clarify** = the code is right for a reason the review could not see; document it · **Push back** = keep the behaviour, with the reason.

## Summary table

| # | Point | Factual status | Disposition | Effort |
|---|---|---|---|---|
| 1 | A PROSPECT MEMBER with `dt_agreementNumber` fails; the client must not write it | **Correct.** Without `dt_memberOrdinal` the calculator throws `deduplication-job.member`; with an ordinal it takes the agreement key and can debounce under, or pair with, another person's owner. The PR only logs a WARN for that shape. | **Clarify + Accept, adjusted.** Client side confirmed (BFF allowlist forbids the key; backfill and sync lane never write it). Server side: make the calculator treat the PROSPECT marker as "agreement-less" (same rule as point 2), keep the WARN; **decline** an API-level rejection of the key (merge-only metadata PUT and the conversion write make it unsafe today; revisit with the Phase 4 conversion contract). | S |
| 2 | `resolverPairByMetadata` must not resolve a pair for `dt_memberType == PROSPECT` | **Partially correct as a description, correct as a requirement.** For the contract shape (no agreement) no pair is resolved, pinned by tests. For a PROSPECT-marked owner that also carries `dt_agreementNumber` and `dt_memberOrdinal=0`, `MemberEntryOwnerEntryUserByMetaResolver` *does* resolve the PAYOR/BILLING_ACCOUNT pair of whoever owns that agreement. | **Accept, adjusted.** Add the veto in `MemberEntryOwnerEntryUserByMetaResolver.resolveOwnerUserPair` (not in `accepts`, not in the facade), unflagged, **paired with** writing `dt_memberType=MEMBER` wherever universal-wallet stamps agreement metadata onto a MEMBER owner (`DtMemberMigrationService`, `DtMemberTransferService`), so a converted prospect cannot keep a stale marker. Record the D-02 amendment: the marker becomes a *veto*, never a *selector*. | S |

Both points reduce to one rule that the PR should state and pin: **a MEMBER owner marked `dt_memberType=PROSPECT` never takes the agreement path** — no agreement-based job key, no owner pair — and **every writer that stamps agreement keys on a MEMBER owner flips the marker to `MEMBER` in the same write**.

---

## 1. A PROSPECT MEMBER must not have `dt_agreementNumber`; otherwise it fails (client-side control, out of scope)

### What the code does

The job key is computed by `DeduplicationJobKeyByWalletEntryOwnerCalculator.calculate` (`scheduler/job/data/walletentry/deduplication/util/DeduplicationJobKeyByWalletEntryOwnerCalculator.java`):

- `L40-41`: `getDtAgreementNumber` (`L85-92`) looks for a non-blank `dt_agreementNumber` (`WalletConstants.MEMBER_METADATA_KEY_AGREEMENT_NUMBER`, `common/WalletConstants.java:L15`). If present the owner is on the **agreement path** regardless of owner type or marker.
- `L43-49`: on the agreement path, if the owner also has `dt_memberType=PROSPECT` (`WalletConstants.java:L19-20`) the calculator logs `Prospect owner has agreement metadata; using agreement deduplication key` and **continues** on the agreement path. This WARN is the only thing the marker does here; it is telemetry, as recorded in D-02.
- `L51-55`: the agreement path requires a non-blank `dt_memberOrdinal`; otherwise `ErrorResponse(NotFoundResponseError("deduplication-job.member", "{type}: {id} does not have ordinal metadata"))` is thrown.
- `L57-60`: key `DEDUPL_ACCOUNT_<agreementNumber>_<ordinal>`.
- `L62-82` (agreement absent): PAYOR gets `DEDUPL_ACCOUNT_PAYOR_<id>` (`L64-70`); MEMBER throws the pre-existing `deduplication-job.member` "does not have agreementNumber metadata" when the flag is off (`L72-76`, added by this PR) and gets `DEDUPL_ACCOUNT_MEMBER_<id>` when it is on (`L78-81`).

What "fails" means concretely for a PROSPECT-marked MEMBER owner that carries `dt_agreementNumber`:

| Shape | Calculator | Downstream |
|---|---|---|
| `dt_memberType=PROSPECT` + `dt_agreementNumber`, **no** `dt_memberOrdinal` (the shape a client would produce by adding the one key to the contract set) | WARN, then **throws** `deduplication-job.member` "does not have ordinal metadata" (`L51-55`) | `WalletEntryDeduplicationJobSchedulerService.scheduleJob(WalletEntryOwner)` catches every exception and `log.error`s (`scheduler/job/data/walletentry/deduplication/WalletEntryDeduplicationJobSchedulerService.java:L110-113`); the entry-created listener is `@TransactionalEventListener` and swallows too (`.../event/WalletEntryDeduplicationEventListener.java`). The card is saved, dedup is never scheduled, every add-card logs an error. This is the state hazard #10 describes, and it is independent of the new flag. |
| `dt_memberType=PROSPECT` + `dt_agreementNumber` + `dt_memberOrdinal` | WARN, key `DEDUPL_ACCOUNT_<agr>_<ordinal>` (`L57-60`) | If another owner already has a job under that key (the real member whose agreement it is, or another prospect sharing a placeholder such as `PROSP`), `scheduleJobForOneWalletEntryOwnerInternal` only **reschedules the existing trigger** (`SchedulerService:L195-203`); the job detail keeps the first owner's `OWNER_ID` (`L208-219`), so the prospect's own dedup never runs (hazard #4). With ordinal `0` the resolver in point 2 additionally pairs the prospect with that agreement's PAYOR. |
| `dt_memberType=PROSPECT`, **no** agreement (the D-02 contract) | flag off: throws as before; flag on: `DEDUPL_ACCOUNT_MEMBER_<id>` | Correct; this is what the PR gates. Pinned by `DeduplicationJobKeyByWalletEntryOwnerCalculatorTest` rows `prospect marker only, flag on/off` and `WalletEntryDeduplicationJobSchedulerTest.testAddProspectCardSchedulesOneDeduplicationJob` (`src/test/groovy/.../scheduler/job/walletentry/deduplication/WalletEntryDeduplicationJobSchedulerTest.groovy:L92-100`). |

The PR's own data provider already pins the first two rows as *current* behaviour (`prospect with agreement` → agreement key + WARN; `prospect with agreement without ordinal` → ordinal error + WARN), i.e. the PR consciously keeps the agreement path for a mis-stamped prospect.

Nothing on the server rejects the key. Owner creation validates only externalId+type uniqueness and `locationId` (`owner/validator/WalletEntryOwnerValidator.java:L39-51`); `PUT /wallet-entry-owner/{id}/metadata` (`owner/WalletEntryOwnerController.java:L244-257` → `WalletEntryOwnerService.updateMetadata:L133-141`) accepts any map; `WalletEntryOwnerMetadataMapper.mapMetadata` (`owner/mapper/WalletEntryOwnerMetadataMapper.java:L53-71`) **updates existing keys and adds new ones, and never removes a key**.

### Is the concern already handled on the client side?

Yes, for every writer that exists today:

- **Online Join BFF (Day Pass checkout)** — `prospects-ui/repos/online-join-bff/src/services/shortTermPass/wallet.ts`: `OWNER_METADATA_ALLOWLIST = ['dt_clubNumber','dt_memberId','dt_vpdId','dt_memberType']` and `OWNER_METADATA_FORBIDDEN = ['dt_agreementNumber','dt_memberNumber','dt_memberOrdinal']` (`L99-100`); `ownerMetadataFor` builds exactly `{dt_clubNumber, dt_memberId, dt_vpdId?, dt_memberType:'PROSPECT'}` and strips anything outside the allowlist (`L107-117`); `saveCardToWallet` passes that map to `createOwner` (`L203-212`) and reuses an existing owner rather than touching its metadata. Entry metadata is `oj_*` only (`ENTRY_METADATA_ALLOWLIST`, `L140-144`, `L152-167`). The platform adapter forwards the maps unchanged (`services/shortTermPass/adapters/platform/wallet.ts:L131-137`, `L158-173`). The rule and the hazard numbers are in the code comment (`L93-97`). The writer is dark behind `STP_WALLET_WRITES`.
- **Prospect backfill (wallet-account-sync)** — `ProspectBackfillDryRunService` writes nothing (dry-run), and decision (g) in `prospect-wallet-decisions.md` forbids reusing `MemberMetadataUtil.getDtMemberMetadata`, which synthesizes `dt_agreementNumber = club + memberNumber` (`wallet-account-sync/.../sync/dtwallet/util/MemberMetadataUtil.java:L13, L22`). The execution-phase writer must keep the four-key contract.
- **Prospect sync lane (wallet-account-sync)** — `ProspectPaymentMethodChangedEventProcessor` mirrors payment-method rows into WAS's own tables; it imports wallet-entry enums only and has no owner or metadata client. `MemberClassifier` only *reads* `dt_memberType` for the `match/mismatch/absent` counter (`notification/wallet/prospect/MemberClassifier.java:L15-23, L70-85`; `RoutableComposite.java:L91`).
- **Existing DT writers** (`DtMemberMigrationService`, `DtMemberTransferService`, `MemberWalletEntryOwnerPairResolver`, WAS `MemberMetadataUtil`) write `dt_agreementNumber` only for real agreements and never write `dt_memberType` at all (see the coherence note under point 2).

### Assessment

**Correct.** The reviewer's fact holds for both shapes (throw without ordinal; wrong key and possible cross-person pairing with ordinal), and the sentence "controlled on the client side" is exactly what the BFF does. Two refinements:

1. The invariant is not "a prospect never has an agreement number" but "**the PROSPECT marker and agreement keys never coexist**". After conversion the same owner legitimately gets `dt_agreementNumber`; D-02 says conversion "stamps the agreement keys and sets `MEMBER`". The server-side risk is therefore the *stale marker*, not the key itself.
2. The server currently *chooses the agreement path* for a mis-stamped prospect and only warns. Given point 2 is being accepted (the marker vetoes a pair), the calculator should apply the same veto so the dedup path has one rule; otherwise a mis-stamped prospect would get an agreement-based key but a MEMBER_ONLY handler, which is an inconsistent state that is hard to reason about in logs.

### Risk if unaddressed

Today: none in production — no prospect owner exists in any environment (BFF dark, backfill dry-run, flag off) and no writer produces the shape. After enablement: a client bug that adds `dt_agreementNumber` to a prospect would (a) silently stop dedup for that person with an error log per card, or (b) with an ordinal, debounce the prospect under a real member's job and, with ordinal `0`, run the MEMBER_AND_PAYOR handler across two people (assignments aligned onto the other person's BILLING_ACCOUNT user; `deduplication/handler/impl/DeduplicationMemberAndPayorHandler.java`). Rejecting at the API would be the strongest guard but see below for why it is not safe yet.

### Recommended response

**Clarify** the client half and **accept, adjusted** the server half:

- Client: no change; confirm the allowlist/forbidden list above.
- Server, this PR: in `calculate`, evaluate the PROSPECT marker **before** `getDtAgreementNumber` and, when present, skip the agreement path (fall through to the existing agreement-less branch: PAYOR id key / flag-gated MEMBER id key / flag-off throw). Keep the WARN when an agreement is also present so the mis-stamp stays visible. Member behaviour is unchanged in both flag states because no member carries the marker.
- Server, follow-up (decline for now): an API-level rule "reject `dt_memberType=PROSPECT` together with `dt_agreementNumber`/`dt_memberNumber`/`dt_memberOrdinal`" on owner and authorized-user create and metadata update. Not in this PR because (i) `mapMetadata` is merge-only, so reverse conversion (set `PROSPECT`, drop the agreement keys) has no way to drop keys and would be rejected by that rule; (ii) `DtMemberMigrationService` and `DtMemberTransferService` stamp agreement keys without touching the marker (see point 2), so a converted prospect would trip the rule from inside universal-wallet. It needs the Phase 4 conversion contract (a metadata delete path and the marker flip) first. Track it in the readiness register.

**Proposed PR reply**

> Agreed on the fact: a PROSPECT-marked MEMBER that carries `dt_agreementNumber` either throws `deduplication-job.member` (no `dt_memberOrdinal`, calculator L51-55) or takes the agreement key (L57-60) and can be debounced under, or paired with, the owner of that agreement. The client never writes it: the Online Join BFF builds owner metadata from an allowlist of exactly `dt_clubNumber`, `dt_memberId`, `dt_vpdId`, `dt_memberType` and strips everything else (`services/shortTermPass/wallet.ts` L99-117); entry metadata is `oj_*` only; the backfill uses the same four keys and the sync lane never writes owner metadata.
>
> On the server I will make the calculator consistent with your point 2 in this PR: a PROSPECT-marked owner never takes the agreement path (marker checked before the agreement lookup; WARN kept when an agreement is present). With the flag off that owner throws the pre-existing error, with the flag on it gets the id-based key. Member behaviour is unchanged since no member carries the marker.
>
> I am not adding an API-level rejection of `dt_agreementNumber` on a PROSPECT here: metadata PUT is merge-only (cannot drop keys) and `DtMemberMigrationService` / `DtMemberTransferService` stamp agreement keys without flipping the marker, so conversion would trip it from inside the service. That belongs with the Phase 4 conversion contract; I have added it to the readiness register.

---

## 2. `EntryOwnerEntryUserByMetaResolver.resolverPairByMetadata` must not resolve a pair for a MEMBER with `dt_memberType == PROSPECT`

### What the code does

`EntryOwnerEntryUserByMetaResolver.resolverPairByMetadata` (`common/resolver/multi/EntryOwnerEntryUserByMetaResolver.java:L24-45`) is a type-agnostic facade: it logs, delegates to `factory.getService(genericOwner).resolveOwnerUserPair(genericOwner)` (`L52`) and records a timer. `EntryOwnerEntryUserByMetaResolverFactory` extends `AbstractFactory` (`common-core-63.18.0`), whose `getService` collects every `Acceptor.accepts(owner) == true` and **requires exactly one** (`ServiceValidator.validate`) — so a guard placed in `accepts` would leave a PROSPECT owner with no acceptor and make the facade throw, not return "no pair". The guard has to live inside an implementation's `resolveOwnerUserPair`.

Acceptors and what they do for a MEMBER owner:

- `MemberEntryOwnerEntryUserByMetaResolver` (`common/resolver/multi/impl/MemberEntryOwnerEntryUserByMetaResolver.java`) accepts **every** MEMBER (`L107-111`). `resolveOwnerUserPair`:
  - `L48-56`: not primary (`dt_memberOrdinal != "0"`, predicate `L37-38`) → identity result, `Optional.empty()`.
  - `L58-68`: no non-blank `dt_agreementNumber` (predicate `L39-40`) → WARN, identity result, `Optional.empty()`. **This is the branch every contract-shaped prospect takes.**
  - `L70-71`: otherwise `ownerRepository.findPrimaryOwnerByAgreementNumberNoAgreementInactiveMetadata(PAYOR, agreement)` — JPQL joining `dt_agreementNumber = :agreementNumber` **and** `dt_memberOrdinal = '0'`, excluding `dt_agreementStatus = INACTIVE` (`owner/repository/WalletEntryOwnerRepository.java:L27-32`).
  - `L72-79`: no PAYOR → no pair. `L81-87`: more than one → `WalletEntryOwner.not-unique` (404). `L89-104`: one PAYOR → pair with that PAYOR plus the unique BILLING_ACCOUNT user found by the same agreement (`L113-133`).
  - The marker `dt_memberType` is **not read anywhere in this class**, nor in `PayorEntryOwnerEntryUserByMetaResolver`, `PayorEntryOwnerEntryUserByEmptyMetaResolver`, `owner/resolver/impl/MemberWalletEntryOwnerPairResolver` or the repository. The only production reader of the marker in universal-wallet is the calculator WARN (`grep MEMBER_METADATA_KEY_MEMBER_TYPE src/main`).
- `PayorEntryOwnerEntryUserByMetaResolver` (PAYOR with agreement, `L87-94`) does the reverse lookup `findPrimaryOwnerByAgreementNumberNoAgreementInactiveMetadata(MEMBER, agreement)` (`L51-52`): zero → `wallet-entry.deduplication.billing.no-active-member`; more than one → `WalletEntryOwner.not-unique` (`L53-66`).

Callers, all of which act on the returned pair: `WalletEntryDeduplicationJob.executeInternal` (`scheduler/job/data/walletentry/deduplication/WalletEntryDeduplicationJob.java:L114-126`), the manual endpoint `DeduplicationService.deduplicateOwnerWalletEntry` (`deduplication/DeduplicationService.java:L49-59`), and `WalletEntryDeduplicationJobSchedulerService.groupWalletEntryOwners` which collapses a PAYOR onto its paired MEMBER (`SchedulerService:L300-334`). `DeduplicationHandlerFactory.getInstance` picks `MEMBER_AND_PAYOR` whenever the right side is present (`deduplication/handler/DeduplicationHandlerFactory.java:L35-38`), else `MEMBER_ONLY` / `PAYOR_ONLY` (`L40-50`).

Behaviour by shape for a MEMBER owner with `dt_memberType=PROSPECT`:

| Shape | `resolverPairByMetadata` | Handler |
|---|---|---|
| No `dt_agreementNumber` (contract) | no pair (`L58-68`) | MEMBER_ONLY |
| `dt_agreementNumber`, no ordinal / ordinal ≠ 0 | no pair (`L48-56`) | MEMBER_ONLY |
| `dt_agreementNumber` + `dt_memberOrdinal=0`, PAYOR with that agreement exists | **pair with that PAYOR and its BILLING_ACCOUNT user** (`L89-104`) | MEMBER_AND_PAYOR across two identities |
| same, no such PAYOR | no pair (`L72-79`) | MEMBER_ONLY |
| PAYOR side: a PROSPECT-marked MEMBER shares the real member's agreement + ordinal 0 | `PayorEntryOwnerEntryUserByMetaResolver` finds two MEMBER owners → **throws `WalletEntryOwner.not-unique`** (`L60-66`) | none; the real member's payor dedup fails (`groupWalletEntryOwners` propagates; `scheduleJob(UUID)` logs) |

Pins today (Sprint 0001 A4): `EntryOwnerEntryUserByMetaResolverTest.prospectsDoNotContaminatePrimaryMemberAgreementPair` (`src/test/groovy/.../common/resolver/multi/EntryOwnerEntryUserByMetaResolverTest.groovy:L31-58`) asserts, on the fixture `src/test/resources/sql/owner/init.prospect-isolation.sql` (two prospects with exactly the four contract keys next to a real primary MEMBER/PAYOR pair on agreement `1111199999`), that the member resolver accepts a prospect, the payor resolver does not, `resolveOwnerUserPair(prospect).right` is empty, the facade returns the prospect as left with no right, and the agreement JPQL still returns only the real member. `WalletEntryOwnerPairResolverTest:L77-86` and `DeduplicateOwnerWalletEntryTest:L109-123` cover the owner-side resolver and the MEMBER_ONLY dedup of a prospect. **None of these pins covers a PROSPECT-marked owner that also carries agreement metadata**, and the 2026-09-15 response (point 2) argued the property "by construction" for the contract shape only.

### Assessment

**Partially correct as a description, correct as a requirement.** The reviewer's sentence is true for every shape a compliant writer can produce, and pinned. It is false for the contaminated shape (`PROSPECT` + agreement + ordinal 0), where the resolver resolves the pair of whoever owns that agreement — the worst outcome on the whole dedup path. The 2026-09-15 position ("correct by construction, no resolver change") relied on the metadata contract being honoured by every writer; the reviewer is asking for the property to hold even when it is not. That is a reasonable ask for a merge that touches identities, and the veto is cheap.

One consequence must be handled or the veto creates a new problem. The only realistic producer of "PROSPECT marker next to agreement keys" is not a buggy client but **universal-wallet itself at conversion**: `DtMemberMigrationService.migrate` builds `{dt_clubNumber, dt_memberNumber, dt_memberOrdinal, dt_agreementNumber}` (`dt/migration/DtMemberMigrationService.java:L109-115`) and calls `ownerHelper.getOrCreateLocationWalletEntryOwner(..., dtMemberMetadata, true)` (`L120`), which **merges** into the existing metadata (`owner/helper/WalletEntryOwnerHelper.java:L47-57` → `mapMetadata`, update-or-add, never delete). `DtMemberTransferService.getMetadata` (`dt/transfer/member/DtMemberTransferService.java:L294-297`) rewrites the same four keys. Neither touches `dt_memberType`. So a Day Pass prospect who later joins and is migrated through the membership-created hook (hazard #11) ends up as a real member with a real agreement **and a stale `dt_memberType=PROSPECT`**. With the veto in place that member would be silently downgraded to MEMBER_ONLY dedup (payor-side duplicates not merged, assignments not aligned) — a regression for a paying member that no log would explain. D-02 already says conversion "sets `MEMBER`"; the code that performs conversion in this service does not yet do it. The veto therefore has to land together with the marker flip in those two writers (three lines), and Phase 4's in-place conversion must do the same.

Should the guard be behind `ENABLE_AGREEMENT_LESS_MEMBER_DEDUPLICATION`? **No.** The flag's meaning is "allow the id-based key for an agreement-less MEMBER". The veto is a fail-safe in the opposite direction: gating it would make the *unsafe* behaviour (a mis-stamped prospect pairing with another person) the default-off state. For members nothing changes because no member carries the marker (D-02 "no service writes `dt_memberType` for existing members"; the flip proposed here writes `MEMBER`, which the veto ignores). Leave it unflagged.

Where exactly: `MemberEntryOwnerEntryUserByMetaResolver.resolveOwnerUserPair`, first statement, returning the same identity result the agreement-less branch returns (`L63-67`, with `resolvedMemberEntryUserEntryOwnerExternalId` set — `DeduplicationMemberHandler` needs it to find the MEMBER authorized user). Condition: `dt_memberType` equals `PROSPECT` (exact, case-sensitive, matching the calculator at `L43-45`). Log at WARN only when an agreement is also present (the contaminated shape); the contract shape stays at the existing debug/warn level. Not in `accepts` (factory would find no acceptor), not in the facade (the identity result is the member implementation's shape; the facade is type-agnostic). Optional symmetry, recommended in the same change because it protects the *existing member* rather than the prospect: in `PayorEntryOwnerEntryUserByMetaResolver.resolveOwnerUserPair` filter PROSPECT-marked owners out of `memberOwners` before the size checks (`L52-66`), so a mis-stamped prospect cannot turn the real member's payor dedup into `not-unique`. `owner/resolver/impl/MemberWalletEntryOwnerPairResolver` (association-time pairing via RCM, `L49-134`) has the same exposure and would take the same three-line veto; it is outside the reviewer's sentence, so list it and let the reviewer decide whether to include it now.

This amends D-02's "no lane, resolver or job key is chosen from the marker" to: **the marker may veto (remove a pair, force the agreement-less key) but never select** (it never creates a pair, never routes a lane, never replaces the Oracle classification in wallet-account-sync). Classification in WAS is unchanged.

### Risk if unaddressed

Cross-identity merge: a PROSPECT-marked owner carrying a real member's agreement number with ordinal 0 is paired with that member's PAYOR; `DeduplicationMemberAndPayorHandler` moves assignments to survivors and aligns the BILLING_ACCOUNT user's assignments to the prospect's surviving card if the tokens match, and inactivates or disassociates losers across both owners. Reverse direction: the real member's payor-side dedup throws `not-unique` and stops. Both require a writer to violate the contract (none does today) — but the fix is small and the blast radius is two people's payment methods.

### Recommended response

**Accept, adjusted**: add the veto in `MemberEntryOwnerEntryUserByMetaResolver.resolveOwnerUserPair` (unflagged), the symmetric filter in `PayorEntryOwnerEntryUserByMetaResolver`, and the `dt_memberType=MEMBER` write in `DtMemberMigrationService` and `DtMemberTransferService`; extend the isolation fixture with a contaminated prospect and pin all three behaviours; amend D-02 (veto-not-selector; conversion writers flip the marker). If the reviewer wants #707 to stay a pure flag PR, the same four edits go into an immediate follow-up PR that must merge before the flag is turned on anywhere (readiness register L3).

**Proposed PR reply**

> Agreed, and thanks for pushing on it. Today `resolverPairByMetadata` returns no pair for every prospect a compliant writer can produce (no `dt_agreementNumber` → `MemberEntryOwnerEntryUserByMetaResolver` L58-68; pinned by `EntryOwnerEntryUserByMetaResolverTest` on `init.prospect-isolation.sql`), but the class never reads `dt_memberType`, so a PROSPECT-marked owner that *also* carried `dt_agreementNumber` + `dt_memberOrdinal=0` would pair with that agreement's PAYOR (L70-104). I will add the veto as the first check in `resolveOwnerUserPair` (return the identity result, no pair; WARN when an agreement is present), plus the mirror filter in `PayorEntryOwnerEntryUserByMetaResolver` so a mis-stamped prospect cannot make the real member's payor dedup `not-unique`. It has to go in `resolveOwnerUserPair`, not `accepts`: `AbstractFactory.getService` requires exactly one acceptor. Unflagged: it only removes pairs, never creates one, and no member carries the marker.
>
> One coupled change: `DtMemberMigrationService` (L109-120) and `DtMemberTransferService.getMetadata` (L294-297) merge agreement keys into an existing owner without touching `dt_memberType`, so a converted Day Pass prospect would keep a stale `PROSPECT` marker and the veto would downgrade a real member to MEMBER_ONLY dedup. I will have both writers set `dt_memberType=MEMBER` in the same map, which is what D-02 already says conversion does. Tests: a contaminated prospect added to `init.prospect-isolation.sql` (no pair, payor side still resolves the real member), a migration test asserting the marker flips, and calculator rows for the same shape.
>
> Happy to do this as a second commit here or as the next PR; either way it merges before the flag is enabled.

---

## Implementation notes if accepted

All in `universal-wallet`, branch `prospect-wallet/review-fixes-dedup-flag` (or a follow-up from it). No behaviour change for MEMBER owners without the marker in either flag state.

**Production code**

1. `common/WalletConstants.java` — no new constants needed (`MEMBER_METADATA_KEY_MEMBER_TYPE`, `MEMBER_TYPE_PROSPECT`, `MEMBER_TYPE_MEMBER` exist at `L19-21`). Optionally add a small `WalletEntryOwnerMetadataSupport.isProspect(WalletEntryOwner)` (or a static predicate next to the existing ones) so the calculator and the two resolvers share one definition: key `dt_memberType`, value exactly `PROSPECT`.
2. `scheduler/job/data/walletentry/deduplication/util/DeduplicationJobKeyByWalletEntryOwnerCalculator.calculate` — compute `boolean prospect = isProspect(owner)` first; if `prospect && dtAgreementNumber.isPresent()` keep the existing WARN (`L47-48`, id/type only, never the agreement value); take the agreement path only when `dtAgreementNumber.isPresent() && !prospect`; otherwise fall into the existing `else` (PAYOR id key; flag-gated MEMBER id key; flag-off throw). Update the class comment at `L34-36`.
3. `common/resolver/multi/impl/MemberEntryOwnerEntryUserByMetaResolver.resolveOwnerUserPair` — first statement: `if (isProspect(member)) { if (has agreement) log.warn("Prospect owner has agreement metadata; not resolving a pair: ownerId={}, ownerType={}"); return identityResult(member); }` where `identityResult` is the builder used at `L63-67` (extract it into a private method; the class builds the same result four times). `accepts` unchanged.
4. `common/resolver/multi/impl/PayorEntryOwnerEntryUserByMetaResolver.resolveOwnerUserPair` — after `L52`, `memberOwners = memberOwners.stream().filter(not(isProspect)).toList()` before the empty / size checks; WARN with the filtered ids if anything was removed.
5. `dt/migration/DtMemberMigrationService` `L109-115` — add `MEMBER_METADATA_KEY_MEMBER_TYPE, MEMBER_TYPE_MEMBER` to the metadata map (both when the request supplies `memberEntryOwnerUserMetadata` and in the default map; a `putIfAbsent`-free unconditional put, since the point is to overwrite a stale `PROSPECT`). The same map feeds `authorizedUserHelper.getOrCreateUser` (`L117`), so the user marker flips too.
6. `dt/transfer/member/DtMemberTransferService.getMetadata` `L294-297` — add the same entry.
7. Optional (reviewer's call): the same veto at the top of `owner/resolver/impl/MemberWalletEntryOwnerPairResolver.resolvePair` (`L49`), before the RCM call, since it get-or-creates a PAYOR twin and re-homes the member (`L106-119`).

**Tests**

- `DeduplicationJobKeyByWalletEntryOwnerCalculatorTest` (data provider): change `prospect with agreement` and `prospect with agreement without ordinal` to expect the agreement-less outcome (flag on → `DEDUPL_ACCOUNT_MEMBER_<id>`; flag off → `deduplication-job.member` "does not have agreementNumber metadata"), WARN still expected once and still free of the agreement value; add `prospect with agreement and ordinal, flag off` → throw; keep `member marker with agreement` → agreement key.
- `src/test/resources/sql/owner/init.prospect-isolation.sql`: add `g3_prospect_3` with the four contract keys **plus** `dt_agreementNumber='1111199999'` and `dt_memberOrdinal='0'` (the real pair's agreement). Extend `EntryOwnerEntryUserByMetaResolverTest`: `memberResolver.resolveOwnerUserPair(g3_prospect_3).right` is empty; `resolver.resolverPairByMetadata(payor).right.get().owner.id == primary.id` still holds (payor side ignores the contaminated prospect instead of throwing `not-unique`); the raw JPQL now returns two MEMBER rows (documenting why the Java-side filter exists).
- `DeduplicateOwnerWalletEntryTest`: one case running the manual endpoint for the contaminated prospect and asserting the handler type is `MEMBER_ONLY` and the real pair's entries are untouched.
- `DtMemberMigrationTest` (or the closest existing migration test): migrate an owner seeded with `dt_memberType=PROSPECT` and assert the owner and user carry `dt_memberType=MEMBER` afterwards, alongside the agreement keys. Same for the transfer service test if one exists at that level.
- `WalletEntryDeduplicationJobSchedulerTest.testAddProspectCardSchedulesOneDeduplicationJob` unchanged (contract shape).
- Run `./gradlew test --tests '*Deduplication*' --tests '*Resolver*' --tests '*DtMemberMigration*'` then the full suite (the previous full run was 978 tests / 0 failures).

**Documentation (outside the PR)**

- `prospects1/docs/prd/prospect-wallet-decisions.md`, D-02 clarifications: replace "no lane, resolver or job key is chosen from the marker" with the veto-not-selector rule; add "conversion writers in universal-wallet (`DtMemberMigrationService`, `DtMemberTransferService`) set `dt_memberType=MEMBER` with the agreement keys" under writers; note that existing members gain the `MEMBER` marker lazily on their next migration/transfer (no backfill needed; absence + agreement still means MEMBER).
- Readiness register L3: the veto/flip change must be deployed before `universal-wallet-PROSPECT-enable-agreement-less-member-deduplication` is turned on; API-level rejection of agreement keys on a PROSPECT deferred to the Phase 4 conversion contract (needs a metadata delete path).
- Semantic index: `themes/agreement-number-and-prosp.md` hazard #10 and `repos/universal-wallet/walletentry/deduplication.md` job-key rule — update once merged.

## What not to change, and why (for the reply)

- The client contract stays exactly four keys; the BFF allowlist and forbidden list are the control the reviewer asked for and already exist (point 1).
- No API-level rejection of `dt_agreementNumber` in this PR: merge-only metadata updates and the migration/transfer writers would trip it from inside the service before the conversion contract exists (point 1).
- The veto is not behind the new flag: gating a fail-safe would make the unsafe state the default (point 2).
- The veto goes in `resolveOwnerUserPair`, not `accepts`: the factory requires exactly one acceptor (point 2).
- Classification in wallet-account-sync still comes from Oracle; the marker vetoes on the universal-wallet dedup path only and never selects a lane or creates a pair (D-02, amended).
