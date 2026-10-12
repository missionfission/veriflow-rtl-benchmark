# Findings: Codex (gpt-6.1-sol) using VeriFlow-CC's method — 2026-10-12

**Generator:** Codex CLI 0.162.1, model gpt-6.1-sol, medium reasoning. Not Claude Code and not VeriFlow-CC's own code.
**Method:** VeriFlow-CC's four stages, given as a prompt: (1) write a spec, (2) write Verilog, (3) write own testbench, simulate and fix (max 3 retries), (4) lint (`iverilog -Wall`) and synthesize (Yosys).
**Isolation:** each run happened in a fresh folder outside this repo, with only `requirement.md`. The generator never saw `bench/`, the reference models or `fixtures/`.
**Scoring:** this repo's independent checks (`python3 -m bench.runner`): cycle-by-cycle comparison with a Python reference model, lint, Yosys synthesis.

## Result
15 of 15 runs passed all three independent checks (5 designs x 3 runs). Every run passed its own tests on the first try (0 fix retries).
Tokens per run: 10k–30k. Wall time per run: 1.6–4.4 min (runs were done 5 at a time in parallel).

## Failures
None in this batch. Honest limits:
- These are small, fully specified blocks. They are easy compared with real chip work (AES, FFT, CNN, which VeriFlow-CC's examples cover).
- "Golden" means agreement over bounded random test vectors, not a formal proof.
- One model, one prompt, 3 runs per design. Not a statistically strong sample.
- No timing, area or power targets were checked.

Next: harder designs, and the same specs through Claude Code with real VeriFlow-CC for a direct comparison.
