# Sprint 0001 Critique: Claude vs Codex Drafts

## Claude Draft Evaluation

**Architectural Soundness:**  
Claude proposes a stateless, JWT-backed session (`STP-SESSION`) and identify token. It tightly structures a port-and-adapter pattern for upstream services and proposes reusing the existing Pay Page routes. This is structurally straightforward but reuse of the existing Pay Page session routes introduces a potential security bypass for generic token collection.

**Completeness:**  
Extremely thorough on the exact implementation details. Claude identifies the UI/BFF boundaries perfectly, outlines the precise Redux state branches, SCSS token abstractions, and provides an exact file-by-file plan. It correctly catches a flaw in the original Intent regarding the Pay Page SDK callback not containing a raw token.

**Phasing/Ordering:**  
Sensible sequencing, proposing shared foundations first (A), then parallelizing UI (D) with BFF routes (B/C). 

**Risk Coverage:**  
Excellent operational risk mitigation. Proposes a recursive payload scan test to strictly enforce that `PROSP` and agreement metadata do not leak into identity calls. It addresses PII logging risks nicely. However, its stateless JWT approach risks replay or revocation failures (e.g., if a user abandons a locked session, the server has no state to permanently lock the JWT).

**Feasibility:**  
Highly feasible. Its precise knowledge of the codebase makes the execution steps actionable and ready to code. 

**Definition of Done:**  
Well-defined, separating immediate mock deliverables (live gates E0-E10) from deferred backend integration gates (F1-F6). 

**Strongest Ideas / Weaknesses:**  
*Strengths:* The recursive payload test to prevent PROSP identity leaks; catching the Pay Page SDK token limitation; highly accurate file-level plan.  
*Weaknesses:* Stateless JWTs for short-term highly-sensitive sessions are suboptimal; reusing the existing Pay Page route without checkout-binding allows bypassing the pass-specific authorization.

---

## Codex Draft Evaluation

**Architectural Soundness:**  
Codex designs a highly robust, stateful architecture featuring opaque server-side checkouts and purchase locking. It specifically catches the flaw in reusing the generic Pay Page session routes, advocating for a strictly scoped pass-payment endpoint to prevent attackers from using the generic route to bypass authorization.

**Completeness:**  
Very strong on backend state machines and business logic boundaries. It extensively covers failure recovery, checkout idempotency, and the semantic difference between "no match" and "ambiguous". It spends less detail explicitly naming frontend files and Redux slices compared to Claude.

**Phasing/Ordering:**  
Logical and defensive. Starts with freezing contracts (A), locking down the BFF trust boundaries (B), orchestrating purchase logic (C), and finally UI (D). This enforces backend security before frontend consumption.

**Risk Coverage:**  
Outstanding. Codex properly identifies the threat of generic Pay Page reuse and mandates binding payment sessions to the checkout owner. It also accurately scopes the reality of the missing legacy system integrations, emphasizing that the sprint will only reach a "mock complete" status.

**Feasibility:**  
Feasible, though potentially over-engineered in some areas (e.g., strictly versioned server-owned quotes for a $25 static pass). The stateful tracking approach is safer and more realistic for real payment orchestration.

**Definition of Done:**  
Excellent separation. Differentiates Sprint Delivery Gates (G0-G8) from Real-Service Enablement Gates (L1-L5), which keeps the team accountable to deliverables without blocking on backend teams.

**Strongest Ideas / Weaknesses:**  
*Strengths:* Server-owned opaque sessions; checkout-bound payment sessions to avoid bypasses; explicit stateful idempotency tracking.  
*Weaknesses:* Overly abstract in its UI recommendations compared to Claude; could lead to over-engineering the quote versioning.

---

## Synthesis Recommendations

To achieve the best outcome, the final plan should synthesize the strengths of both drafts:

1. **Session & Security (Take Codex):** Use Codex’s opaque, server-side `CheckoutStore` instead of Claude’s JWTs. Implement Codex’s dedicated, checkout-bound Pay Page session endpoint to prevent authorization bypass.
2. **Architecture & Implementation Plan (Take Claude):** Use Claude’s precise UI component structure, `dt-*` SCSS isolation, and Redux slice design.
3. **Safety Checks (Take Claude):** Implement Claude's recursive payload scan to strictly guarantee that agreement numbers and `PROSP` markers never leak to the wallet layer.
4. **Honest Readiness (Take Codex):** Adopt Codex’s phrasing around "mock-complete" to explicitly acknowledge that the UI/BFF will be delivered but blocked from live production by missing upstream DataTrak and MICO services.
