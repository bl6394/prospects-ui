# Sprint 0004 Drafts Critique

This document evaluates the two competing sprint plan drafts (Claude and Codex) for Sprint 0004 (Guest Pass v1) based on PRD v3.6 (Rounds 5–7), Change Requests v3, Design v6, and existing codebase realities.

## Summary Recommendation
**Claude's draft is vastly superior in its architectural reasoning, specifically regarding the DT read path.** By actually investigating how MICO accesses DataTrak (using `datatrak-service` rather than direct Oracle JDBC), Claude provides a realistic, sprint-sized path forward. Codex's proposal to connect the Node BFF directly to an Oracle database ignores the factual reality of MICO's architecture and introduces severe operational, security, and feasibility risks that would almost certainly block the sprint.

Both drafts correctly handle the reconciliation with Sprint 0003 and the repository/hosting strategy.

---

## Evaluation of Claude Draft

### 1. Open Questions
* **Q1 (Reconciliation):** Excellent. Correctly argues that PRD v3.6/CR v3 explicitly deprecate Sprint 0003 features (multi-day ranges, UI QR, etc.). Proposes deleting the code rather than hiding it behind feature flags, successfully avoiding technical debt and security risks of leaving dead public endpoints in the API.
* **Q2 (Home/Repo):** Excellent. Correctly determines that "fork off Myko" meant a standalone URL product-wise. Hosting the existing React/Koa application on a new `guestpass.abcfitness.com` domain is technically feasible within the sprint (via Helm/Ingress) and avoids the massive engineering cost (6-10 weeks) of rewriting the application inside the legacy MICO jQuery/Spring MVC stack. 
* **Q3 (DT Read Path):** Outstanding. Claude accurately analyzed the `mico` repository and discovered that MICO relies entirely on a Feign client (`orasvc-client`) to talk to `datatrak-service`, not direct JDBC. Claude proposes integrating the BFF with this exact same service layer, adhering perfectly to the "like Myko" directive without introducing direct Oracle DB dependency to a Node service.

### 2. Architectural Soundness & Reasoning against Code
Claude grounds its architecture in the existing BFF/UI capabilities and MICO's actual implementation. It handles the purchase order correctly (`create prospect` → `pay` → `deactivate on failure`) and provides a clear mechanism for compensating failed payments via a new `deactivate` flow. It also accurately notes that missing `DATATRAK_SERVICE` credentials or lack of DBA columns will not block localized development (using fixtures).

### 3. Completeness against PRD v3.6 / CR v3
Claude covers all requirements: catalog items (v1 singleton mask), prospect begin/expiration correctly tied to the purchase date, marketing opt-in legal text (in a `DocumentDialog`), removing the 18+ checkbox, and omitting the QR code from the success UI.

### 4. Phasing, Feasibility, Risks, DoD
* **Phasing:** A→B(BFF) / C(UI)→D(Hosting)→E(Proof) sequence makes sense.
* **Feasibility:** By avoiding a direct Oracle JDBC connection or MICO rewrite, this is feasible in the 1-2 week target.
* **Risks & DoD:** Pilot checks (scanner, webhooks, Cloudflare) are accurately captured in the Definition of Done.

### 5. Strongest Ideas & Weaknesses
* **Strongest Idea:** Reusing the `datatrak-service` HTTP endpoint discovered in MICO to implement the DT read path.
* **Weaknesses:** Claude relies heavily on HTTP intercept tests (using existing mocks/fixtures) which leaves live DT validation until the very end, but this is unavoidable without the DBA columns.

---

## Evaluation of Codex Draft

### 1. Open Questions
* **Q1 (Reconciliation):** Good. Similar to Claude, Codex correctly dictates that code for deprecated Sprint 0003 features should be removed rather than toggled via flags.
* **Q2 (Home/Repo):** Good. Aligns with Claude that a standalone UI/BFF deploy is the right solution over a monolithic MICO refactor.
* **Q3 (DT Read Path):** Flawed. Codex recommends an `oracledb` Node adapter to connect directly to the DataTrak Oracle Database. It completely missed that MICO doesn't have direct DB access for these reads either (as found by Claude). This introduces massive risks (VPD context management in Node connection pools, network plumbing, DBA grants).

### 2. Architectural Soundness & Reasoning against Code
Codex’s architecture is logical on paper but fails upon inspection of the underlying `mico` repo. While Codex appropriately scopes the BFF orchestration (validation → prospect → auth → save wallet → POS → receipt), its heavy reliance on an unproven Direct Oracle integration compromises the architecture.

### 3. Completeness against PRD v3.6 / CR v3
Codex checks all the product boxes: removing the date picker, extracting DT dates, modal marketing opt-ins, and returning customer flows. 

### 4. Phasing, Feasibility, Risks, DoD
* **Phasing:** Standard sequence (A-E), parallel UI/BFF.
* **Feasibility:** Because it relies on a direct Oracle connection, it is wildly optimistic to assume this could be completed (including all security, networking, and schema approvals) within 1-2 weeks.
* **Risks & DoD:** Acknowledges the DBA risk, but its primary recommendation is what causes the risk.

### 5. Strongest Ideas & Weaknesses
* **Strongest Idea:** The meticulous mapping of failure states in the "Prospect and payment orchestration" table (e.g., handling deactivate timeouts, wallet save failures).
* **Weaknesses:** Failing to inspect MICO's read path correctly led to a direct-DB architecture that violates the sprint's constraints.
