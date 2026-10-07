# Sprint 0005 Draft Critique

This critique evaluates the two proposed drafts (Claude and Codex) for Sprint 0005 (G1) based on the Intent document and codebase reality.

## 1. Architectural Soundness

### Feature-Flag Design and "Byte-Identical" Safety
Both drafts correctly understand the "byte-identical when off" invariant and use LaunchDarkly context appropriately. 
- **Claude** excels by providing a concrete, file-by-file review map for the gating pass in `datatrak` (PR #6643). It also prescribes a strong verification method: capturing the executed SQL string via `ArgumentCaptor` and asserting it matches the `main` branch constants exactly, alongside shape goldens.
- **Codex** correctly emphasizes that evaluating a feature flag as `false` is not an instantaneous guarantee (due to LD caching or outages) and that operations must be drained before schema rollbacks.

### DTO Strategy for `ClubDefaultExternal` (JAXB Risk)
- **Claude** proposes a local subclass `GuestPassClubDefaultExternal extends ClubDefaultExternal`.
- **Codex** accurately identifies the risk here: because the shared jar relies on JAXB (`@XmlRootElement`, `@XmlElement`), a runtime subclass might serialize perfectly to JSON but fail to unmarshal via MICO's XML `RestTemplate` path (JAXB polymorphism). 
- **Verdict**: Codex's approach—mandating a half-day spike to prove the local subclass works across both converters, with a shared-interface jar bump as the explicit fallback—is the architecturally sounder path.

### Protecting MICO (Sale Items Query)
- **Claude** makes a crucial codebase discovery: `GET_ONLINE_SALE_ITEMS` hardcodes `cgi_service = '1'`, meaning the endpoint currently only returns services. Because guest passes are *products* (`0`), simply adding fields is insufficient. Claude proposes a new `guestPass=true` parameter to widen the query safely without injecting products into MICO's existing member shop.
- **Codex** also identifies the product exclusion but is slightly less concrete on the exact parameterization, though it correctly advocates for a bounded "memberless" branch.
- **Verdict**: Claude's `guestPass=true` parameter is the safest, most concrete way to satisfy G1 and protect MICO.

## 2. Completeness against Intent
Both drafts are highly complete against the G1 scope, touching G2, G8, G9, and G12 exactly where necessary.
- **G12 (Item Type)**: Addressed flawlessly by both, recognizing the `cgi_service` mapping.
- **G8 (Liability)**: Both handle the base64 UTF-8 encoding. Codex adds an excellent point about safely sanitizing the decoded HTML in the BFF before rendering it, which is essential for consent versioning.
- **G2 (Member ID)**: Both properly bound the memberless list requirement to the guest-pass path.

## 3. Phasing and Ordering
- **Claude** proposes a straightforward sequence: code with flags off -> scripts -> M&O flag -> service flag -> BFF switch. 
- **Codex** provides a superior, rigorous runbook (R0-R7). It correctly points out that Oracle DDL is not a reversible transaction. It explicitly dictates that DB scripts must be rolled back by dropping only *after* confirming flags are off everywhere and caches are drained. 
- **Verdict**: Codex wins on phasing and operational safety.

## 4. Risk Coverage
- **BFF Caching**: Codex notes a critical risk that Claude misses: the BFF must evaluate the flag *before* reading from its club/offers cache. A flag-off cache hit must not authorize the route.
- **UI/BFF Verification**: Codex enforces stricter mapping (rejecting unknown item types/timezones explicitly).
- **Delivery**: Claude's suggestion to open a PR directly *onto* Chancy's `feat/NOJIRA-guest-pass-email` branch, along with a review map, is an excellent mitigation for the "repos we don't own" constraint, preventing merge-base confusion.

## 5. Feasibility inside Two Weeks
- Claude estimates ~12 days; Codex estimates ~10 elapsed days. 
- Both recognize that working in foreign repos requires heavy coordination. 
- If the DTO spike fails, the shared-interface jar bump (Codex's fallback) will threaten the two-week timeline due to cross-repo release cycles. The team must spike this on Day 1.

## 6. Definition of Done
Both drafts correctly retain the four-verdict completion vocabulary from Sprint 0004. Both strictly separate "mock-proven" implementation from the "dev live read" verdict.

## Conclusion and Recommendations

The final plan should be a synthesis of the strongest elements from both:

1. **Keep from Claude**:
   - The `guestPass=true` request parameter on `saleItems.spr` to safely inject products without breaking MICO.
   - The concrete review map of sites to gate in `datatrak` PR #6643.
   - The SQL string `ArgumentCaptor` goldens for proving "byte-identical when off".
   - The PR strategy: target Chancy's branch directly for the gating pass.

2. **Keep from Codex**:
   - The DTO spike requirement: prove the local subclass works with JAXB/XML, or fall back to a jar bump.
   - The R0-R7 runbook, especially the acknowledgment that DDL is not transactional and rollback requires cache draining.
   - The BFF constraint: flag exposure must be evaluated before cache hits.
   - HTML sanitization in the BFF for the liability text.

3. **Weaknesses to discard**:
   - Discard Claude's assumption that the local DTO subclass is a guaranteed fix without a spike.
   - Discard Codex's slight vagueness on the exact POS query parameterization (use Claude's).
