# Sprint 0005 — PR description (BFF lane)

PR on `abcfinancial/online-join-bff`, branch `prospect-wallet/sprint-0005` → `main`. Title: `feat: read the guest-pass fields from the DataTrak service layer (contract v4.1)`. The body below is what was passed to `gh pr create --body-file`. Opened at `8f8e156`; the bump job pushed `ca3bb38` (1.3.0); the first Sonar scan failed on one S3776 finding in the demo script, fixed behaviour-unchanged in `b22febc`; all checks green at `b22febc` (CI / Build, Endor Labs, LD flag scan, SonarQube; Bugbot posted nothing).

---

## What changes

`DatatrakServiceCatalog` (`STP_CATALOG_SOURCE=datatrak`) now codes against the **contract v4.1 §8a(e) field table** — the two DataTrak service-layer responses the Guest Pass BFF reads once the Sprint 0005 datatrak-service PR, the DBA scripts and the DT service flag land. Nothing here changes what the browser sees.

- **New endpoint.** `getOffers` reads the club-scoped, member-less `GET {base}/club/guestPassItems.spr?clubNumber=` instead of the member-scoped POS `/pos/saleItems.spr` (CF-14 no longer applies). `&saleItemId=` exists on the wire for a single-item read but is unused: the orchestrator re-reads the list (`requireOffers`) before side effects, so one path and one cache suffice.
- **Confirmed names.** `club.prospectLiability` (base64 HTML, decoded like `prospectTerms`) → `waiverText`; `club.timezone`; items carry `saleItemId`, `catalogItemId`, `catalogItemName`, `catalogPrice`, `salePrice` (wins when present and parsable, else `catalogPrice`), `taxed`, `guestPassOnline`, `guestPassContractDays`, `guestPassVisits`, `itemType`. The never-existing `waiverText` wire field is gone; `DatatrakSaleItem*` types are replaced by `DatatrakGuestPassItem` / `DatatrakGuestPassItemsResponse`.
- **Strict timezone validation** (`adapters/platform/timezoneId.ts`): a club resolves only on a Node-supported id (`Intl.supportedValuesOf('timeZone')`), an explicit alias (`US/*`, `Canada/*`, `EST`/`CST`/`MST`/`PST`/`HST`/`AST`, `GMT`/`UTC`) or a spelling `Intl.DateTimeFormat` canonicalises to a supported id. Anything else fails closed with `missing: ['timezone:invalid']` — never GMT. Missing stays `missing: ['timezone']`.
- **Strict item type.** `PRODUCT` → `product`, `SERVICE` → `service`, `BILLING` → `billing` (the `CatalogOffer` union gains `'billing'`; the v1 filter already rejects non-products as `not-a-product`). Missing or unknown → skipped with the new reason **`unknown-type`**, listed in the capability report in catalog order like every other skip; never coerced to a product.
- **U6 envelope.** `messages.status === 'error'` or `saleItems === null` (flag off, unknown club, columns absent) → no offers with the report reason `unavailable` (gate 404), never a fixture.
- **`dtFields` observation.** `ClubReport.dtFields: 'present' | 'absent'` — `present` when the club body carried `timezone` or `prospectLiability` or the items read answered a success envelope; else the note prints `DT fields: absent (off, old code or columns missing — unknown which)`. An observation about the bytes seen, never a claim about the remote flag.
- **Fixtures labelled.** `getClubDefaultExternal.recorded.json` (2026-09-18) is the absent / off club; `getClubDefaultExternal.synthetic.json` carries the v4.1 on shape; `saleItems.synthetic.json` → `guestPassItems.synthetic.json` (v4.1 envelope); new `guestPassItems.unavailable.synthetic.json` (U6); `saleItems.*.recorded.json` kept as CF-14 history; the README documents the three labels and the reserved `*.flag-on.recorded.json` slot for the first scrubbed dev recording.
- Demo and mock catalog wording: the capability notes print a `DT fields` line; the live-read line says *pending* with its four preconditions; `MockClubCatalog.standsInFor` names `guestPassItems.spr`.

## The six-cell matrix (`__tests__/datatrakServiceCatalog.test.ts` → `describe('matrix')`)

| Cell | Fixture | Pinned outcome |
|---|---|---|
| absent / club | `getClubDefaultExternal.recorded.json` | club incomplete `missing: ['timezone']`, timezone `missing`, `dtFields: absent` |
| absent / items | `saleItems.noMember.recorded.json` (400), `saleItems.emptyMember.recorded.json` (error envelope) — CF-14 **history** | no offers; `http 400` without the CF-14 hint / `error (unavailable)`; the new path never sends a member id or calls `/pos/` |
| off / club | the same recorded file (one file, two labels) | adapter output identical under both labels; the file carries none of `prospectLiability` / `timezone` / `waiverText` |
| off / items | `guestPassItems.unavailable.synthetic.json` | no offers, reason `unavailable`, `dtFields: absent`, cached like a success |
| on / club | `getClubDefaultExternal.synthetic.json` | club resolves on `America/Chicago`, `waiverText` = decoded `prospectLiability`, consent texts `club`/`club`, `dtFields: present` |
| on / items | `guestPassItems.synthetic.json` | exactly the one eligible product (`core-flex-pass`, `$30.00` from `salePrice`, 7 days, 1 visit); skipped `core-3-visit-pass (multi-visit)`, `core-pt-session (not-a-product)`, `core-mystery-item (unknown-type)`, `core-towel-service (not-flagged)`; `dtFields: present` |

Plus: timezone unit tests (`timezoneId.test.ts` — `America/Chicago` accepted, `US/Central` → `America/Chicago`, `Nonsense/Zone` → invalid, blanks → missing), the strict `itemType` and `salePrice` fallback mapper tests, and the fail-closed transport tests (404 / 5xx / network / timeout / resolver failure).

## Proof (this branch, Node 26)

- `npx jest --coverage`: **69 / 69 suites, 706 passed (2 skipped)**; coverage **97.47 % statements / 86.5 % branches / 97.19 % functions / 98.28 % lines** (floors 84 / 67 / 67 / 84 unchanged).
- `npm run lint`: clean. `npx tsc --noEmit`: clean. `npm run build`: clean.
- `STP_EMAIL_TRANSPORT=mock npm run demo:short-term-pass`: **58 / 58** (fixture catalog; the `.env` SMTP sink was not running, which is why the mock transport was selected — unrelated to this change).
- UI proof (no UI change): `online-join-ui` `__tests__/routes/ShortTermPass/ShortTermPassPage.test.tsx` **16 / 16** on `main` `3967c43` — the unavailable block renders for flag-off and for zero eligible offers.

## Browser contract unchanged

`/api/short-term-pass/*` (§4–§6) is byte-for-byte what v4 serves: `offers[]`, `selectedOfferId`, the consent set and the purchase result are untouched. Only the adapter behind `ClubCatalogPort` and its capability report changed.

## Not in this PR / verdicts kept separate

- **Live read: pending.** The datatrak-service PR (new endpoint + the two club fields) is unmerged; the DBA scripts have not run; the LaunchDarkly key `datatrak-service-DT-21555-guest-pass-fields` is not on for any dev club; PLATFORM has not set `STP_DATATRAK_SERVICE_URL` / `STP_DATATRAK_SERVICE_AUTH`. Until all four hold, the dev adapter fails closed exactly as today (verdict 3 stays pending).
- **D7 dev switch-over: pending by decision** — no helm PR, no remote host probed, no secret touched. Precondition text in `SPRINT-0005-EXECUTION-SUMMARY-BFF.md`.
- **HTML sanitiser for club-authored consent HTML:** carried finding (owner SECURITY + UI). `prospectLiability` reaches the UI `DocumentDialog` (`html-react-parser`) and the BFF stand-in prospect mail through the same path `prospectTerms` already uses — no new sink, so no new dependency this sprint.
- Contract §8 / §8a(e) / §10 row deltas are listed for the orchestrator (E3) in the execution summary; this PR does not edit the contract.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
