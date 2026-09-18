# Sprint 0004 — blockers, feasibility record, removal inventory and Phase A notes

Executor: Claude Fable 5.1 (orchestrator), 2026-09-18. Branches `prospect-wallet/sprint-0004` in `repos/online-join-ui` (off `origin/main` `b6dae7d`, 8.33.0-daypass.2) and `repos/online-join-bff` (off `origin/main` `f5c92ca` — includes PR #106, 1.2.3); pushed and opened as PRs only at the end of Phase E. Lane files: `SPRINT-0004-BLOCKERS-BFF.md`, `SPRINT-0004-BLOCKERS-UI.md`.

## Baseline (A1)

| Item | Value |
|---|---|
| Node / npm | v26.3.0 / 11.16.0; `npm ci --ignore-scripts` in both clones (AppDynamics postinstall skipped), `npx husky` for the BFF hook |
| BFF `npx tsc --noEmit` | clean at branch creation and at the Phase A exit |
| UI `npx tsc --noEmit -p tsconfig.json` | **8 pre-existing errors** at branch creation (all under `routes/PaymentPage` and two payment tests — the Sprint 0003 list, unchanged) |
| Pre-existing UI test failures (never counted green) | `__tests__/helpers/transformers.test.ts` (date-dependent); `__tests__/routes/ReviewPage/OfferDetails/OfferDetails.test.tsx` (intermittent) |
| BFF suite at branch creation | 71 suites / 710 passed (Sprint 0003 E5 figures) |
| Mailpit | `stp-mailpit` up (Docker, healthy), SMTP :2525, UI :8025 |
| Dev cluster | reachable (`kubectl --context k8s-lower-wlr -n dev`); BFF image `v1.2.3`, ingress `onlinejoin.dev.abcfitness.net` |
| `gh` | authenticated |

## Blockers and gates recorded (A2 feasibility, half-day time-box)

### CF-13 — DataTrak service layer does not expose the guest-pass fields (blocked; fixtures until the DT PR)

Probed `https://datatrak-service.dev.abcfitness.net/external/club/getClubDefaultExternal.spr?clubNumber=09003` with MICO's dev credential (read from the local MICO `application-local.yml` into a shell variable — **never printed, never committed**). 200 in JSON and XML. Shape recorded (scrubbed) at `online-join-bff/src/services/shortTermPass/fixtures/datatrak/getClubDefaultExternal.recorded.json`: `club.{number, name, phone, website, billingCountry, classes, prospects, prospectTerms (base64 HTML), address{…}, branding{…}, hideEnrollPage}`. **No `timezone`, no waiver text, no `guestPassOnline` / `contractDays` / `visits`.** MICO's `SaleItem` DTO carries none of the three catalog fields either. **Effect:** `STP_CATALOG_SOURCE=fixture` in dev; the `DatatrakServiceCatalog` adapter (B11) is unit-pinned against **labelled synthetic** fixtures (`*.synthetic.json`) and fails closed per club; E4 records the live read as blocked. **Owner:** Chancy → PK (DT PR). Smallest fix named for the DT PR: `guestPassOnline`, `contractDays`, `visits`, `itemType` on the sale-item response; `waiverText` and `timezone` on the club-default response.

### CF-14 — `saleItems.spr` refuses a request without a member id (refused)

`GET …/pos/saleItems.spr?club=09003` → **400** `application/problem+json` "Required parameter 'memberId' is not present."; `…&memberId=` → 200 `{"club":null,"saleItems":null,"messages":{"status":"error","message":[{"text":"Invalid request."}]}}`. Both recorded under `fixtures/datatrak/saleItems.*.recorded.json`. **Effect:** the pre-identity catalog read cannot use this endpoint; the DT PR needs a club-scoped (member-less) query or a dedicated guest-pass items call. **Owner:** Chancy.

### CF-15 — `addProspect` field names, idempotency, deactivate / conditional update (asked; unanswered)

MICO's `ProspectController` sets `club, firstName, lastName, street, address2, city, state, zip, email, issueDate, signatureImage, campaign, country, primaryPhone, cellPhone, referredById, agreementEntrySource` and the four consent flags `commDirectMail, commEmail, commPushNotif, commSms` from **one** `messagingConsent` value; no begin / expiration / visits / item fields are set on MICO's path. Handoff text for Chancy / Mark: (1) field names for begin date, expiration date, number of visits, sale item and the opt-in on `/member/addProspect.spr` (one value or four `comm*` flags?); (2) whether the call is idempotent by a caller key or returns the existing member on a duplicate contact; (3) whether a deactivate (soft delete) and a conditional update (repaint only if the record is unchanged) exist. **Effect:** platform `ProspectPort` stays `notEnabled`; the mock proves the order; the overlapping-active-pass case is excluded from the pilot (RQ-4).

### Security observation (not a blocker) — DataTrak service refuses unauthenticated reads

Without a credential the gateway answers **404** `{"error_code":"N404"}`; fail closed. The credential is a static Basic header; it must live in the `platform-online-join-bff` secret as `STP_DATATRAK_SERVICE_AUTH` (PLATFORM ticket, D3) and is never logged.

### Secrets in `helm-configs/online-join-bff/dev.yaml` (pre-existing; recorded, not changed by this sprint)

The dev values file carries `STP_TEST_HOOKS_KEY`, `STP_SESSION_SECRET`, `STP_CODE_SECRET`, `STP_PASS_LINK_SECRET` and `STP_MOCK_OTP_CODE` as plain values (Sprint 0002 / 0003 PRs #3083 / #3088). D1 removes the three pass-link keys and keeps the rest as they are; moving the remaining dev secrets into the k8s secret is a PLATFORM housekeeping row, not part of this sprint. Values were seen while reading the file and are not reproduced anywhere in this repo or in the PRs.

### A2(b) — `ctx.hostname` behind the ingress: code-verified, runtime proof in E3

`services/application.ts` sets `app.proxy = isProduction` (true whenever `NODE_ENV !== 'development'`, so in dev); Koa then reads `X-Forwarded-Host` before `Host`, and ingress-nginx sets it to the request host. B12's `standaloneHost` middleware compares the lower-cased, port-stripped `ctx.hostname` with `STP_STANDALONE_HOSTS`. E3 on `guestpass.dev.abcfitness.net` is the runtime confirmation (the entry document on the new host carries `window.guestPass.standalone:true`).

### A2(c) — dev hooks through the pod: passes

`POST https://onlinejoin.dev.abcfitness.net/api/short-term-pass/checkouts {"clubNumber":"90030"}` → 201; `GET …/testing/state?checkoutId=…` through the ingress → **403** (loopback rule intact); `kubectl --context k8s-lower-wlr -n dev port-forward deploy/online-join-bff 18080:8080` then `GET http://127.0.0.1:18080/api/short-term-pass/testing/state?checkoutId=…` with `X-STP-TEST-KEY` → **200** `{checkout:{id, state:'identify', generation:0, emailVerified:false, boundMember:false}, purchases:[], wallet:{…}, outbox:[]}`. No hooks-policy change (R14).

### Carried, unchanged

B1 Pay Page credentials are absent locally (hosted capture unverified locally; dev has `PAY_PAGE_*` — E3 records the hosted-card result truthfully). LD flag does not exist (`STP_LOCAL_FLAG_OVERRIDE` in dev until PLATFORM creates `guest-pass-online`, CF-17). Harness lane deferred by the user.

## Removal inventory (A5) — executed by B0 / C0; `rg` proof required at each lane's exit

### online-join-bff — DELETE

`src/routes/shortTermPass/passes.ts`, `src/routes/shortTermPass/__tests__/passes.test.ts`, `src/services/shortTermPass/passCredentials.ts`, `src/services/shortTermPass/passView.ts`, `src/services/shortTermPass/qr.ts`, `src/services/shortTermPass/ports/passCredentialStore.ts`, `src/services/shortTermPass/adapters/mock/passCredentialStore.ts`, `src/services/shortTermPass/adapters/smtp/templates/passEmail.ts` (→ renamed / rewritten as `prospectMailStandIn.ts` by B6), `src/services/shortTermPass/testing/passDeliveryFixture.ts`, `src/services/shortTermPass/testing/qrDecode.ts`, `src/utils/logRedaction.ts`, `src/utils/__tests__/logRedaction.test.ts`, `src/services/shortTermPass/__tests__/{passCredentials,passEmail,passView,qr}.test.ts`. Dependencies: `qrcode`, `@types/qrcode`, `jsqr`, `pngjs`, `@types/pngjs` (package.json + lockfile).

### online-join-bff — MODIFY (remove the v3 surface named)

| File | Remove |
|---|---|
| `src/routes/shortTermPass/index.ts` | `passChain`, `passViewRoute`, `passQrRoute`, `passLinkRoute`, `passLinkResendRoute`, `PASS_VIEW_PER_IP`, `PASS_LINK_RESENDS_PER_HOUR`, `passLimiter`, `passLinkLimiter`, `passLinkSecret`, `passLinkGraceHours`, `publicBaseUrl` deps |
| `src/routes/shortTermPass/context.ts` | `passLimiter`, `passLinkLimiter`, `passLinkSecret`, `passLinkGraceHours`, `publicBaseUrl` on `ShortTermPassDeps` |
| `src/routes/shortTermPass/purchase.ts` | `passLinkRoute`, `passLinkResendRoute`, `loadOwnedIssuedPurchase`, `tokenOf`, `linkOf`, `serializePerPurchase`, `PASS_NOT_ISSUED_MESSAGE`, `RESEND_THROTTLED_MESSAGE`, `response.pass.viewPath` on the 201 |
| `src/routes/shortTermPass/testing/routes.ts` | `revokePassRoute`, outbox `viewPath` / `label` / `validUntil` / `passId`, state `pass.viewPath` strip (no field to strip), `passLimiter` / `passLinkLimiter` resets |
| `src/routes/shortTermPass/schemas.ts` | every `@deprecated` member: `OfferSummary.{perks,durationDays,label}`, `OrderRequest.{visitDate,adult}` (schema properties too), `OrderConsents.adult`, `OrderConsents.marketingOptIn.version`, `OrderSummary.{durationDays,label,visitDate,validUntil,minVisitDate,maxVisitDate}`, `CreateCheckoutResponse.offer`, `PurchaseResult.pass.{passId,visitDate,validUntil,qrPayload,viewPath}`, `PurchaseReceiptSummary.{label,visitDate,validUntil}`, `PassLinkResponse`, `PassLinkRotateResponse`, `PASS_VIEW_STATUSES`, `PassViewStatus`, `PassView`, `PASS_TOKEN_PATTERN`, `isPassTokenShape` |
| `src/services/shortTermPass/validity.ts` | the `@deprecated` block: `DEFAULT_PASS_LINK_GRACE_HOURS`, `validUntilOf`, `durationLabelOf`, `validityLabel`, `dateFieldLabelOf`, `linkExpiresAtOf`, `passStatusOn`, `rangeLengthDays` |
| `src/services/shortTermPass/order.ts` | `visitDate` / `validUntil` / `maxVisitDate` / `adult` handling (`isVisitDateAllowed`, `dateFieldLabel`, adult in `isOrderReady`, `applyOrderUpdate`), `ADULT_REQUIRED_MESSAGE`, `addDays`, `isValidCalendarDate` (use `validity.ts`), the `durationDays` / `perks` / `label` fallbacks in `toOfferSummary` / `createOrderShell` / `toOrderSummary` |
| `src/services/shortTermPass/purchaseOrchestrator.ts` | `PassLinkFacts`, `mintPassLink`, `deliverPass` (rewritten for the stand-in), `issuePass`, `passRangeOf`, `OrchestratorDeps.{passLinkSecret,passLinkGraceHours,publicBaseUrl}`, adult assertion, `visitDate` |
| `src/services/shortTermPass/receipt.ts` | `visitDate` / `validUntil` / `label` / `lineItemOf` → `beginDate` / `expirationDate` / `item = offer name` |
| `src/services/shortTermPass/ports/{checkoutStore,clubCatalog,passSale,purchaseStore,delivery,identityDirectory}.ts` | every `@deprecated` field; `PassSalePort.issue`, `IssuedPass`, `IssuePassInput`; `DeliveryInput.{qrPayload,viewPath,links}`; `PurchaseConsentSnapshot.adult`; `CONSENT_NOTICE_IDS` `marketingOptIn`; checkpoint `ISSUED` |
| `src/services/shortTermPass/fixtures/{catalog,consentTemplates}.ts` | `FIXTURE_OFFERS_BY_CLUB` alias, `perks` / `durationDays` on the `product()` helper, `visitDateLabel`, `CONSENT_NOTICE_VERSIONS.marketingOptIn`, the `marketingOptIn` notice in `renderConsentNotices`, `ConsentDocumentInput.visitDate` |
| `src/services/shortTermPass/adapters/mock/{passSale,verification,faults,payment,identityDirectory}.ts` | `issue`, `passes()`, `issueAttempts()`, `STP2` payload; outbox `viewPath` / `label` / `validUntil`; faults `auth-timeout`, `prospect-failure`, `issue-failure` (aliases) |
| `src/services/shortTermPass/adapters/{index,platform/catalog,smtp/mailer,publisher/emailPublisher}.ts` | `passCredentials` wiring, `PlatformClubCatalog` (replaced by `DatatrakServiceCatalog`; the `FIXTURE_OFFER` fallback goes), `passMailWithAttachment` / CID, publisher pass email |
| `src/services/shortTermPass/config.ts` | `passLinkSecret`, `passLinkGraceHours`, `publicBaseUrl`, `assertPassLinkConfig`, `assertPublicBaseUrl`, `resolvePublicBaseUrl`, `DEV_PASS_LINK_SECRET`, `parseGraceHours` |
| `src/utils/middlewares/historyFallback.ts` | `PASS_VIEW_DOCUMENT_PATTERN`, `PASS_VIEW_REWRITE`, `redactPassTokens` logger |
| `src/routes/static/index.html.ts` | `isPassDocument`, `NO_APPDYNAMICS`, the `/pass/` skip; flag key `oj_short_term_pass_checkout` → `guest_pass_online` |
| `src/services/application.ts` | `installLogRedaction()` |
| `.env.example` | `STP_PUBLIC_BASE_URL`, `STP_PASS_LINK_SECRET`, `STP_PASS_LINK_GRACE_HOURS` rows |
| `scripts/short-term-pass-demo.ts` | rewritten by B13 (Demo 0–6) |
| Tests to delete or rewrite (v3 pins) | `routes/shortTermPass/__tests__/{offer,order,purchase,checkouts,identify,verify,testingRoutes}.test.ts`, `services/shortTermPass/__tests__/{order.service,platformCatalog,wallet.service,purchaseMocks,smtpMailer,emailPublisher,config}.test.ts`, `utils/middlewares/__tests__/historyFallback.test.ts`, `routes/static/__tests__/index.test.ts` |

`rg` proof at the B0 exit: `rg -n 'pv1|viewPath|qrPayload|validUntil|durationDays|visitDate|adult|PASS_LINK|passCredential|passView|renderPassMail|redactPassTokens|isPassDocument|PASS_VIEW|maxDaysAhead|linkExpiresAt' src scripts` returns only the changelog comments in `schemas.ts` / `validity.ts` headers.

### online-join-ui — DELETE

`src/routes/ShortTermPass/PassViewPage.tsx`, `src/routes/ShortTermPass/components/PassCredential.tsx`, `src/routes/ShortTermPass/components/PassReceipt.tsx`, `__tests__/routes/ShortTermPass/PassViewPage.test.tsx`. Dependency: `qrcode.react` (package.json + lockfile).

### online-join-ui — MODIFY (remove the v3 surface named)

| File | Remove |
|---|---|
| `src/App.tsx` | the `matchPath(PAGES.passView)` branch and the `PassViewPage` import |
| `src/common/constants.ts` | `PAGES.passView` (add `PAGES.guestPass`) |
| `src/interfaces/api/shortTermPass.ts` | every `@deprecated` member (mirror of the BFF list) |
| `src/services/shortTermPass.ts` | `getPassLink`, `resendPassLink`, `getPassView`, `PASS_VIEW_BASE`, `PASS_TOKEN_PATTERN`, `isPassTokenShape`, `passQrImageUrl` |
| `src/reducers/shortTermPass/shortTermPassSlice.ts` | `loadPassLink`, `resendPassEmail`, `PassLinkStatus`, `passLink` state, `viewPath` handling, `visitDate` / `adult` in `applyOptimisticOrder`, `validUntilOf` import |
| `src/selectors/shortTermPass.ts` | `day` / `adult` gates in `consentGatesSelector` and `canPay` (`visitDate`, `adult`) |
| `src/routes/ShortTermPass/format.ts` | `dateFieldLabel`, `validityLabel`, `dayLabel` (as start-day label), `addDaysIso`, `validUntilOf`, `RANGE_SEPARATOR`, `durationLabel`, `lineItemLabel`, `resendToast`, `DAY_FIELD_LABEL`, `START_FIELD_LABEL`, `DAY_TOAST`, `ADULT_TOAST` (add `useByLabel`, `validityLine`) |
| `src/routes/ShortTermPass/components/OrderSummary.tsx` | `.dayfield` block, `DATE_DEBOUNCE_MS`, `isSelectableDate`, `dayToast`, `DAY_LABEL` / `START_LABEL` exports, `resolvePassRange` (→ `useBy` / begin / expiration), the "Your pass" View row |
| `src/routes/ShortTermPass/components/ConsentBlock.tsx` | the 18+ checkbox, `ADULT_TITLE`, `ADULT_SUB`, `ADULT_CHECKBOX_ID` reader |
| `src/routes/ShortTermPass/components/OfferCard.tsx` | `durationLabel` `.days` line (→ `validityLine`), perks `<ul>` |
| `src/routes/ShortTermPass/components/PassBlock.tsx` | `viewPath`, `VIEW_PASS_LABEL`, `RESEND_PASS_LABEL`, `onResend`, `.pass-links` |
| `src/routes/ShortTermPass/steps/DoneStep.tsx` | `loadPassLink` / `resendPassEmail` effects, `validityLabel`, `durationLabel` |
| `src/routes/ShortTermPass/hooks/usePayAction.ts` | `ADULT_CHECKBOX_ID`, `DAY_INPUT_ID`, the `day` / `adult` gate prompts |
| `src/routes/ShortTermPass/components/MarketingOptIn.tsx` | the notice-copy reader (→ the `marketing` document + `DocumentDialog`) |
| `src/styles/short-term-pass.scss` | `.pass-view` (incl. `.qr`), `.pass-links`, `.dayfield` |
| Tests to delete or rewrite (v3 pins) | `__tests__/routes/ShortTermPass/{format,copy,layout,OfferCards,OrderSummary,DoneStep,PassBlock,IdentifyStep,NewVisitorStep,RecognizedStep,ShortTermPassPage,CardCaptureSlot,SaveCardSwitch}.test.*`, `__tests__/reducers/shortTermPass/{shortTermPassSlice,shortTermPassSliceV3}.test.ts`, `__tests__/selectors/shortTermPass.test.ts`, `__tests__/services/shortTermPass.test.ts`, `__tests__/App.test.tsx` (pass-view branch) |

`rg` proof at the C0 exit: `rg -n 'passView|viewPath|qrcode|validUntil|durationDays|visitDate|adult|ADULT_' src __tests__` returns only the header comment of `interfaces/api/shortTermPass.ts` (and `BirthdateField` tests, which are membership code and out of scope — `adult` there is unrelated).

### helm-configs — MODIFY (D1)

`online-join-bff/dev.yaml` lines 80–90: remove `STP_PUBLIC_BASE_URL`, `STP_PASS_LINK_SECRET`, `STP_PASS_LINK_GRACE_HOURS` and their comment block; add the second ingress host + TLS, `STP_STANDALONE_HOSTS`, both origins in `STP_ALLOWED_ORIGINS`, `STP_CATALOG_SOURCE=fixture`; rewrite the Day Pass comment block for Guest Pass.

## Phase A exit state (what the lanes inherit)

- **Contract v4 frozen** (`docs/contracts/short-term-pass-bff.md`); types mirrored in `schemas.ts` and `interfaces/api/shortTermPass.ts` as **additive v4 + `@deprecated` v3** so both repos type-check at the exit (BFF `tsc` clean; UI `tsc` has new errors only in `src/selectors/shortTermPass.ts` (`adult` now optional — C1 removes the gate) and in v3-pinned tests — listed below).
- **Fixtures v4** landed: catalog (Riverside `day-pass`; Core `core-day-pass` / `core-flex-pass` / `core-anytime-pass` + hidden `core-3-visit-pass` and `core-towel-service`), directory (+ Priya, `access`, `barcode`, `marketingOptIn`), wallet (+ Priya's expired Mastercard 5454), `MockClubCatalog.getOffers` applies the v1 filter (`catalogEligibility.ts`), `MockIdentityDirectory` implements `ProspectPort` v4 (`create` with access, `repaint`, `deactivate`, `revert`, `lookupByOperation`; faults `create-failure`, `create-response-lost`, `deactivate-failure`, `revert-failure`, `auth-unknown`), consent set with the `marketing` document and Pass Terms `2026-09.3`, `validity.ts` v4 helpers, `CONTRACT_VERSION` on the checkout response, recorded + synthetic DataTrak fixtures.
- **Green at the exit:** BFF `catalog`, `identityDirectory`, `consentTemplates`, `validity`, `schemas` suites (144 tests); UI `shortTermPassTestData.test.ts`.
- **Known red at the exit — v3 pins the lanes clear in B0–B5 / C0–C5, never baseline:** BFF `routes/shortTermPass/__tests__/{checkouts,identify,verify,offer,order,purchase,passes,testingRoutes}.test.ts`, `services/shortTermPass/__tests__/{order.service,platformCatalog,wallet.service}.test.ts` (11 suites / 43 tests: fixture counts 8→9 people and 6→7 owners, `contractVersion` in `toMatchObject`, five documents, v4 ids / names / prices / windows, Pass Terms text, `passes.test.ts` deleted by B0). UI: `__tests__/routes/ShortTermPass/{format,copy,RecognizedStep,NewVisitorStep,DoneStep,OrderSummary,CardCaptureSlot,PassViewPage,IdentifyStep,SaveCardSwitch,OfferCards,ShortTermPassPage}.test.*`, `__tests__/reducers/shortTermPass/*.test.ts`, `__tests__/selectors/shortTermPass.test.ts` (16 suites / 112 tests incl. the `transformers` baseline) — all pinned to v3 ids / copy / `adult` / dates.
- **Decisions taken at A3 (lanes: do not re-decide):** (1) `OfferSummary` has no `perks` (DataTrak has no field; D57). (2) `validityLine` copy is "One time use only, valid today" / "One time use only, valid for N days"; the Pass Terms sentence is "{offerName} to {legalName}. {validityLine} · use by {Ddd, Mmm D}. Price … including tax. One-time purchase — …". (3) `receipt.item` and `pass.label` are the catalog item name. (4) `delivery.renderer ∈ {dt, bff-stand-in}`; platform mode = `delegated`. (5) The compensate route is `POST /checkouts/:id/purchases/:pid/compensate`. (6) `contractVersion: 4` on `POST /checkouts` and on 409 `details`. (7) The entry document exposes `window.guestPass = {standalone, basename}` and `window.featureFlags.guest_pass_online`. (8) `OFFER_ID_PATTERN` relaxed to `^[a-z0-9][a-z0-9-]{0,63}$` (DataTrak ids are numeric strings). (9) Mock faults renamed `auth-unknown` / `create-failure` (v3 names accepted until B4). (10) `CatalogClub.waiverText` maps to a `waiver` override with a content-derived version (CF-18 fallback = US template).
- **Approved deltas vs Design v6 (V2):** `VALID_DAYS = 30` / `today + 30` → days from the item (D71); `adultCb` gate → removed (D66); refund sentence → PRD D15/D22 (CF-16); "Core South" in the marketing paragraph → `{legalName}`; perks `<ul>` not rendered (D57); the v6 sidebar shows "{label} · {name}" → v4 shows the catalog name only (no duration label exists).

## Scope notes

- The A4 "UI test factories" deliverable landed with the deprecated v3 fields still populated so the v3 components render until C0/C2 replace them; the factory pin test is the only UI suite asserted green at the A exit.
- `MockIdentityDirectory` implements the full `ProspectPort` v4 already (A4) because the interface change would otherwise break `tsc`; B4 wires the orchestrator to it.
- The demo script compiles (`scripts/short-term-pass-demo.ts`, one optional-chaining fix) but still exercises the v3 flow; B13 rewrites it.
