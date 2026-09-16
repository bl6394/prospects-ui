# Sprint 0003 Merge Notes

Orchestrator: Claude Fable 5.1, 2026-09-15. Inputs: `SPRINT-0003-INTENT.md`, the three drafts (`CLAUDE`, `CODEX`, `GEMINI`), the three critiques, and the user's interview answers (CR-13 in full with resend; new `prospect-wallet/sprint-0003` branches; 24-hour view-only link grace).

## Claude Draft Strengths
- Twelve code facts verified before proposing anything, two of which reshape the plan: every consent render uses the **first** catalog offer (`requireOffer` from `createOrderShell`, `consentSetFor`, `buildCheckoutResponse`, `validatePurchase`), so a 3-day buyer would otherwise accept 1-day Pass Terms; and the Day Pass HTML flag hint is computed from `?club=`, so a token URL is blocked unless the pass page is routed in `App.tsx` before the `/pass` branch.
- Most executable UI breakdown: `OfferCards` radiogroup + selectable `OfferCard`, `format.ts` helpers (`validityLabel`, `dateFieldLabel`), `PassBlock` without QR, `PassViewPage` + `PassCredential` + `PassReceipt`, exact SCSS rules and breakpoints, every v4 string pinned.
- Concrete image transport split with reasons: CID PNG on SMTP, hosted token-protected `qr.png` on the publisher (no attachment slot in `EmailEngineRequest`), never a data URI.
- `EmailPublisherMailer.deliver` passes no club today → billing `00000-STP`; fixed in passing.
- Vertical slice named (select 3-day at Core → price/validity/terms/Pay change → mock purchase with a range) before any email or link work.
- Owner-only rotate-and-resend route; hooks-only revoke for the smoke; Demo 3 in the HTTP demo script; PR-06 proved by decoding the PNG, not by eye.
- Corrections to the CR list (`OrderRequest.offerId` never existed; FR-P22/P23 are not in PRD v3.4; tel attributes already present).

## Codex Draft Strengths
- Separate `PassCredentialStorePort` with its own lifetime, decoupled from the 30-minute / 2-hour checkout sweep; idempotent `getOrCreateForPurchase`; the same URL reconstructed on replay, never re-minted on GET.
- Versioned HMAC capability token (`v1.<randomId>.<exp>.<sig>`) with a dedicated `STP_PASS_LINK_SECRET`, constant-time compare, no identifiers in the token, identical 404 for malformed / tampered / unknown / revoked / link-expired.
- Concurrency: selection must be atomic against verify (directory resolution awaits external work, then commits an order from an older snapshot); compare generation inside `CheckoutStore.update` and bump on committed offer/order edits so equal-generation stale writes are refused.
- Consent revision bound to canonical commercial fields (offer id, amount, dates) as well as document hashes, so club-overridden static Pass Terms cannot hide a range change; waiver acceptance preserved only if its rendered hash is unchanged.
- Skeleton sidebar until an order exists; no early payable order invented to show a total.
- Public route chain never reuses `checkoutChain`; club gate resolved from the credential, not `?club=`; `no-store`, `Referrer-Policy: no-referrer`, `X-Robots-Tag` on API, image **and** the token HTML document; `STP_PUBLIC_BASE_URL` for absolute links, never the Host header.
- Publisher acknowledgement ("queued") mapped to `delivery.pending`, not `sent`.
- T0–T8 gates with the rule that a failed gate is named, never absorbed into the completion sentence; extended vocabulary "static QR only; desk verification and rotation unverified".
- Time-boxed A4 feasibility checks (Node QR package, base path, timezone helper, CID MIME shape) before the transport table is frozen.

## Gemini Draft Strengths
- Explicit `defaultOfferId` on `POST /checkouts` rather than making array position part of the contract (adopted as `selectedOfferId`).
- The branch question: `prospect-wallet/sprint-0001` now carries prerelease bumps and two sprints of history (adopted by the user: new branches).
- Compact L0/L1 summary style; capability-based section order.
- Static QR first with rotation deferred (all three agree).

## Consensus Critiques (multiple agents agreed)
- Selection must exist **before** an order exists and be threaded through all five first-offer call sites; a UI-only radio change cannot satisfy CR-10.
- The purchase store holds no amount, offer name or dates today, so a standalone pass page and a resend need an **immutable receipt snapshot** on the purchase, independent of the checkout and the mutable catalog.
- CID for SMTP, hosted image for the publisher, no data URI; local Mailpit proof is separate from any live or client-compatibility claim.
- Codex's sprint-wide mandatory `generation` and the full instrumentation/logging audit inflate scope by roughly a third and are trimmed (below).
- The parity inputs under `tools/day-pass-harness/parity/` must be updated to v4 **in place** (they are sha256-pinned to v1.2 today) without running the loop; a second copy elsewhere would leave the harness pointed at v1.2.
- Gemini's stateless JWT cannot be revoked and its `SignupShell` mount is dead code; its removal of the on-page receipt contradicts v4 (line 610 keeps "Receipt").

## Valid Critiques Accepted
- (Codex on Claude) Persist an immutable `receipt` snapshot at ISSUED (item, label, amount, currency, dates, seller, sanitized payment brand/last4, purchasedAt); page, email and resend read that snapshot.
- (Codex on Claude) Selection allowed only while no order exists and checked atomically inside the store mutation together with state and generation; a verify that commits an order uses the selection read inside the same mutation. Races tested: offer-vs-verify, offer-vs-retryLookup, offer-vs-identity-reset.
- (Codex on Claude) Resend semantics defined: per-purchase serialization; mint the new token, deliver, and revoke the old token **only when the transport accepts the send**; a failed resend leaves the previous link valid; toast follows the returned delivery status. Lost creating response recovered by an owner-only `GET …/pass-link` that returns the current `viewPath` without rotation, so reload never forces a resend.
- (Codex on Claude) No claim that resend recovers passes after a BFF restart — both stores are in-memory; recorded as a local-demo limitation and a PLATFORM register row.
- (Codex on Claude) Token confidentiality is concrete middleware work: redact `/passes/` and `/pass/` paths in the request logger and history-fallback debug lines; `Referrer-Policy: no-referrer` and `no-store` on API, image and token HTML; skip the AppDynamics snippet for `/pass/` documents. Hooks outbox is the acknowledged fourth place a raw link appears.
- (Codex on Claude) `PassView` carries a server `today` (club-local) so status is never browser-local; payment brand/last4 stay in the **email** receipt and out of the public page; the public field set is pinned by a leak test.
- (Codex on Claude) CR-13 link placement: done-page pass block, email button, and the done-page **Receipt** sidebar row; the on-page receipt stays (v4 keeps it).
- (Codex on Claude) Vertical slice includes B3 (range on the issued pass) so the milestone's receipt shows a range; B4 (email) depends on B5 (token) — ordered accordingly.
- (Codex on Claude) Date edits keep the existing explicit rejection (`isVisitDateAllowed`); no silent clamp; `maxDaysAhead` bounds the **start** date.
- (Codex on Claude) T4 requires a decoded byte-for-byte QR comparison; T3 proves the page with no cookie **and** after checkout expiry.
- (Claude on Codex) Trim: `generation` stays optional-but-checked on existing routes, **required** on the new offer route, and bumped on committed offer/order edits; per-IP limiter via the existing `WindowLimiter` plus a per-purchase resend limiter (per-credential limiter deferred with the durable store).
- (Claude on Codex) D4 (done page without QR) is shippable without the pass page: CTA hidden when no `viewPath`.
- (Claude on Codex) E3 runs against a single BFF process (in-memory credential store).
- (Claude on Codex) Reuse `requireShortTermPass` with a club resolver from the credential is an explicit task, not a side note.
- (Gemini) Merge Claude's UI mapping with Codex's credential store and atomic selection.

## Critiques Rejected (with reasoning)
- (Codex) Mandatory `generation` on every mutating call incl. DELETE/headers this sprint — contract break for deployed clients, unrelated to CR-10…17; deferred to a register row.
- (Codex) Full audit of AppDynamics and client tracking across the BFF entrypoint — reduced to the three concrete measures above; the rest is a live-readiness row.
- (Codex) Parity inputs in a new `docs/validation/parity/sprint-0003/` folder — rejected in favour of updating `tools/day-pass-harness/parity/*.json` in place; the state list and citations live in `docs/validation/short-term-pass-ui.md`.
- (Gemini) Live re-pricing via `offerId` on `PUT /order` after verify — v4 has no control for it; Change / Start again re-selects. Recorded as the rejected alternative (RQ-6).
- (Gemini) Stateless JWT signed with `STP_SESSION_SECRET` — no revocation, key coupling; rejected for the random id + server record with a dedicated secret.
- (Claude draft) 7-day link grace — user chose 24 hours view-only.
- (Claude draft) Continue on `prospect-wallet/sprint-0001` — user chose new branches.

## Interview Refinements Applied
- **CR-13 in full**: link on done page + email + receipt, login-free page with static QR, owner-only rotate-and-resend.
- **Branches**: `prospect-wallet/sprint-0003` off the current `sprint-0001` heads in both repos; new PRs stacked on `prospect-wallet/sprint-0001` (retarget to `main` when #524/#96 merge — rebase with `--onto` if the base branch is deleted after a squash merge, as happened with universal-wallet #705). Prerelease tags for the dev deployment keep pointing at the sprint-0001 heads until the user asks for a bump.
- **Link lifetime**: end of the last valid club-local day + 24 hours, view only; expired state hides the QR; after link expiry the generic 404.

## Final Decisions
- Contract v3: `POST /checkouts` → `offers[]`, `selectedOfferId`, compatibility `offer`; `PUT /checkouts/:id/offer {offerId, generation}` (pre-order states only); `OrderSummary.{durationDays,label,validUntil}`; `PurchaseResult.pass.{label,validUntil}` + `viewPath` on the creating 201 only; `PurchaseResult.receipt` summary; `GET /passes/:token`, `GET /passes/:token/qr.png` (public, 404/410/429, `no-store`); `POST …/purchases/:pid/pass-link` (rotate + resend) and `GET …/purchases/:pid/pass-link` (current link, owner only); hooks `POST /testing/passes/revoke`.
- Validity: inclusive club-local calendar days, `validUntil = visitDate + durationDays − 1`; one helper in the BFF, one formatter in the UI, identical fixtures; Pass Terms `2026-09.2` "{label} to {legalName}, valid {validity}" with the PRD refund sentence.
- Catalog: Core 90033 Gym Floor 1/3/5 ($25 / $60 / $90, the latter two `provisional: true`); Riverside single $18; Kelly Reyes for Core `m@m.com`.
- Credential: `PassCredentialStorePort` + mock adapter; token `pv1.<id>.<exp>.<sig>` HMAC-SHA256 with `STP_PASS_LINK_SECRET`; static `STP2` QR payload carrying both dates; CID on SMTP, hosted PNG on publisher.
- Sizing after trims: ~14 engineering days (A 1.5, B 5, C 4.5, D 1, E 2) in two lanes after A; harness lane still deferred until the user says.
