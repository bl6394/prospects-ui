# Sprint 0003 Intent: Design v4 — multi-day passes, pass credential by email and "View your pass"

## Seed

User (2026-09-15): run the sprint plan "for Sprint 0003 with the CR-10 to CR-17 scope". The scope is `docs/prd/Change_Requests_2026-09-15.md`, produced when the user confirmed that the Director of Design HTML **v4** (`docs/prd/day-passv4.html`) supersedes v1.2 as the D46 source of truth:

- **CR-10** multiple pass products per club, selectable on the identify screen (1-day $25, 3-day $60, 5-day $90 in the design; multi-day prices marked "demo pricing — confirm"); selection drives sidebar, total, Pass Terms and Pay button.
- **CR-11** multi-day validity: "Day pass applies on" (1 day) vs "Pass starts on" (multi-day); help line, sidebar "Valid" row, pass block and Pass Terms show a range "Today – Fri, Sep 12" (start + days − 1); BFF adds `validUntil`.
- **CR-12** done page loses the on-page QR; copy becomes "{label} · {validity}" and "We emailed your pass and door QR code to {masked}. Show it at the door, or just say your name at the front desk."; the pass email carries the QR image and the receipt.
- **CR-13** "View your pass" magic link (D41, FR-P22/P23, Miro Design v2 alignment rows 8–9) on done page, in the pass email and on the receipt → web page rendering the pass and a QR without app or login. Link lifetime, resend and admit interval are open.
- **CR-14** remove the "We'll text your pass here on the day." helper under the mobile field; input gets `inputmode="tel" autocomplete="tel"`.
- **CR-15** v4 offer-card grid and identify layout (`.offers` 3-col grid, `.days` line, 32 px price, breakpoints 1250/640).
- **CR-16** fixture: Core `m@m.com` returning visitor is **Kelly** Reyes.
- **CR-17** Pass Terms template "{label} to {Club}, valid {validity}"; PRD refund sentence stays.
- Also PR-05 (parity loop re-baselined on v4 — the harness lane itself stays **deferred until the user says**), PR-06 (pass email renders its QR in Mailpit and the link resolves locally), CF-04…CF-07 (pricing/catalog, window semantics, link lifetime, static-QR vs link-only).

## Context

- **Project state.** `online-join-ui` and `online-join-bff` on branch `prospect-wallet/sprint-0001` (PRs #524 / #96), UI HEAD `151846d`, BFF HEAD `53e549e` (another session added `STP_NON_PRODUCTION` so dev/qa clusters can run mock adapters, plus prerelease versions under the npm dist-tag `daypass`). Sprint 0002 phases A–C are done and smoke-tested at 1440/375 against v1.2; harness lane (Phase D, E1, E2) deferred by the user; S5 hosted Pay Page proof pending B1 credentials; live publisher email blocked by the dev email-publisher 503. Local email goes to Mailpit (`STP_EMAIL_TRANSPORT=smtp`, SMTP :2525, inbox :8025).
- **Recent direction.** Sprint 0001 built the single-flow Day Pass checkout; Sprint 0002 brought it to v1.2/PRD v3.4 parity (email-only OTP for every buyer, §4.5 consent set with `consentRevision`, Pay Page as the only card entry, save-card default off, UUID `providedId` wallet write, test hooks) and added SMTP/publisher email transports with a designed code email. Sprint 0002 explicitly carried "multi-day products" and the SMTP lane to Sprint 0003.
- **Semantic prior art.** The index covers `wallet-repos/` only; nothing there bears on offers, passes or email. The relevant prior art is unindexed and listed under *Relevant Codebase Areas*.
- **Chapter context.** none (`docs/chapters/` does not exist).
- **Constraints to respect.** No real cards, no live charges; secrets never printed; the harness lane must not start; BFF `erasableSyntaxOnly`, husky + lint-staged prettier, coverage floors 84/67/67/84; UI React 17 / react-router v5 / RTK / MUI v4 / webpack 5 / jest, floors 80/80; `npm install --legacy-peer-deps` in the UI; the contract doc `docs/contracts/short-term-pass-bff.md` is versioned and frozen at each sprint's Phase A.

## Pyramid Index

- L0: Move the Day Pass build from Design v1.2 to v4 — selectable 1/3/5-day products with range validity, the QR and receipt delivered by email instead of on the done page, and a login-free "View your pass" link and page — with the contract, consent templates, fixtures and copy updated and the deferred harness re-baselined on v4.
- L1:
  - **Catalog and order (CR-10, CR-11, CR-17):** offer selection on `PUT /order` (or a dedicated call) with consent re-render, `validUntil` from `durationDays`, Pass Terms and sidebar copy by label and range.
  - **Credential delivery (CR-12, CR-13):** QR rendered server-side into the pass email (inline image), receipt content in the same email, signed "View your pass" token and page; done page copy per v4; static vs rotating QR staged behind decisions CF-06/CF-07.
  - **UI parity with v4 (CR-14, CR-15, CR-16, CR-12 copy):** `.offers` radiogroup grid, `.days` line, label switch, mobile helper removal and input attributes, Kelly fixture, PassBlock without QR.
  - **Proof:** unit and route tests in both repos, orchestrator browser smoke at 1440/375 for each product, Mailpit check of the QR image and link (PR-06); parity element list and approved deltas regenerated from v4 (PR-05) for the still-deferred harness.
  - **Risks:** pricing unconfirmed (CF-04); email clients and inline images; token security for a login-free pass page; a second surface (`/signup/pass/:token`) in a shell that gates routes by club flags; `qrcode.react` is a browser library — server-side QR needs a Node renderer.
- L2:
  - Seed → `docs/prd/Change_Requests_2026-09-15.md` §A–E; v4 anchors `day-passv4.html` lines 350–410 (`PRODUCTS`, `validityLabel`, `DOCS.terms`), 465 (`offerCards`), 589–590 (done copy), 624–629 (sidebar labels).
  - PRD → `Consolidated_PRD_v3.4.md` D18 (line 42), D41 (line 70), UC step 6 (line 140), §5A item 6 rotating QR (line 293), FR-P1/FR-P6 (lines 218, 223), Q19 (line 437).
  - Code → *Relevant Codebase Areas* below; contract `docs/contracts/short-term-pass-bff.md` §4 (routes), §4a, §10 register.

## Semantic Index

- **Available (partial)** — Token cache: `/Users/bjornloftis/claudeprojects/prospects-ui/repos/` (online-join UI/BFF/MICO, unindexed) and `/Users/bjornloftis/claudeprojects/wallet-repos/` (indexed). Index entrypoint: `/Users/bjornloftis/claudeprojects/prospects1/docs/semantic-index/README.md`. Access: read entrypoint, follow routing nodes, open leaf citations; use `rg` against the token cache for targeted searches. Prior art retrieved: the entrypoint and `themes/` routes concern wallet identity, agreement numbers, sync and flags — **none found for this seed**. For this sprint use `rg` directly under `repos/online-join-ui/src` and `repos/online-join-bff/src` (paths below); do not scan `repos/mico`.

Planning agents drafting this sprint must read the index entrypoint when available, follow routing nodes to relevant leaves, and run `rg` searches against the token cache before proposing architecture or implementation approaches. Do not attempt to scan the full token cache; use the index to sniff relevant areas first.

## Chapter Context

No chapter link selected — `docs/chapters/` does not exist in this repo.

## Recent Sprint Context

- **SPRINT-0001 (done):** Day Pass single-flow checkout in UI + BFF (checkout cookie, identify/challenge/verify, order, purchase orchestrator with mock adapters, Pay Page session by purpose, prospect-wallet save behind a gate). G2 parity and G4 hosted proof transferred to Sprint 0002.
- **SPRINT-0002 (in-progress; A–C complete, D/E1/E2 deferred, S5 pending B1):** v1.2 parity; §4.5 consent set (`ConsentDocumentSet`, `templateVersion`, `renderedHash`, `consentRevision`, attestation with the exact Pay text); OTP for every email with lookup after consumption; Pay Page only; save default off; UUID `walletProvidedId` + `oj_*` metadata; `STP_TEST_HOOKS` testing routes (`/testing/{outbox,state,reset}`); P1-1…P1-6 QA fixes; self-hosted Inter; SMTP (Mailpit) and publisher (route AMZ) email transports; designed code email from `email-1-verification-code.html`. Execution summary: `docs/sprints/drafts/SPRINT-0002-EXECUTION-SUMMARY.md`; open items: `SPRINT-0002-BLOCKERS-UI.md` Q-1…Q-9 (Q-2 recognized-person mobile not persisted; Q-1 brand casing "CORE's").

## Relevant Codebase Areas

Paths: `UI/` = `repos/online-join-ui/src/`, `UI-T/` = `repos/online-join-ui/__tests__/`, `BFF/` = `repos/online-join-bff/src/`.

**BFF — catalog, order, consent**
- `BFF/services/shortTermPass/ports/clubCatalog.ts` — `CatalogOffer {offerId, name, amountMinor, currency, perks, durationDays, maxDaysAhead?}`, `CatalogClub` (`address?`, `links.passTerms|privacy`, `consentOverrides`), `getOffers(clubNumber)` returns a list, `getConsentDocuments(club, offer, {visitDate, todayIso})`.
- `BFF/services/shortTermPass/fixtures/catalog.ts` — Riverside `day-pass-1-day` $18.00; Core South `day-pass-gym-floor` "Gym Floor" $25.00 with perks; `FIXTURE_OFFERS_BY_CLUB` (one offer per club today).
- `BFF/services/shortTermPass/order.ts` — `requireOffer` takes **the first** offer (`const [offer] = await catalog.getOffers(...)`, line 37); order shell fixes `offerId/offerName/amountMinor/currency/durationDays/visitDate=today/maxVisitDate`; `isVisitDateAllowed`; `applyOrderUpdate` handles `visitDate/adult/waiver/saveCard/marketingOptIn/smsNoticeShown` — **no offer change path**.
- `BFF/services/shortTermPass/ports/checkoutStore.ts` — `StoredOrder {offerId, …, durationDays, visitDate?}`.
- `BFF/services/shortTermPass/fixtures/consentTemplates.ts` — `TemplateContext {legalName, brandWord, offerName, amount, dayLabel…}`; `passTermsHtml` hard-codes "1-day pass to {legalName}, valid {dayLabel}"; `visitDateLabel` renders one day ("Today · Wed, Sep 9"); `CONSENT_TEMPLATE_VERSIONS`; `renderConsentDocumentSet`, `consentRevisionOf`, `payButtonTextFor`.
- `BFF/routes/shortTermPass/schemas.ts` — contract v2 types: `OfferSummary` (line 133), `OrderRequest` (line 74: no `offerId`), `OrderSummary` (line 185: `offerId, offerName, amountMinor, currency, visitDate?, minVisitDate, maxVisitDate?, consents, saveCard, ready`), `PurchaseResult.pass {status, passId?, visitDate?, qrPayload?}` and `.delivery {status, channel?, masked?}` (line 321), JSON schemas alongside.
- `BFF/routes/shortTermPass/{index,checkouts,order,purchase}.ts` — router (`POST /checkouts`, `PUT /checkouts/:id/order`, `POST /checkouts/:id/purchases`, `GET …/purchases/:pid`, `…/wallet-retry`, hooks-only `testing/`); `CreateCheckoutResponse.offer` is a single offer.

**BFF — purchase, pass, delivery**
- `BFF/services/shortTermPass/purchaseOrchestrator.ts` — order: validate → authorize → persist prospect → wallet → finalizeSale + capture → `issue` (one retry then refund) → `deliver` (never blocks); lines 539–579 set `result.pass` and `result.delivery`.
- `BFF/services/shortTermPass/ports/passSale.ts` — `IssuePassInput {…, visitDate, durationDays, firstName, lastName}`, `IssuedPass {passId, visitDate, qrPayload}`; `adapters/mock/passSale.ts` builds `qrPayload = STP1|passId|club|visitDate|sig` (sha256 truncated, idempotent by purchaseId).
- `BFF/services/shortTermPass/ports/delivery.ts` — `DeliveryInput {channel, destination, passId, receiptNumber, visitDate, clubName, checkoutId?}`; `DeliveryPort.deliver`. Adapters: `adapters/mock/outbox.ts` (`MockOutbox`), `adapters/smtp/mailer.ts` (`SmtpMailer`; `passEmail()` is plain text/HTML "Your 1-day pass at {club} - {date}", **no QR, no receipt content, hard-coded "1-day"**), `adapters/publisher/emailPublisher.ts` (`EmailPublisherMailer`, `buildEngineRequest`, base64 HTML, route `AMZ`), `adapters/smtp/templates/verificationCode.ts` (designed code email; `ClubMailContext`; pattern to follow for a pass/receipt email), `adapters/index.ts` (transport selection), `ports/verification.ts` (`SendCodeInput.club/expiresInMinutes`, `toClubMailContext`).
- `BFF/services/shortTermPass/config.ts` — `STP_EMAIL_TRANSPORTS`, boot guard, `STP_TEST_HOOKS`, `STP_NON_PRODUCTION` (new, `53e549e`), `CODE_TTL_MS`.
- `BFF/services/shortTermPass/ports/purchaseStore.ts` — stored purchase (`passId?`), consent snapshot; `routes/shortTermPass/testing/routes.ts` — `/testing/state` exposes purchases incl. `pass` and `delivery`.
- Session/cookie: `BFF/routes/shortTermPass/context.ts` (401 `CHECKOUT_EXPIRED`), `utils/middlewares/{requireShortTermPass,csrf,originAllowlist,rateLimit}.ts` — a login-free pass page must **not** depend on the checkout cookie.

**UI**
- `UI/routes/ShortTermPass/steps/IdentifyStep.tsx` — renders `<OfferCard offer={checkout.offer} />` (single, pre-selected); `components/OfferCard.tsx` (radio `id="offerRadio"`, "Selected" chip, price via `moneyWhole`, name, perks).
- `UI/routes/ShortTermPass/components/OrderSummary.tsx` — `DAY_LABEL = 'Day pass applies on'`, date input, `dayLabel(visitDate, today)` help and "Valid" row, line item via `lineItemLabel`; `format.ts` (`dayLabel`, `durationLabel`, `lineItemLabel`, `money`, `moneyWhole`).
- `UI/routes/ShortTermPass/steps/DoneStep.tsx` + `components/PassBlock.tsx` — QR via `qrcode.react` `QRCodeSVG` (`.qr` block), `deliverySentence` ("Show this at the front desk… We emailed it to … too."), titles/alerts; `steps/{NewVisitorStep,RecognizedStep}.tsx` — `MOBILE_HELP = "We'll text your pass here on the day."`, mobile field `#second`.
- `UI/reducers/shortTermPass/shortTermPassSlice.ts` — `checkout.offer: OfferSummary`, `order`, `consent`, `updateOrder` thunk with `generation`, `applyOrderUpdate` (line ~426), `CheckoutController` owns Pay/PayPage lifecycle; `UI/services/shortTermPass.ts` (`updateOrder`), `UI/interfaces/api/shortTermPass.ts` (mirror of contract v2; `offerId` at 128/211, `qrPayload` at 358).
- `UI/routes/SignupShell.tsx` — react-router v5 `Route`s for `PAGES.*`; guest routes gated by `onlineProspects`; where a `/signup/pass/:token` page would mount; `UI/styles/short-term-pass.scss` (v1.2 stylesheet: `.offer`, `.page` grid `minmax(0,1fr)`, `.pass .qr`).
- Tests: `UI-T/routes/ShortTermPass/**` (CheckoutShell, CardCaptureSlot, SaveCardSwitch, layout), `UI-T/reducers/shortTermPass/`, `UI-T/services/shortTermPass.test.ts`; BFF `routes/shortTermPass/__tests__/{purchase,order,verify,identify,consentEvents}.test.ts`, `services/shortTermPass/__tests__/{smtpMailer,emailPublisher,walletWrites,platformWallet,config}.test.ts`, demo `scripts/short-term-pass-demo.ts` (66 checks, reads codes from the outbox).

**Design and docs**
- `docs/prd/day-passv4.html` — source of truth; `docs/prd/day-pass-v1.2.html` superseded; `docs/prd/email-1-verification-code.html` — email design language (header legalName/location, code box, footer address + Pass Terms/Privacy links, "Sent on behalf of … by ABC Fitness"); **no design exists for the pass/receipt email or the View-your-pass page**.
- `docs/contracts/short-term-pass-bff.md` — contract v2 (§4 routes, §4a, §6 consents, §10 readiness register with Sprint 0002 email rows); `docs/demos/short-term-pass-local-demo.md` (Mailpit and publisher sections); `docs/validation/short-term-pass-sprint-0002-{smoke,traceability}.md`; `docs/SEMANTIC-INDEX.md` (Sprint 0002 code map to extend).
- Orchestrator smoke driver (puppeteer-core) lives in the session scratchpad `smoke/smoke.mjs`; `tools/day-pass-harness/` holds untouched scaffolding (deferred).

## Constraints

- Must integrate with the Sprint 0001/0002 architecture: ports and adapters, contract-first (freeze contract v3 in `docs/contracts/short-term-pass-bff.md` before lanes code), consent revision recomputed whenever price or validity changes, one consent snapshot per purchase, `generation` on every mutating call, test hooks only behind `STP_TEST_HOOKS`.
- Same branches and PRs (`prospect-wallet/sprint-0001`, #524/#96) unless the interview says otherwise; commit messages start "Sprint 0003".
- No real cards, no live charges, no secrets in logs or docs; nothing in `mico/**`, wallet repos, or membership Pay Page behaviour.
- The harness lane (parity loop, agent runs) remains **deferred until the user says**; this sprint may re-baseline its inputs (element list, approved deltas, states) but must not run it.
- Fixture data is not design: Riverside stays the demo default; Core South `90033` is the v4 club (Gym Floor 1/3/5, `m@m.com` Kelly Reyes). Multi-day prices are provisional (CF-04) and must be data, not code.
- Refund copy follows PRD D15/D22, not v4's "Full refund any time before the first valid day" (recorded delta carried from Sprint 0002).
- Coverage floors and lint must hold; husky/lint-staged in the BFF; UI `npm install --legacy-peer-deps`.
- Server-side QR rendering requires a Node QR library (e.g. `qrcode`) in the BFF; email clients vary on inline images (CID vs data URI vs hosted) — the plan must choose and justify, and the publisher path (base64 HTML to email-publisher-service) constrains attachments.
- A login-free "View your pass" page is a public, token-addressed surface: tokens must be unguessable, scoped to one pass, time-bounded to the pass window (+ grace), revocable, and never reveal more than the pass itself; rate-limited; no PII beyond first name and masked contact. Rotating QR (§5A item 6) needs a signing key and a verifier the desk does not yet have — stage static first unless the interview decides otherwise.

## Success Criteria

- A buyer at Core South can pick 1-, 3- or 5-day Gym Floor, sees the price/validity/Pass Terms/Pay text change, and completes a mock purchase whose recorded consent snapshot matches the chosen offer and range; Riverside (one product) is unchanged in behaviour except copy.
- The done page shows v4 copy (no QR); the pass email in Mailpit shows the receipt (number, item, amount, validity, seller) and a scannable QR image, plus a "View your pass" link that opens a login-free page rendering the same pass; the link is refused after expiry/revocation.
- Contract v3 documented and frozen; UI and BFF type-check against it; tests per CR; coverage floors hold; orchestrator browser smoke at 1440/375 for each product; PR-06 check recorded; traceability table CR-10…CR-17 → commits/tests; register rows for CF-04…CF-07; parity inputs regenerated from v4 (PR-05) without running the loop.
- Completion vocabulary distinguishes: *v4 changes complete; pass email + link proven locally (Mailpit); live email unverified (publisher 503); hosted capture unverified (B1); parity and agents deferred*.

## Open Questions

Drafts should propose answers, with the decision surface for the interview:

1. **Offer selection API.** Extend `PUT /order {offerId}` (re-render consents, reset waiver acceptance? keep date?) or a dedicated `POST /checkouts/:id/offer`? Should `POST /checkouts` return `offers[]` plus a default `offer`, and must selection be allowed before identify (v4 selects on the identify screen, before any order exists)?
2. **Validity model.** `validUntil` computed by the BFF from `durationDays` (calendar days, club-local, inclusive) — where does it live (`OrderSummary`, `IssuedPass`, receipt), and how do Pass Terms and `consentRevision` incorporate it? What about `maxVisitDate` for multi-day passes?
3. **Pass email content and QR.** Inline PNG via CID (nodemailer) vs data URI vs hosted image URL (needs a public BFF route); how does the publisher transport (base64 HTML) carry it? Should the email QR be the static `qrPayload` (D41 static) while the page rotates, or one static payload everywhere for v1 (CF-07)?
4. **"View your pass" token and page.** Token format (random id + server lookup vs signed JWT-like), lifetime (pass window + grace?), storage (purchase store), route (`GET /api/short-term-pass/passes/:token` + UI `/signup/pass/:token`), rate limiting, what the page shows, and whether rotation ships behind a flag or is deferred to a register row (CF-06).
5. **Done page and receipt.** v4 copy exactly; do we keep the Sprint 0002 truthful `deliverySentence` variants for `pending|failed` (v4 assumes success)? Where does the "View your pass" link appear on the done page?
6. **Multi-day pricing and catalog.** Provisional fixture prices (CF-04) with a `provisional: true` marker in the capability report? Which clubs get which durations in fixtures (Riverside single, Core 1/3/5)?
7. **Mobile field.** CR-14 removes the helper; does the transactional-SMS notice text stay as is (D37)? Any change to `RecognizedStep` where the same helper exists?
8. **Parity re-baseline (PR-05).** What artefacts can be produced now without running the harness: v4 element list, approved-delta manifest, state list (eleven states plus one per extra offer), Kelly fixture — and where they live.
9. **Sequencing and lanes.** Phase A contract freeze; then parallel BFF and UI lanes as in Sprint 0002? What is the minimal vertical slice that lets the user "see something functioning" first (offer selection end-to-end before email/link work)?
10. **Branching.** Continue on `prospect-wallet/sprint-0001` (PRs #524/#96 absorb) or start `prospect-wallet/sprint-0003`? Note the branches now also carry prerelease version bumps for the dev deployment.
