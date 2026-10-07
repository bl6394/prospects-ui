# Sprint 0005 — DTS lane blockers (`datatrak-service`, PR #591)

Executor: Claude Fable 5.1 (DTS lane), 2026-10-07. Nothing merged; no script run; no flag flipped; no remote host probed; no credential printed.

| # | Blocked | Why | Tried | Effect |
|---|---|---|---|---|
| BL-1 (carried) | Gradle compile and test of the branch | `artifactory.abc30ops.com` unreachable (no VPN) | standalone `javac` + TestNG against cached jars for every self-contained class (50 / 50; proxy versions listed in the execution summary); hand review of the four tests that need app classes | DAO / service / controller tests and the app's real converters classpath are first observed in the PR's CI (§CI of the summary) |
| BL-4 (carried) | Off-path body goldens captured from `main` | no DB, no live service from this machine; the only `main` body is the 2026-09-18 scrubbed dev recording in the BFF fixtures (different inputs) | goldens written from the tests' fixed inputs through the app's converters (same classes, same settings) | the goldens prove "off = the jar types with no new element" and "on = off + two fields"; they do not prove equality with a live `main` body for the same club — a dev `curl` with the pinned build (E2) is the remaining step |
| BL-DTS-1 | `ResponseMessages` XML golden under the real jar | the cached `CommonWsObjects` is `1.0.2-SNAPSHOT` with **javax** JAXB annotations (the build uses 1.2.0); JAXB 4 ignored them and used public-field access | goldens generated with that proxy | **cleared by CI run 1:** `GuestPassItemSerializationTest` 9 / 9 under the real jar — the goldens stand |
| BL-DTS-2 | Jackson `MrBean` / `Joda` / `Guava` modules in the standalone run | not in the Gradle cache (never resolved) | `registerModules` stripped in the standalone copies only; repo files mirror `SpringConfiguration.objectMapper()` | none of the serialised types uses those modules; CI runs the real line |
| BL-DTS-3 | `gh pr create` without `--head` | refused ("you must first push the current branch…") although the push had succeeded and tracking was set | retried with `--head DT-21555-guest-pass-service-fields` | PR #591 opened; no effect on content |

| BL-DTS-4 (closed) | CI run 1 red | `ClubExternalControllerGuestPassItemsTest` 5 / 6 failed: stale mocks — `@InjectMocks` on a TestNG single instance with per-method `openMocks()` (the named sibling `ClubExternalControllerTest` has the same latent pattern and is not in the include list) | controller constructed per method in `setUp` (`b36f727`) | run 2 green; runs 3–4 cleared the Sonar gate (13 findings, behaviour unchanged, see the summary §CI); finding for the repo owners: the sibling test would fail the same way if it were ever added to the include list |

Nothing else was blocked. The push was accepted; the draft PR was accepted; reviewers were not requested (per the brief).
