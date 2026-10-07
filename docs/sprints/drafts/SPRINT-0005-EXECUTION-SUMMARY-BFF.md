# Sprint 0005 — BFF lane execution summary (`online-join-bff`, branch `prospect-wallet/sprint-0005`, PR #112)

Executor: Claude Fable 5.1 (BFF lane), 2026-10-07. Base `origin/main` `5e370a0`. Every statement below is about the **mock / unit-pinned** path unless it says otherwise; no remote host was probed, no credential printed, no DataTrak repo touched, `online-join-ui` and `helm-configs` unchanged.

## Commits

| Commit | Task | What landed |
|---|---|---|
| `2213ba8` | D3 | `adapters/platform/timezoneId.ts` (`canonicalTimezoneId`: `Intl.supportedValuesOf('timeZone')` exact match → explicit alias map → `Intl.DateTimeFormat` canonicalisation accepted only when it lands on a supported id, never `UTC` by fallback) + `__tests__/timezoneId.test.ts`. The `git mv saleItems.synthetic.json → guestPassItems.synthetic.json` (content-identical rename) was already in the index and rode along in this commit. |
| `43ff8bf` | D1 + D2 | `adapters/platform/datatrakServiceCatalog.ts` on the v4.1 field table; `catalogEligibility.ts` (`unknown-type`); `ports/clubCatalog.ts` (`'billing'`, comments); fixtures (`getClubDefaultExternal.synthetic.json` v4.1 content, `guestPassItems.synthetic.json` v4.1 envelope, NEW `guestPassItems.unavailable.synthetic.json`, README); `__tests__/datatrakServiceCatalog.test.ts` rewritten around `describe('matrix')`. |
| `8f8e156` | D4 | `scripts/short-term-pass-demo.ts` (`DT fields` line; live-read line *pending* with four preconditions; verdict 3 wording), `adapters/mock/catalog.ts` (`standsInFor` names `guestPassItems.spr`), `__tests__/catalog.test.ts` (assertion follows). The diff also carries prettier reflow of pre-existing long `log` / `check` lines (lint-staged) — formatting only. |
| `ca3bb38` | CI | Bump job: `1.3.0` (a minor this time). Pulled locally (`--ff-only`) before any further push. |
| `b22febc` | Sonar | First scan on #112 failed the gate with **one** new issue: S3776 cognitive complexity 17 > 15 on the demo's `main()` (`scripts/short-term-pass-demo.ts:800`) after the D4 `DT fields` line. Fixed behaviour-unchanged: the capability-notes loop lifted into `printCapabilityNotes` (same lines, same order); lint / tsc clean, demo 58 / 58 again. |

## Per task

| Task | Status | Evidence |
|---|---|---|
| D1 wire types, new endpoint, strict mapping | **done** (`43ff8bf`) | `getOffers` → `GET /club/guestPassItems.spr?clubNumber=`; `DatatrakClubDefaultResponse.club.prospectLiability` + `timezone`, `waiverText` removed from the wire type; `DatatrakGuestPassItem` / `DatatrakGuestPassItemsResponse` replace `DatatrakSaleItem*` (nothing else referenced them; the CF-14 history tests now run on the new types). `mapGuestPassItem`: `salePrice` → else `catalogPrice` (an unparsable `salePrice` such as `n/a` now falls back instead of pricing at 0 — the filter outcome for 0 was `no-price` anyway); `guestPassContractDays` / `guestPassVisits`; `itemType` strict via a three-entry table; missing / unknown → `{ kind: 'skipped', reason: 'unknown-type' }` short-circuited in the adapter and merged in catalog order by `partitionMappedItems` (so it appears in the report's skipped list). U6 envelope → `offers: { kind: 'error', reason: 'unavailable' }`; the `http 400 (member id required — CF-14)` hint is gone from the code. **Single-item re-read:** the orchestrator re-reads via `requireOffers` → `getOffers` (list) before side effects (`purchaseOrchestrator.ts:198`); `&saleItemId=` is documented in the adapter header as available but unused — no dead code added. |
| D2 fixtures + matrix tests | **done** (`43ff8bf`) | Six cells below; CF-13 / CF-14 tests kept and renamed "history". `__tests__/datatrakServiceCatalog.test.ts` 15 tests + `timezoneId.test.ts` 2 tests (17 total, was 9). |
| D3 timezone validation | **done** (`2213ba8`, wired in `43ff8bf`) | `America/Chicago` accepted; `US/Central` → `America/Chicago`; `Nonsense/Zone` → club fails closed `missing: ['timezone:invalid']`, report timezone `invalid`; `''` / `null` / key absent → `missing: ['timezone']` as today. Node fact pinned: this ICU canonicalises `EST` → `America/Panama` and lists neither `UTC` nor `Etc/UTC`, hence alias-before-fallback and `UTC` as an explicit alias target. |
| D4 capability report `dtFields` | **done** (`43ff8bf`, `8f8e156`) | `ClubReport.dtFields: 'present' \| 'absent'`; note prints `DT fields: present` or `DT fields: absent (off, old code or columns missing — unknown which)`; `standsInFor` / note name `guestPassItems.spr` and the two club fields, no CF-14 wording as current. Demo prints the capability table and now a `DT fields` line (`n/a` on the fixture catalog, which is what runs in fixture mode). |
| D5 liability path check (read only) | **done — no new exposure; carried finding registered** | See §D5 below. No code change in either repo. |
| D6 UI proof | **done — no UI change** | See §D6 below. |
| D7 dev switch-over | **pending by decision** | See §D7 below. |
| D8 gates, commits, PR | **done — PR #112 open, checks below** | lint clean · `tsc --noEmit` clean · `npm run build` clean · jest 69 / 69 suites, 706 passed, 2 skipped · coverage 97.47 / 86.5 / 97.19 / 98.28 (floors 84 / 67 / 67 / 84 untouched) · demo 58 / 58. |

## The six-cell matrix (U14–U16)

| Cell | Fixture file | Adapter outcome pinned |
|---|---|---|
| absent / club | `fixtures/datatrak/getClubDefaultExternal.recorded.json` | club `incomplete (missing timezone)`, timezone `missing`, consent texts `passTerms=club waiver=template`, `dtFields: absent` |
| absent / items | `saleItems.noMember.recorded.json` (400) · `saleItems.emptyMember.recorded.json` (error envelope) — **CF-14 history**, served on the `guestPassItems.spr` path to show fail-closed | `offers: { kind: 'http', status: 400 }` (note `offers http 400`, no `CF-14`) · `offers: { kind: 'error', reason: 'unavailable' }`; the request never carries `memberId` or `/pos/` |
| off / club | the same recorded file (one file, two labels) | `mapClubDefault` output deep-equal under both labels; file bytes carry none of `prospectLiability` / `timezone` / `waiverText`; club `incomplete (missing timezone)`, `dtFields: absent` |
| off / items | `guestPassItems.unavailable.synthetic.json` (`{ club: '09003', saleItems: null, messages: { status: 'error', message: [{ text: 'Not available' }] } }`) | `[]`, `offers: { kind: 'error', reason: 'unavailable' }`, note `offers error (unavailable); DT fields: absent (…)`, cached inside the 60 s window |
| on / club | `getClubDefaultExternal.synthetic.json` (v4.1: `prospectLiability` base64, `timezone: America/Chicago`) | resolves: `timezone: 'America/Chicago'`, `waiverText: '<h3>Assumption of risk</h3><p>Club-authored waiver.</p>'`, `prospectTerms: '<p>test</p>'`, ids from the resolver; report `club ok; location ok; timezone wire; consent texts passTerms=club waiver=club`, `dtFields: present` |
| on / items | `guestPassItems.synthetic.json` (five items) | exactly `core-flex-pass` (`amountMinor 3000` from `salePrice`, `catalogItemId cgi-flex-pass`, 7 days, 1 visit); skipped in catalog order `core-3-visit-pass (multi-visit), core-pt-session (not-a-product), core-mystery-item (unknown-type), core-towel-service (not-flagged)`; `dtFields: present`; consent set renders the club liability as the waiver and `Pay $30.00 and get my pass` |

Also pinned: `BILLING` → `billing` → `not-a-product`; an empty success list → `offers 0 eligible, skipped none; DT fields: present`; CAD from `billingCountry: CA`; a stray `waiverText` on the wire is ignored; `""` liability (null column) → template waiver.

## D5 — liability path check (read only, evidence)

Trace: `DatatrakServiceCatalog.mapClubDefault` → `CatalogClub.waiverText` → `fixtures/consentTemplates.ts` `overridesFor` (`:217-219`: `overrides.waiver = { html: waiverText, templateVersion: 'club-waiver-<sha8>' }`) → `renderConsentDocumentSet` (`html = override?.html ?? TEMPLATES[id](ctx)`) → `ConsentDocument.html` → browser contract → `online-join-ui/src/routes/ShortTermPass/components/DocumentDialog.tsx` line 36: `<div className="dt-modal-body">{parse(document.html)}</div>` with `html-react-parser` (`^4.2.0`), **no sanitiser** (no `dompurify` / `sanitize-html` in either `package.json`; no `sanitize` symbol in either `src`).

- **Is club-authored HTML rendered unsanitised today via `prospectTerms`?** Yes — `prospectTerms` → `overrides.passTerms` → the same `ConsentDocument.html` → the same `parse()` in `DocumentDialog`. `html-react-parser` converts markup to React elements; it does not strip `<script>` / event handlers by itself (scripts do not execute as React children, but `<img onerror>` / `<a href="javascript:">` / `<iframe>` style payloads are not removed).
- **BFF-side rendering:** the stand-in prospect mail (`adapters/smtp/templates/prospectMailStandIn.ts` `acknowledgedBlock`) interpolates `${doc.html}` unescaped for the acknowledged Pass Terms and waiver — the same two club overrides — in the **mock / labelled stand-in** mail only (platform mode delegates delivery to DataTrak and sends nothing). The OTP template and receipt do not render consent HTML.
- **Does `prospectLiability` add new exposure beyond `prospectTerms`?** **No new sink.** It is a second club-authored field through the identical path (same decoder, same override map, same dialog, same stand-in mail). Same author population (club staff editing club settings → Online), same byte limit class (CF-21 `VARCHAR2(4000)`).
- **Decision per A1:** no code change. **Carried finding registered:** *"BFF/UI HTML sanitiser for club-authored consent HTML (`prospectTerms`, `prospectLiability`): the BFF delivers club-authored HTML verbatim in `ConsentDocument.html`; the UI renders it with `html-react-parser` and the BFF stand-in mail interpolates it unescaped. Sanitise once at the BFF boundary (allow-list of block / inline / list tags, no `script` / `iframe` / `on*` / `javascript:`), re-hash after sanitising so `renderedHash` is what the visitor saw."* **Owner slot: SECURITY + UI.** No new dependency this sprint.

## D6 — UI proof (no UI code change)

`repos/online-join-ui` on `main` `3967c43`, `git status` clean before and after; `npx jest __tests__/routes/ShortTermPass/ShortTermPassPage.test.tsx --coverage=false` → **16 / 16 passed**, including "renders the unavailable block when the guest_pass_online hint is off or no club is present, without calling the BFF", "marks the flow unavailable when the BFF refuses the checkout (flag off / no flagged item → 404)" and "U23 (D61): a checkout with zero eligible offers renders the same unavailable block". The Sprint 0004 baseline failures (`__tests__/helpers/transformers.test.ts` date-dependent, `OfferDetails.test.tsx` intermittent) were not in scope of this single-suite run and did not appear.

## D7 — dev switch-over: PENDING by decision (BL-2)

Preconditions unmet, all four required: (1) the datatrak-service PR with `GET /external/club/guestPassItems.spr` and the two club fields merged and deployed to dev; (2) the DBA scripts (`SPL_EXTENSIONS.SPLEX_PROSPECT_LIABILITY`, `SALEITEMS.SAI_GUEST_PASS*`) run in dev; (3) LaunchDarkly `datatrak-service-DT-21555-guest-pass-fields` on for the chosen dev club (RQ-13 — which club is unanswered); (4) PLATFORM sets `STP_DATATRAK_SERVICE_URL` / `STP_DATATRAK_SERVICE_AUTH` as secrets for the BFF dev release. Until then `STP_CATALOG_SOURCE` stays `fixture` in dev. No helm PR opened; `repos/helm-configs` untouched; no remote host probed. When the four hold: helm `STP_CATALOG_SOURCE=datatrak` (signed commit), boot, capability report (`DT fields: present` expected for the flagged club), `POST /checkouts` via port-forward, scrubbed recording into the `*.flag-on.recorded.json` slot.

## PR and checks

PR **#112** https://github.com/abcfinancial/online-join-bff/pull/112 — non-draft, base `main`, title `feat: read the guest-pass fields from the DataTrak service layer (contract v4.1)`, no reviewers requested, not merged. Head at hand-off: **`b22febc`** (after the `1.3.0` bump `ca3bb38` and the Sonar fix).

Checks on `ca3bb38` (first run): CI / Build **pass** · CI / Scan with Endor Labs **pass** · Bump package version **pass** · Find LaunchDarkly feature flags in diff **pass** · Dependabot skipped · **SonarQube Code Analysis FAIL** (1 new issue, S3776 on the demo script — fixed in `b22febc`). Cursor Bugbot posted no check and no review comment on this PR within the window.

Checks on `b22febc` (re-run, final head — no second bump): CI / Build **pass** · CI / Scan with Endor Labs **pass** · Bump package version **pass** · Find LaunchDarkly feature flags in diff **pass** · **SonarQube Code Analysis pass** (gate green) · Dependabot skipped. Cursor Bugbot: no check run and no review on #112 (only the SonarQube bot commented). Local branch fast-forwarded to `b22febc`; working tree clean.

## Gate V5 — BFF matrix: verdict **PASS (mock-proven)** with evidence

| V5 requirement | Evidence |
|---|---|
| six cells pinned | `describe('matrix')`, 6 tests, table above |
| `timezone:invalid` and `unknown-type` fail closed | `timezoneId.test.ts` + the D3 adapter test (`Nonsense/Zone` → club undefined, offers `[]`, `missing: ['timezone:invalid']`); strict `itemType` test (6 unknown / missing spellings → `unknown-type`, never an offer) |
| `dtFields` observation wording | note contains `DT fields: present` / `DT fields: absent (off, old code or columns missing — unknown which)`; `DT_FIELDS_ABSENT_TEXT` exported and asserted |
| fixtures labelled | `_label` in every synthetic file; README three labels + `*.flag-on.recorded.json` slot |
| coverage floors kept (≥ 84 / 67 / 67 / 84) | 97.47 / 86.5 / 97.19 / 98.28; `jest.config.js` thresholds unchanged |
| Sonar green | first scan 1 issue (S3776, demo script) → fixed `b22febc` → re-scan **pass** |
| UI unavailable tests green | 16 / 16 (D6) |

## Contract deltas for E3 (the orchestrator owns `docs/contracts/short-term-pass-bff.md`)

1. **§8 ClubCatalogPort row** — replace "the single-item re-read adds `&saleItemId=`" with "`&saleItemId=` is available on the wire and unused: the BFF re-reads the list before side effects (`requireOffers`)". Add: "an unparsable `salePrice` falls back to `catalogPrice`; `catalogItemId` is carried from the wire (falls back to `saleItemId` when absent)". Add the timezone observation vocabulary `wire | missing | invalid` and that `BILLING` maps to `billing` and is skipped `not-a-product`.
2. **§8a(e) items table** — `itemType` row: "the BFF rejects anything else (`unknown-type`)" holds; add "a missing `itemType` is also `unknown-type` — the BFF never assumes product". `salePrice` row: add "unparsable → `catalogPrice`". `messages` row: add "the BFF reports the U6 envelope as `offers error (unavailable)` and `dtFields: absent`; a `success` envelope with an empty list is `0 eligible` and `dtFields: present`".
3. **§8a(e) club table** — `timezone` row: add the alias map summary (`US/*`, `Canada/*`, `EST`/`CST`/`MST`/`PST`/`HST`/`AST`, `GMT`/`UTC` → `UTC`) and the Node fact that `EST` would otherwise canonicalise to `America/Panama` (why the alias map precedes the `Intl` fallback). `prospectLiability` row: add "`""` → no override (template waiver), `consentTexts.waiver = template`".
4. **§10 registers** — DataTrak catalog live read: `blocked (CF-13 / CF-14)` → `pending (datatrak-service PR, scripts, flag `datatrak-service-DT-21555-guest-pass-fields`, secret `STP_DATATRAK_SERVICE_*`)`; CF-14 → `not required (closed by D2: club-scoped endpoint)`. New carried finding row: **HTML sanitiser for club-authored consent HTML** — SECURITY + UI (text in §D5). RQ-11 note: the BFF side is closed by the alias map + fail-closed; the open half is the distinct `TZL_ABC_CODE` values in dev / prod (Chancy / Terry).
5. **§7 / demo wording** — the demo's verdict 3 now reads "live DataTrak read pending (datatrak-service PR, scripts, flag, secret)"; the smoke doc should carry the same four preconditions.

## Decisions taken in the lane (recorded, not re-decided)

1. `unknown-type` is produced in the adapter (`mapGuestPassItem` returns a `skipped` entry), not by widening `CatalogOffer.type` to an invalid value; `partitionMappedItems` keeps catalog order across adapter-level and filter-level skips.
2. The U6 envelope and the CF-14 error envelope both map to reason `unavailable` (the upstream text goes to the warn log only).
3. `dtFields` becomes `present` on either read and never reverts within the report's life (it is an observation of bytes seen, not a state).
4. Timezone precedence: supported-id exact (case-insensitive) → alias map → `Intl.DateTimeFormat` canonicalisation checked against the supported set, refusing `UTC` from the fallback.
5. Demo recorded with `STP_EMAIL_TRANSPORT=mock` (local Mailpit not running); fixture-mode numbers are what the register reads.

## Known limitations

Live DataTrak read pending (four preconditions above). The synthetic "on" fixtures remain synthetic until the first scrubbed dev recording; the matrix is written so swapping them in changes no assertion as long as the recording covers the same skip reasons. The sanitiser finding is carried, not fixed. Husky v9 deprecation notices on commit (cosmetic).
