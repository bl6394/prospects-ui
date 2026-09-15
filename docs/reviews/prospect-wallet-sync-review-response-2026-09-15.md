# Prospect wallet sync — code review response (2026-09-15)

**Review under discussion:** `docs/prd/concerns.txt` (reviewer notes on `wallet-account-sync` commit [`1dc1cd6`](https://github.com/abcfinancial/wallet-account-sync/commit/1dc1cd64549c6b8655d12b699cadae58aea1045f) "Dark prospect wallet sync lane: intake classification, isolated consumer, read-only backfill dry-run (#405)" and on `universal-wallet` `WalletEntryDeduplicationJobSchedulerService`, branch `prospect-wallet/sprint-0001`).
**Method:** every class the reviewer names was read on the branch heads (`wallet-account-sync` `63b4290`, `universal-wallet` `1e5eefa0`) together with the shared classes they wrap (`PaymentMethodChangedEventProcessor`, `MicrometerService`, the existing Kafka listeners and the `spring.kafka` / `abcfinancial.kafka.listener.retry` configuration) and the design record in `prospects1/docs/prd/prospect-wallet-decisions.md` and `prospect-wallet-plan-v2.md`. Each point below states what the code actually does, whether the concern holds, and a recommended reply. Effort is a rough size for the follow-up, not a commitment.

**Disposition key:** **Accept** = fix as asked · **Accept, adjusted** = fix, but not exactly as proposed · **Clarify** = the code is right for a reason the review could not see; document it · **Push back** = keep the behaviour, with the reason.

## Implementation status (2026-09-15, same day)

All accepted points are implemented and in review; the pushed-back items are unchanged as argued below.

| PR | Repo | Content | Tests |
|---|---|---|---|
| [wallet-account-sync #406](https://github.com/abcfinancial/wallet-account-sync/pull/406) | `main`, squash | Points 5–19 in three commits (`45a5063` mechanical; `3f07fff` dedicated Kafka container factory, typed consumer, tagged `MicrometerService`, validated properties; `7e412bd` prospect-scoped consent publisher, guard removed, shared payment helpers) | full suite 1087 tests / 98 classes, 0 failures |
| [universal-wallet #707](https://github.com/abcfinancial2/universal-wallet/pull/707) | `main` | Point 1: `universal-wallet-PROSPECT-enable-agreement-less-member-deduplication` (default off) gates the MEMBER id-based dedup key fallback | 978 tests, 0 failures |
| [spring-cloud-config #4652](https://github.com/abcfinancial/spring-cloud-config/pull/4652) | `develop` | Follow-up: drops the retired `prospect-tier.consent-suppression` and `prospect-lane.nack-backoff` keys from the three unapplied `*-prospect.yml` tier files | YAML parse |

Points 3 and 4 (documentation) are recorded in `prospects1/docs/prd/prospect-wallet-decisions.md` ("D-02 clarifications" and "Post-review implementation state"). Per-point implementation notes with the pinning tests: `prospect-wallet-sync-review-fixes-WAS.md` and `prospect-wallet-sync-review-fixes-UW.md` in this folder. Deviations worth knowing: the prospect consent publisher implements a small interface rather than subclassing the member publisher (avoids ambiguous injection); `prospect-payment-method-sync-count.errors` is counted once per terminal pass by the recoverer and the duration timer is one sample per delivery attempt; the strict UUID helper has one caller because point 8 removed the string parse from `MemberService.isProspect`.

## Summary

| # | Point | Disposition | Effort |
|---|---|---|---|
| 1 | UW: agreement-less MEMBER dedup behaviour not behind its own flag | Accept, adjusted (flag the key fallback only) | S |
| 2 | No pair-resolver changes; prospects must not resolve pairs | Clarify (correct by construction, pinned by tests) | — |
| 3 | Who populates `dt_memberType` | Clarify (writers named) | — |
| 4 | Data migration / backfill of `dt_memberType` for existing members | Clarify + Accept (write the rule down, no DBA backfill) | S |
| 5 | BackfillDryRun: redundant full-UUID check | Push back on "redundant" (`UUID.fromString` is lenient); Accept moving the check into `UUIDUtil` | XS |
| 6 | Metrics counters belong in `MicrometerService` (3 classes) | Accept, adjusted (`MicrometerService` needs a tagged API first) | M |
| 7 | `FeatureFlagHelper#isProspectLaneEnabled` wrapper | Accept, adjusted (inline, keep fail-closed) | XS |
| 8 | `MemberService#isProspect` re-parses a UUID | Accept (`isProspect(UUID)`) | XS |
| 9 | `ProspectLookupRowMapper` `getBigDecimal` → `getBoolean` | Accept (`Boolean` + `wasNull`) | XS |
| 10 | `WalletEventService` prospect logic | Clarify + Accept (metrics, extraction) | S |
| 11 | `ProspectClassifier` → `MemberClassifier`; club mismatch should fail; `Integer` flag | Accept rename and boolean; **Push back** on failing the club mismatch | S |
| 12 | Publisher: topic constant, no empty default, JSR validation | Accept, adjusted (required only when the lane is enabled) | S |
| 13 | `RoutableComposite` readability, "always false" checks, club regex, `DT_MEMBER_TYPE` | Accept readability and `isValidClubNumber`; Clarify the null checks (consumer path has no bean validation) | S |
| 14 | `ProspectPaymentMethodChangedEventProcessor` redundant vs member processor; retry on missing account; `matches*` | Push back on "redundant" (documented reasons), Accept a shared-helper extraction | M |
| 15 | `ProspectConsentPolicyConfiguration` breaks member document generation | Clarify (cannot boot in a member tier) + Accept a cleaner injection | M |
| 16 | `ProspectTierInvariantGuard` / too many flags | Accept, adjusted (collapse two of five; keep the LD club flag) | S |
| 17 | Kafka handler retry loop → container-level retry | Accept, adjusted (dedicated container factory, not the shared one) | M |
| 18 | Listener: default config, custom group, String ser/de, typed record | Accept (with the dedicated error handler from 17) | S |
| 19 | No `AssignmentEventProcessor` for prospects | Clarify (by design, D-02) | — |
| 20 | Global: messy, duplicated, hard to follow (especially Kafka) | Accept: one consolidation change set (17, 18, 6, 11, 13) | M |

---

## GLOBAL and universal-wallet

### 1. `WalletEntryDeduplicationJobSchedulerService` — new behaviour not behind a dedicated feature flag

**What the code does.** Four commits on `universal-wallet` (`57152974`, `7c85c9cc`, `a387015e`, `1e5eefa0`). Two behaviours changed: (a) `scheduleJob(WalletEntryOwner)` now returns early for owner types other than MEMBER and PAYOR; (b) `DeduplicationJobKeyByWalletEntryOwnerCalculator` no longer throws `deduplication-job.member` for a MEMBER owner without `dt_agreementNumber`; it uses the id-based key `DEDUPL_ACCOUNT_MEMBER_<ownerId>` (the same fallback PAYOR already had). The payor-member pair path was hardened to treat a blank agreement number as absent. Gating today is only `ENABLE_WALLET_ENTRY_DEDUPLICATION_JOB` / `…_BY_LOCATION`, which the reviewer describes correctly.

**Assessment.** (a) is a pure guard: for MEMBER and PAYOR owners nothing changes, and other owner types previously fell through to the same calculator and failed. It does not need a flag. (b) is real new behaviour for one population that could not previously be scheduled at all (every prospect add-card logged an error, plan v2 G8), so a flag would only ever switch prospects between "dedup runs" and "dedup throws as before". That is still worth having for a dark rollout: if the fallback key misbehaves it can be turned off without a deploy.

**Recommended response.** Agree to add `ENABLE_AGREEMENT_LESS_MEMBER_DEDUPLICATION` (LaunchDarkly, default off, evaluated where the calculator chooses the fallback branch). When off, the calculator keeps today's throw, so member behaviour is unchanged in both states. No flag for the owner-type guard. Add the key to `LaunchDarklyFeatureFlagKey`, a test for both states, and a line in the readiness register (L3).

### 2. No `WalletEntryOwner` / `WalletEntryUser` pair-resolver changes; prospects should not resolve pairs

**What the code does.** No production resolver was modified. Prospect owners carry `dt_clubNumber`, `dt_memberId`, `dt_vpdId`, `dt_memberType=PROSPECT` and never `dt_agreementNumber`, `dt_memberNumber`, `dt_memberOrdinal` (decision D-02). The four pair and metadata resolvers select by agreement metadata, so an agreement-less owner is never a pair candidate. `EntryOwnerEntryUserByMetaResolverTest`, `WalletEntryOwnerPairResolverTest`, `DeduplicateOwnerWalletEntryTest` and the `init.prospect-isolation.sql` fixture pin this (Sprint 0001 A4).

**Recommended response.** Agree: prospects never resolve a pair, and that is achieved by construction, not by a code branch. Point the reviewer at the A4 pin tests. No change.

### 3. Who populates `dt_memberType` on owner and user

**What the code does.** Today's writers, all dark:
- `online-join-bff` day-pass checkout (`services/shortTermPass/wallet.ts`, Sprint 0002): creates the owner and authorized user with exactly `{dt_clubNumber, dt_memberId, dt_vpdId?, dt_memberType:'PROSPECT'}` at the consented card save; behind `STP_WALLET_WRITES`, which stays false until this lane is signed off.
- Prospect backfill (Sprint 0002 execution, dry-run only today): stamps the same four keys on the owners and users it creates.
- Planned, outside these repos (plan v2 Phase 3 and 4): `datatrak` / `abc-core` `PosPayPageInitServiceBase` and `DtMetadataUtil` stamp `PROSPECT` on the PayPage session for POS and app flows; conversion stamps the agreement keys and sets `MEMBER`; reverse conversion sets `PROSPECT` and drops the agreement keys.

Nothing writes `dt_memberType` for existing members, and nothing in the sync lane needs it: routing is decided by the Oracle read (D-03), the marker is telemetry only (`match` / `mismatch` / `absent` counter).

**Recommended response.** List the writers above in the metadata contract section of `prospect-wallet-decisions.md` and add the "never a routing input" sentence. No code change.

### 4. Do we need a data migration or DBA backfill of `dt_memberType` for existing MEMBER owners/users?

**Assessment.** No, provided the rule is explicit. Every existing member owner carries `dt_agreementNumber` (the pair resolvers depend on it), so "no `dt_memberType` and an agreement number present" is unambiguously a member. The only code that reads the marker is the classifier's telemetry counter and the dedup calculator's warning branch (a prospect owner that somehow carries an agreement number). Neither treats absence as a decision.

**Recommended response.** Accept the request to make it explicit: state in the metadata contract that (i) `dt_memberType` absent + `dt_agreementNumber` present ⇒ MEMBER, (ii) `dt_memberType` is never used to choose a lane or a resolver, and (iii) no backfill of existing member rows is required for go-live; a metadata backfill can be scheduled later purely for reporting uniformity. Add a test pin that the classifier never reads the marker for routing.

---

## wallet-account-sync

### 5. `ProspectBackfillDryRunService` — redundant full-UUID check; metrics

**What the code does.** `getUUID(memberId)` parses; the following block compares the dash-stripped forms and throws if they differ. `UUIDUtil.getUUID` is `UUID.fromString(getUUIDFromChar32(value))`, and `java.util.UUID.fromString` is lenient: it accepts groups shorter than the canonical width (`"1-2-3-4-5"` parses to `00000001-0002-0003-0004-000000000005`), so a truncated or malformed id can parse "successfully" to a different UUID and the earlier step does **not** fail. The comparison is what catches that, and it matters here because a wrong-but-parsable id would be counted as `missing` and later drive a backfill create.

**Recommended response.** Push back on "redundant" with the example above, and accept the maintainability point by moving the strictness into `UUIDUtil` (a `getUUIDStrict` or making `getUUID` round-trip-check) with a unit test, so the dry-run service and `MemberService` both get it for free and the inline block disappears. Metrics: see point 6.

### 6. Metrics counters belong in `MicrometerService` (BackfillDryRun, WalletEventService, ProspectClassifier)

**What the code does.** The prospect code builds `Counter`s and `Timer`s directly on `MeterRegistry` with `lane=prospect` plus `action` / `result` tags. `MicrometerService` exposes only `registerMetricCounter(name, description[, actionValue | eventType | status])` and timers of the same shape; there is no arbitrary-tag overload, which is why the direct registry was used (recorded in the decisions doc, coding/010).

**Recommended response.** Accept the principle. Do it in two steps: (1) add `registerMetricCounter(String name, String description, Tags tags)` and `registerMetricTimer(String name, String description, Duration, Tags tags)` to `MicrometerService` and its no-op implementation; (2) move every prospect counter (backfill three, intake routed/skipped/errors/metadata, classifier result, no-op, consent-suppressed, sync count/errors/duration, dead-letter, quarantine-publish-failure) behind those methods and drop the direct `MeterRegistry` injections. Series names and tags stay identical so `prospect-wallet-telemetry.md` and the dashboards do not change.

### 7. `FeatureFlagHelper#isProspectLaneEnabled` is unnecessary

**What the code does.** The method validates the club number, calls `launchDarklyFeatures.getBooleanFeature(PROSPECT_LANE, CLUB, clubNumber)` and returns `false` on any exception. It deliberately does not reuse the RCM-enablement gate of the sibling method.

**Recommended response.** Accept, adjusted. The value is the fail-closed evaluation, not the helper class. Inline the call at its single call site in `WalletEventService`, keep the try/catch returning `false` (a flag-evaluation error must never open the lane), and delete the helper method. If `LaunchDarklyFeatures.getBooleanFeature` already guarantees a default on failure, the try/catch can go too.

### 8. `MemberService#isProspect` — why parse a UUID from a string obtained from a UUID?

**What the code does.** `ProspectClassifier` calls `memberService.isProspect(event.memberId().toString())`; the service re-parses and strips dashes for the Oracle `CHAR(32)` lookup.

**Recommended response.** Accept. Change the signature to `isProspect(UUID memberId)` and pass the UUID from `RoutableComposite`; the service keeps the `getNoDashesUUID` conversion for the query. The `IN (:memberId, upper(:memberId))` query stays as is.

### 9. `ProspectLookupRowMapper` — use `getBoolean` instead of `getBigDecimal`

**What the code does.** The Oracle `NUMBER` result is read as `BigDecimal` and narrowed to `Integer`; the classifier then treats `null` or anything other than 0/1 as UNKNOWN. The design point being protected is "absence or an unexpected flag is UNKNOWN, never MEMBER" (D-03).

**Recommended response.** Accept. Use `row.getBoolean("is_prospect")` followed by `row.wasNull()` so the record becomes `ProspectLookup(Boolean isProspect, String clubNumber)` with `null` preserved; drop the 0/1 range check in the classifier. Oracle's driver maps `NUMBER` 0/1 to boolean correctly.

### 10. `WalletEventService` — metrics; "prospect logic …"

**What the code does.** One flag-guarded block runs before the member `switch`: build `RoutableComposite`, set the event club's VPD, classify once, and either publish to the prospect topic (club flag on), count a skip (club flag off), or fall through to the member processors. Any failure in that block is a 5xx so the webhook retries; nothing reaches a member processor for a prospect.

**Recommended response.** Move the four counters to `MicrometerService` (point 6) and extract the block into a `ProspectIntakeRouter` collaborator so `processWalletEvent` reads as "route or fall through". Behaviour unchanged; the `MemberLaneRegressionTest` byte-identical sequence for toggle-off must still pass.

### 11. `ProspectClassifier` → `MemberClassifier`; formatting; club mismatch; `Integer` flag

**Rename.** Accept `MemberClassifier` (or `MemberTypeClassifier`) with `Classification { PROSPECT, MEMBER, UNKNOWN }`; prospect is a member type derived from the agreement.

**Formatting.** Accept: reformat to the ABC style (braces on their own lines, one statement per line, no single-line `if … return`). Apply the same pass to `RoutableComposite`, the Kafka classes and `ProspectPaymentMethodChangedEventProcessor`, which are the four files the review calls unreadable.

**Boolean flag.** Accept, follows from point 9.

**Club mismatch should fail.** Push back. The lookup runs under the event club's VPD, so a returned row with a different club number is the same person's home club inside the same ABC VPD, which the PRD treats as one person and one wallet (D11, D28; decision D-03 "a second-club row under the same VPD is resolved"). Failing there would reject legitimate cross-club events inside a VPD. Compromise: raise the log to WARN, count it as `result=club-mismatch` on the routing-metadata counter so it is visible in Grafana, and fail only if the row's VPD differs from the session VPD, which the query cannot produce today but is cheap to assert.

### 12. `ProspectWalletSyncEventPublisher` — topic constant, no empty default, JSR validation

**What the code does.** The topic is injected with an empty default so an environment without the property can boot with the lane dark; `publish` throws if the topic is blank. The other topics in this service are constants in `KafkaTopics` resolved from properties.

**Recommended response.** Accept, adjusted. Bind `abcfinancial.kafka.topics.prospect-wallet-sync-topic.*` and `kafka-write-timeout` to a `@ConfigurationProperties` `@Validated` record with `@NotBlank` and `@Positive`, and make the publisher bean conditional on `enable-prospect-wallet-lane` (it is only used behind that toggle). Result: a lane-enabled environment fails at startup when half-configured, a lane-disabled environment does not need the property, and the `IllegalStateException` branch disappears. Reference the topic through `KafkaTopics` like the others.

### 13. `RoutableComposite` — unreadable; "always false" checks; club regex; `DT_MEMBER_TYPE`

**What the code does.** It is the one place that turns any of the three composite shapes into `(memberId, clubNumber, action, dtMemberType)`, and it is used on both paths: the HTTP intake (where the controller's `@Valid` has already enforced `@NotNull`) and the Kafka consumer (where the record is parsed from a string with Jackson and no bean validation runs).

**Recommended response.**
- `event.getType() == null`, `child.getType() == null`, `child.getData() == null`, `memberId == null`, `club == null`: not always false on the consumer path. Either keep them or, preferably, run the `Validator` on the deserialized `WalletWebhookEvent` in the consumer (or use `@Valid @Payload` once the listener consumes a typed object, point 18) and then delete the manual checks. Recommend the latter as part of the Kafka consolidation.
- The three-way child count: accept the readability point; the `switch` on type already selects the child, so the count only rejects malformed envelopes that carry two children. Replace with a small `exactlyOneChild(event)` helper or drop it if validation covers it.
- `club.matches("[0-9]{5}")` → `StringSupport.isValidClubNumber`: accept.
- `DT_MEMBER_TYPE` "will never be there": true for today's producers of DT webhook events. It is telemetry only (D-03) and is meant to light up when the Phase 3 writers land. Recommend keeping the field and the `absent` bucket, with a comment saying so; happy to remove it if the team would rather add it back when a writer exists.

### 14. `ProspectPaymentMethodChangedEventProcessor` — redundant, twisted; retry on missing account; are `matches*` needed?

**What the code does and why it exists.** The member `PaymentMethodChangedEventProcessor` cannot be reused for prospects because of member semantics baked into the shared `PaymentMethodChangedEventService` calls it makes: it resets assignments on inactive update, account-changed and delete (prospects have no assignments until conversion), migration overwrites `wallet_entry_id`, `getMostRecentlyCreatedAccountInfoInactivateDuplicatedRecords` inactivates duplicates as a side effect, and missing account info on UPDATE creates a row while on ACCOUNT_CHANGED it throws a non-retryable error. The prospect lane also consumes from Kafka (at-least-once), so every event must be idempotent under redelivery; the intake webhook path is not replayed the same way. These decisions and the per-event table are in `prospect-wallet-decisions.md` (rows CREATE … DELETE) and were reviewed there.

- **Retry on `ACCOUNT_CHANGED` with no row.** An account-updater change can be dequeued before the prospect's CREATE has been persisted (different producer, no cross-topic ordering). Treating it as retryable gives CREATE a chance to land; after three attempts it is quarantined with reason `MISSING_ACCOUNT_INFO`, which is a real data problem and is visible.
- **`matches`, `matchesZip`, `matchesCardEncodingState`.** They implement replay idempotency by comparing the persisted projection to the event: a redelivered UPDATE whose fields already match must not write again (which would bump timestamps and re-encrypt). `matchesZip` exists because the shared CREATE normalizes postal codes while UPDATE keeps the raw value; `matchesCardEncodingState` exists because a row left on the POS placeholder encryption key is not the completed shape of the event (found by Bugbot on PR #405) and must be re-processed. Without them the alternative is an event-receipt store, which was explicitly not introduced.

**Recommended response.** Push back on "redundant": it is a parallel processor by design, with the reasons above, and the decisions doc should be linked from the class Javadoc so the next reader does not have to rediscover them. Accept the duplication concern in a bounded way: extract the parts that are the same as the member processor into shared helpers (organization lookup, agreement lookup, the deactivate-with-timezone write) and keep only the prospect policy in this class. Longer term, if the member processor gains a lane policy object (assignment handling on/off, missing-row behaviour, replay check), the two can merge; that is a Sprint 0003 design item, not a fix for this PR.

### 15. `ProspectConsentPolicyConfiguration` — registers a no-op bean, likely breaks member document generation

**What the code does.** The `@Primary` override of `PaymentMethodChangedConsentInternalEventPublisher` is created only when `abcfinancial.prospect-tier.consent-suppression=true`. That property is set only in the three unapplied prospect tier profiles (`wallet-account-sync-{dev,beta,stage}-prospect.yml`). `ProspectTierInvariantGuard` refuses to start any process that has suppression on together with intake, the member Kafka listeners, the migration daemon or backfill, so a member tier cannot carry the override. `ProspectProfileContextTest` loads the three real tier files and pins this. In the prospect tier there is no member traffic, so member document generation is untouched anywhere it runs. The override is not a no-op: it counts an eligible suppression (`prospect.consent.suppressed`) so the missing Tier 1 template (R-01) stays visible.

**Recommended response.** Clarify the above, then accept a cleaner shape that removes the need for a global `@Primary`: give the prospect processor its own consent publisher by qualifier (or make the shared `createPaymentMethod` take the publisher as a parameter) so the member bean is never replaced in any context. That also lets point 16 drop the guard. Medium effort because it touches the shared service signature; worth doing together with point 14's extraction.

### 16. `ProspectTierInvariantGuard` — too many flags; collapse to one

**What exists.** Three app toggles (`enable-prospect-wallet-lane` intake, `enable-prospect-wallet-sync-listener` consumer, `enable-prospect-wallet-backfill`), one property (`prospect-tier.consent-suppression`), one LaunchDarkly club flag (`wallet-account-sync-prospect-lane`). Decision D-05 chose separate intake, listener and backfill toggles so each can be dark independently and so the consumer runs in its own deployment tier.

**Recommended response.** Accept, adjusted. Keep two controls: the LD club flag (per-club rollout of intake; nothing else can do that) and one app-level `abcfinancial.prospect.role: none | intake | consumer | backfill` (or the three toggles if the ops team prefers the existing feature-list mechanism). Derive consent suppression from `role=consumer` instead of a separate property, and express the invariant with `@ConditionalOnMissingBean` / role conditions so the guard class is unnecessary. Backfill stays independent because it must never share a switch with the migration daemon (decision (e)).

### 17. `ProspectWalletSyncEventHandler#handleRecord` — retry loop in the handler; use container-level retry

**What the code does and why.** The shared listener configuration (`abcfinancial.kafka.listener.retry`) retries five times with back-off and then publishes to the shared dead-letter topic `wallet-account-sync.listeners.dead-letter`. The prospect lane's isolation requirement was that a prospect record never lands in the shared DLT and that a non-committable record blocks its partition rather than being skipped. Rather than a dedicated container factory, the executor implemented a three-attempt loop inside the handler and manual `nack`, which is the code the review finds unreadable.

**Recommended response.** Accept, adjusted: move retry to the container, but on a **dedicated** `ConcurrentKafkaListenerContainerFactory` for the prospect listener (`@KafkaListener(containerFactory = "prospectKafkaListenerContainerFactory")`) with its own `DefaultErrorHandler(recoverer, backOff)` whose recoverer publishes to the prospect DLQ with the existing quarantine summary, `ProspectRetryableException` classified retryable and everything else not retryable, and `ackMode=MANUAL_IMMEDIATE`. That keeps the isolation the loop was protecting while deleting the loop, the `Throwable` swallowing, the manual `nack` and the container-stop fallback. The handler shrinks to parse, classify, process. Keep the Testcontainers proof that N+1 is not committed while N is unresolved.

### 18. `ProspectWalletSyncKafkaListener` — remove extras, default config, custom group, String ser/de, typed record

**What the code does.** The listener overrides the consumer group and both deserializers to `String` and parses inside the handler so that a malformed record is quarantined to the prospect DLQ instead of the shared library's deserialization error path.

**Recommended response.** Accept all four once point 17 exists: consume `@Valid @Payload WalletWebhookEvent` through the dedicated factory with `ErrorHandlingDeserializer` wrapping the JSON deserializer so a poison record still goes to the prospect DLQ via the dedicated recoverer; drop the `enable.auto.commit`, deserializer and `groupId` overrides (the application default group is fine because the prospect topic has exactly one consumer application; the topic, not the group, separates the tiers); drop the `KafkaListenerEndpointRegistry` and the backoff constructor logic. The bean stays `@ConditionalOnFeature(ENABLE_PROSPECT_WALLET_SYNC_LISTENER)` (or the role from point 16).

### 19. Why a `PaymentMethodEventProcessor` for prospects but no `AssignmentEventProcessor`?

**Clarify.** Prospects have no wallet assignments until conversion by the metadata contract (D-02) and the PRD (no `PRIMARY` assignment, no RCM pair, no billing account before conversion). ASSIGNMENT and MEMBER_RE_SYNC composites for a prospect are therefore counted no-ops (`prospect.lane.noop` with the action tag) and never touch data; `processNoop` is that path. When conversion (Phase 4) creates assignments, the member processors handle them because the person is a member by then. Add this sentence to the handler Javadoc.

### 20. Global — messy, hard to follow, duplicated prospect logic

**Recommended response.** Agree with the direction and propose one consolidation change set rather than piecemeal fixes: points 17 and 18 (dedicated container factory, typed consumption, delete the loop and the manual nack), 6 (tagged `MicrometerService` API and move every prospect meter), 11 and 13 (rename, boolean flag, `isValidClubNumber`, validator instead of manual null checks, ABC formatting), 12 (validated properties), 8 and 9 (UUID and boolean signatures), 7 (inline the flag call), 5 (drop the redundant check after a pin). Points 14, 15 and 16 are a second, medium-sized change because they touch the shared consent publisher and flag topology. The member-lane byte-identical regression test and the broker proofs (N+1 blocked while N unresolved; five quarantine reasons; converted-on-dequeue) must pass unchanged after both.

## Suggested ordering

1. Small mechanical fixes with no behaviour change (5, 7, 8, 9, 11 rename/boolean/formatting, 13 regex, 3 and 4 documentation). Half a day.
2. Kafka consolidation (17, 18) plus metrics (6) and properties (12). One to two days, with the existing Testcontainers proofs as the acceptance test.
3. Consent injection and flag collapse (14 extraction, 15, 16). One to two days; needs a short design note because it touches the shared `PaymentMethodChangedEventService` signature.
4. universal-wallet fallback flag (1). Half a day, separate PR.

## What not to change, and why (for the reply)

- Prospects do not resolve owner/user pairs and never will until conversion; this is guaranteed by the metadata contract and pinned by A4 tests (point 2).
- Classification comes from Oracle, never from metadata; `dt_memberType` is telemetry (points 3, 4, 13).
- A club mismatch inside one VPD is a legitimate second-club event for the same person, not an error (point 11).
- The prospect payment processor is a separate policy over the shared service by design; the replay checks exist because the consumer is at-least-once and no receipt store was introduced (point 14).
- The consent override cannot load in a member tier; the member document flow is unaffected (point 15).
