# Sprint 0002 — UI lane: blockers, deviations and notes

Executor: Claude Fable 5.1, UI lane (parallel with the BFF lane), 2026-09-10. Repo `repos/online-join-ui`, branch `prospect-wallet/sprint-0001`, entered at `eafada1` (Phase A). Scope: Implementation Plan Phase C (C1–C9, C8 split a/b/c), Addendum P1-1, P1-2, P1-3 (UI side), P1-4 (UI side), P1-5, P1-6, the UI-side P2 items, E4 for the UI only. Coded against contract v2 (`docs/contracts/short-term-pass-bff.md` §4 / §4a); the BFF was never run. Not pushed. The previous executor's Phase A notes are in `SPRINT-0002-BLOCKERS.md` and were read first.

## Blockers

None that stop the lane. B1 (Pay Page dev credentials) is unchanged and outside this lane; in the UI it only means the hosted card slot shows the loading state and then "Unable to load the payment form." + Retry until the six variables exist (U15 as planned). Gate S5's hosted run stays *pending*.

## Deviations and interpretations (recorded as they occurred)

### U-1 — Commit boundaries: C1–C7 and C9 landed in one commit, C8 in a second

The plan asked for a commit per task or pair. The v2 slice shape (C1) changes every step and component at once (`order.terms` → `order.consents`, `startOver` → `changeContact`, the verify step folded into identify, Pay moved to the sidebar), so a per-task series would either commit red intermediate states or throw-away adapter code. Resolution: `29ebc96` carries C1–C7 + C9 and every P1/P2 fix; `fa1878c` carries C8a/b/c and P1-6; `41d7444` reconciles one BFF-lane deviation (D-4). Every commit lints (0 errors), builds and has a green suite (the one pre-existing failure aside). C6 was folded into the first commit rather than the second because the recognized / new-visitor tests were written against the `TestCardPanel` buttons, not the deleted `<select>`.

### U-2 — Pay is `aria-disabled`, not `disabled`, while a gate is unmet

U11 says both "Pay enabled only when day && adult && waiver && payment ready && …" and "pressing Pay while incomplete toasts …". A truly disabled button cannot be pressed. Resolution: the sidebar Pay carries `aria-disabled="true"` (styled exactly like `:disabled` — opacity 0.5, not-allowed cursor, so the parity screenshot matches v1.2's `disabled` attribute) until every gate holds, and a press explains the first unmet gate with the v1.2 toast (day → "Choose the day your pass applies on", adult, waiver, card). It is truly `disabled` only while a request is in flight. DESIGN to confirm at S2 (parity compares text and computed style, not the attribute).

### U-3 — Line item "1-day pass · {Product}" is not repeated when the product is itself "1-day pass"

v1.2 renders `1-day pass · Gym Floor` for Core. The Riverside default offer is named "1-day pass", which would read "1-day pass · 1-day pass". `lineItemLabel()` renders `{durationDays}-day pass · {name}` and drops the suffix when the name equals the duration label. Core parity is exact; Riverside reads "1-day pass". The PassBlock title uses the duration label only, as v1.2 does.

### U-4 — "We found you." alert only when a saved card exists

v1.2 always shows "**We found you.** Your saved card is ready — nothing to re-enter." because its fixture has a card. For a recognized person whose wallet is empty or unavailable the sentence would be false, so the alert renders only when the wallet lists a card; the Sprint 0001 empty / unavailable (Retry) copy is kept underneath "Payment" as the plan allows. Parity fixture Jordan (`m@m.com`) has the card, so the parity state is unaffected.

### U-5 — Required Mobile on the recognized step surfaces validation as a panel alert

The approved delta adds a required Mobile field under Your info when the person has no mobile on file (D37). v1.2's recognized step has no error alert, so the two mobile messages ("Please add your mobile number." / "That mobile number doesn't look right.") render in the same `.dt-alert.danger` the new-visitor panel uses. Candidate for the approved-delta manifest (`TOOLS/parity/approved-deltas.json`, owned by the harness lane).

### U-6 — Brand word in the consent sentence and the marketing copy

The UI writes `{club.brand.word}'s Pass Terms`, "Keep me posted about joining {club.brand.word}" (fallback when the server sends no marketing notice) and "Get the {club.brand.word} app". The BFF fixture for Core has `brand.word = 'CORE'` (header) while v1.2's sentence reads "Core's Pass Terms" (first word of the legal name) and the BFF's own marketing notice uses `brandWordOf(club)` = "Core". The UI has no `legalName` on `ClubSummary`. Recorded as contract question Q-1 below; until answered, Core's sentence reads "CORE's Pass Terms" (a 1-token parity delta on one state).

### U-7 — Two buttons named "Close" in the document dialog

v1.2 has both the `×` (aria-label "Close") and the footer "Close" button. Kept verbatim for parity; the test disambiguates by position.

### U-8 — `DtCheckbox` / `DtAlert` not modified

C8b lists `UI/components/dt/{DtCheckbox,DtAlert}.tsx` as MODIFY. The v1.2 `.agree` checkboxes need the `<label>` inside `.t` with a sibling link button (a button inside a label would fight the label's activation), so `ConsentBlock` renders that markup directly; `DtAlert` already supports title + body. Neither primitive needed a change; both stay at 100 % coverage.

### U-9 — Server messages: allowlist instead of "always" or "never"

P1-3 asks that a raw server message is never rendered. The contract also defines customer copy for typed codes (`CODE_INVALID`, `CODE_EXPIRED`, `CHALLENGE_LOCKED`, `THROTTLED`, `VALIDATION_FAILED`, `ORDER_NOT_READY`, capture codes, a bare `STATE_CONFLICT`). `format.ts` `displayMessage()` shows the server text only for those codes and the generic "Something went wrong. Please try again." for everything else (a 404, an ajv pattern, an unexpected shape); `CHECKOUT_EXPIRED` and `STALE_GENERATION` are never rendered — the page restarts / re-syncs with a toast. `WAIVER_HASH` / `CONSENT_REVISION` use local copy.

### U-10 — `retrySecondsLeft` uses `Date.now()` captured when the error arrives

`toUiError` stamps `retryUntil = now + retryAfterSeconds × 1000` in the reducer (impure, like the existing toast counter). Components tick once a second while a cooldown is active; Continue and Resend are disabled and show "(Ns)".

### U-11 — Optimistic order edits: rollback snapshot + latest-request acceptance

`updateOrder.pending` applies the request body to `order` locally (adult, waiver, saveCard, marketingOptIn, visitDate) and keeps the pre-edit order as `orderRollback` while requests are in flight; `fulfilled` replaces the order only for the **latest** RTK request id and only when the response `generation` is not older than the state's; `rejected` restores the rollback. Preference toasts (save on/off) fire immediately; the date toast fires only after the server accepts (QA A1-03). The date `PUT` is debounced 400 ms (QA A1-04).

### U-12 — Stylelint has no configuration in this repo

`lint-staged` lists `stylelint --fix` for `*.scss`, but there is no stylelint config and the `husky` block in `package.json` is the v4 format (husky 8 ignores it), so no pre-commit hook runs. Commits were made with `core.hooksPath=/dev/null` after running `npm run lint` and prettier by hand; the SCSS was formatted with prettier. Not this lane's to fix; noted for the orchestrator.

## Reconciliations with the BFF lane (read from `SPRINT-0002-BLOCKERS-BFF.md` during the run)

- **D-2** (unknown cookie → 401 `CHECKOUT_EXPIRED`, cookie not cleared): the UI already restarts by `POST /checkouts`, which resumes whichever live checkout the cookie points at (`applySnapshot`). The toast still says "Your session expired. Let’s start again." even when the checkout resumes — a wording review item for E5.
- **D-4** (code replay after a 503 → 401 `CHALLENGE_MISSING`; three failed `retryLookup` → bare 409 `STATE_CONFLICT` "We could not look you up. Please start again."): landed in `41d7444` — the bare 409 ends the Retry affordance, re-enables Continue and shows the contract copy.
- **D-3** (new visitors may `wallet-retry`): the UI gates the wallet Retry on `emailVerified`, which is true for every buyer under v2, so first-time buyers see the retry link (U17).
- Random codes in mock mode: irrelevant to the UI tests (the service module is mocked); the orchestrator's browser check needs the B5 outbox route.

## Contract questions for the BFF lane / orchestrator

| # | Question | UI behaviour meanwhile |
|---|---|---|
| Q-1 | Which brand word do the consent sentence, the marketing copy and "Get the {Brand} app" use — `brand.word` ("CORE") or the legal-name first word ("Core")? Suggest `ClubSummary.brand.sentence` (or `legalName`) on `POST /checkouts`. | `brand.word`; the server's `marketingOptIn` notice copy wins when present |
| Q-2 | A recognized person with no mobile on file: the UI sends `profile:{firstName,lastName,mobile}` on `POST /purchases` (D37 approved delta). Does `validatePurchase` accept `profile` for a recognized checkout and store the mobile on the person? | Sent; if the BFF refuses with 400 the message shows in the panel alert |
| Q-3 | `VALIDATION_FAILED` messages are shown verbatim (allowlisted). The BFF should send customer copy for the mobile / name patterns ("That mobile number doesn't look right."), never the ajv pattern text. The client already enforces `maxLength` 120 / 60 / 32 and the v1.2 messages before any request. | Client validation first; server copy shown as-is |
| Q-4 | `snapshot.contact.display` must be present for a `newVisitor` snapshot (the header reads "Email **{display}**"). | Falls back to `contactHint` |
| Q-5 | After `PUT /order {smsNoticeShown:true}` the returned `order.consents.notices.smsTransactional` must be set, otherwise the UI would send it again on the next mount. | Sent once per mount (ref-guarded) |
| Q-6 | `PUT /order {waiver:{accepted:false}}` is sent without `method`/`renderedHash` on uncheck; the schema allows it (nullable). Confirm the server clears `method`. | Optimistic uncheck |
| Q-7 | Can `PUT /order` answer 409 `CONSENT_REVISION`? The UI handles the consent refresh for both `PUT /order` and `POST /purchases`. | Handled either way |
| Q-8 | `DELETE /checkouts/:id/identity` returns `generation`; the UI adopts it. `DELETE /checkouts/:id` has none (fine — the store resets). | — |
| Q-9 | `POST /checkouts` `testHooks` must be `false` (or absent) outside test runs; the UI renders the `TestCardPanel` only for `captureMode==='mock' && testHooks===true` and treats everything else as hosted. | Absent → hosted |

## P2 items from the QA doc **not** done in this lane (listed for the execution summary)

A6-05 (non-JSON 200 on bootstrap), A6-06 (no client timeout on the purchase request), A6-07 (transient network failure on bootstrap shows the permanent unavailable copy), A6-08 (another tab completed the purchase — the P1-4 re-sync covers the 409 path only), A3-05 (invalid field gets no `aria-invalid`/focus — the panel alert is shown instead), A5-02 (header at 641–930 px — `nowrap` + shrinkable brand added, not measured), A5-03 (14 px inputs / iOS zoom — v1.2 token), A5-05 (tap targets — v1.2 sizes), A6-09 (`<html lang>`, landmarks, h1 on the unavailable page — `index.html` and the shared shell are outside this lane), A6-10 (button contrast — v1.2 `--ig-accent`). A2-01/A2-02 are moot (channel switching removed by CR-05).

## Scope changes

- C6 landed in the first commit together with C1–C5, C7, C9 (see U-1); no change to the Pyramid Index was needed.
- `SPRINT-0002.md` not edited.
