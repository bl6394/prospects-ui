# Guest Pass pilot gates — checklist with owners (Sprint 0004 D4)

**Purpose.** Passing the Sprint 0004 gates V0–V8 proves the Guest Pass checkout with **mock adapters** locally and in dev with the pinned one-time code. It never authorises enabling a club. This checklist is what has to be true, in order, before the LaunchDarkly flag `guest-pass-online` is switched on for any real club. Every step names an owner and says what happens if it is skipped. Sources: `docs/sprints/SPRINT-0004.md` §Definition of Done (V-P0…V-P6), `docs/prd/Next_Steps_2026-09-10_v2.md` steps 8–12, CR v3 PR-06 / PR-14, RQ-0.

**Status legend:** `pending` (not started) · `blocked` (waiting on a named input) · `done` (evidence linked). As of 2026-09-18 every row is `pending` or `blocked`; nothing here is claimed.

| # | Gate | Owner | What "done" looks like | Effect if not done | Status 2026-09-18 |
|---|---|---|---|---|---|
| V-P0 | **DT prospect email is safe with create-before-pay (RQ-0)** | Chancy + Mark | Written answer: DataTrak sends the prospect email with the QR only after the sale is recorded, **or** the deactivate reliably precedes any send (test with a declined card at a lower-environment club: no email, or an email followed by a refused check-in). | A declined buyer receives a working QR by email. **No pilot.** | blocked — RQ-0 unanswered |
| V-P1a | **Catalog columns and the DT PR live in a lower environment** | Chancy → PK (review), Terry Smith (DBA) | `saleItems.spr` (or the club-scoped variant) returns `guestPassOnline`, `contractDays`, `visits`, `itemType` for a flagged product; `getClubDefaultExternal.spr` returns `waiverText` and `timezone`; the query works with no member id (CF-13, CF-14). Contract §8a records the shape; the `DatatrakServiceCatalog` adapter reads it with `STP_CATALOG_SOURCE=datatrak`. | The page can only sell fixture items; `STP_CATALOG_SOURCE=fixture` stays in dev and is refused in production → **no production boot**. | blocked — fields absent on 2026-09-18 (§8a) |
| V-P1b | **DT service credential in `platform-online-join-bff`** | PLATFORM | `STP_DATATRAK_SERVICE_URL` and `STP_DATATRAK_SERVICE_AUTH` set from the k8s secret in dev, then prod; never in a values file. | Adapter fails closed; every club 404s. | pending — ticket to raise after V-P1a |
| V-P1c | **Platform identity / prospect / payment / sale ports** | Mark (API package) + Chancy (CF-15 field names) | `ProspectPort` v4 (`create` with begin / expiration / visits / opt-in / item, `repaint`, `deactivate`, `revert`, `lookupByOperation`), `IdentityDirectoryPort`, `PaymentPort`, `PassSalePort` have platform adapters replacing `notEnabled`; each proven against a lower environment; the decline → deactivate path observed in M&O. | Mock only. **No live purchase is possible.** | blocked — CF-15 unanswered |
| V-P1d | **Durable checkout / idempotency / compensation state** | PLATFORM + BFF | Purchase records, idempotency keys and pending compensations survive a pod restart (shared store); one replica in dev is fine, production needs the store before more than one replica. | A restart mid-purchase loses the compensation and the replay guard → duplicate charge or an undeactivated record. | pending |
| V-P2 | **Webhook propagation of the deactivate (PR-14)** | Chancy + Kyle Childers | A page-driven declined purchase at a lower-environment club: the deactivate reaches every CRM / automation the create reached; correlation id matched in each. | Clubs market to people who never bought (Round 6 risk). **No club enabled** without it. | pending |
| V-P3a | **Production host and Cloudflare rules (RQ-5)** | PK | `guestpass.abcfitness.com` (or the name PK chooses) on the BFF ingress with TLS; Cloudflare rate limiting and bot rules "as on OJ" in front of it; the BFF per-IP limits (10 purchases / hour, 20 identifies / hour, 2 codes per address / hour) remain the inner layer. | Card testing on an open endpoint (R10). **The URL stays dark.** | pending |
| V-P3b | **Legal and Twilio on the opt-in modal and no age gate (CF-08, CF-09)** | Kelly Card + Legal | Counsel accepts the waiver with no 18+ gate (or names the change); Twilio accepts the modal (or the inline variant is switched on — a copy switch, not a rebuild). Template versions bump if the text changes. | Consent evidence may be challenged; SMS sends refused. | pending |
| V-P3c | **No mock or test configuration in production** | PLATFORM + BFF | Production values carry `STP_ADAPTER_MODE=platform`, `STP_CATALOG_SOURCE=datatrak`, no `STP_MOCK_OTP_CODE`, no hooks, no flag override; the boot guard refuses anything else (config.test.ts). | The guard refuses to boot — by design. | pending (guard built in B10) |
| V-P4 | **Desk-scanner test (PR-06)** | Chancy + Mark | The emailed QR admits on the pass day at a lower-environment club; refused after `expirationDate`; refused after the single visit (visits = 1). | Buyers cannot get in, or get in twice. | pending |
| V-P5 | **Simulated-user agents end to end (PR-02/03/04)** | Mark | Mail sink + sandbox cards; the harness lane in this repo stays deferred until the user says otherwise. | Regression coverage of the live flow is manual only. | deferred (user decision) |
| V-P6a | **Maintenance server running at pilot clubs** | Chancy | Confirmed at each pilot club (it expires prospects). | Expired records stay active. | pending |
| V-P6b | **Baselines at clubs 31239 and 31590 (D27)** | Chancy + product | Prospect and pass counts captured before enablement. | No before/after measure. | pending |
| V-P6c | **Product-marketing hand-off (PR-08)** | Chancy | Three-button club-site story (trial / join / day pass) and the enablement guide (PRD §4.6 "Club configuration steps"). | Clubs cannot self-enable. | pending |
| LD | **LaunchDarkly flag `guest-pass-online` (club kind, default off) in dev and prod (CF-17)** | PLATFORM | Flag exists; `STP_LOCAL_FLAG_OVERRIDE` removed from dev values; a targeted club evaluates true. | Dev runs on the override; production has no switch. | pending — ticket to raise |
| DEV | **Standalone dev host `guestpass.dev.abcfitness.net`** | PLATFORM (helm PR) + QA | helm-configs PR merged and deployed; `dev-wildcard` covers the host; entry document on `/?club=90030`; a hosted-card checkout completes on the new host. | Dev smoke only on the existing host. | pending — PR opened in D1 |

## Enabling a club (only after every row above is `done`)

1. Club creates the catalog **product** (v1: contract days 1, visits 1, e.g. Day Pass $25), turns on **Guest pass online**.
2. Club settings → Online: waiver language pasted; prospect terms reviewed.
3. Setup → Email types: prospect email greeting and footer reviewed.
4. PLATFORM targets the club in `guest-pass-online`.
5. QA runs one real purchase with a sandbox card at the club and one declined purchase; Chancy confirms the deactivate in M&O and Kyle confirms the CRM.
6. Club adds the **Buy a day pass** button pointing at the Guest Pass URL.

## Completion vocabulary reminder

Sprint 0004 gates V0–V8 (mock acceptance) are separate verdicts from this checklist. "Mock-proven" never reads as "live" or "pilot-ready"; a failed or pending row is named, never absorbed.
