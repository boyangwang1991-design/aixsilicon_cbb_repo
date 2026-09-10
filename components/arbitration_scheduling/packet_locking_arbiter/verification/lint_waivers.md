# Lint review

Run: 2026-09-10, SpyGlass X-2025.06 lint/lint_rtl, NUM_REQ=4, LOCK_MODE=0/1, LEN_W=8.
Both modes: 0 fatal, 0 error, 13 warning-class messages. Native summaries and hashes:
`reports/verification-lint.json`; raw reports under `build/eda/lint/`.

| Rule | Scope and disposition | Owner / expiry |
|---|---|---|
| SYNTH_5064 | Assertions in reused fixed_priority_arbiter are verification-only and ignored by synthesis. Child RTL unchanged. | RTL owner; re-review if child assertions or synthesis handling changes. |
| W240 | clk/rst_n/grant_ack_i unused in the combinational child configuration; parameters deliberately disable state. Parent clock/reset remain used. | RTL owner; expires on child parameter/interface change. |
| W415a | selected/selected_length use initialized OR accumulations in a combinational loop. Repeated assignments are intentional; full assignment prevents latch. | RTL owner; expires on selection logic rewrite. |
| W528 | EOP-mode length cone or length-mode selected_eop is statically unused; synthesis removes it. | RTL owner; expires on mode/metadata changes. |
| STARC05-1.3.1.3 | rst_n masks externally visible grant and consequently transfer enable, in addition to asynchronous reset pins. Intentional reset contract; deassertion must be synchronized by integrator. | RTL/integration owner; expires if reset release contract changes or asynchronous cross-domain use is proposed. |

These are scoped source reviews for this implementation, not blanket tool rule suppression.
No waiver covers a compile error, width truncation, latch, incorrect functional result, or parameter violation.
