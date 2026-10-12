# VeriFlow RTL Benchmark

An open test kit for checking whether AI-written chip code (Verilog RTL) actually works.

## What is VeriFlow-CC?

[VeriFlow-CC](https://github.com/bjwanneng/veriflow-cc) by **bjwanneng** is an open-source pipeline
that uses an AI coding agent to go from a written requirement to Verilog RTL, then runs simulation
(Icarus Verilog) and synthesis (Yosys). All credit for VeriFlow-CC goes to its authors.

This repo is **not** VeriFlow-CC and contains none of its code. It is an independent harness for
scoring the RTL that a pipeline like VeriFlow-CC produces. We inspected upstream revision
`77eca651d0e6ec93ed5309060980c54e76af7432` (see `docs/UPSTREAM.md`).

## What the harness checks

Five small designs, each with a frozen written spec in `specs/`:

| Design | What it is |
|---|---|
| `fifo` | 4-deep, 8-bit FIFO |
| `uart` | Simple UART transmit/receive |
| `axi_lite` | AXI-lite register block |
| `cordic` | CORDIC rotation unit |
| `cache` | Small cache controller |

For every generated design, and every run, it records:

1. **Golden-model equivalence** – a Python reference model (`bench/models.py`) is run cycle by cycle
   against the RTL in simulation. This is bounded checking over test vectors, not a formal proof.
2. **Lint** – the RTL must compile cleanly with Icarus Verilog.
3. **Synthesis** – the RTL must synthesise with Yosys.
4. **Retries, tokens and time** – taken from each run's `metadata.json` when the generator reports them
   (left as N/A otherwise), plus the time the checks took.

Each run's outputs are archived as a `.tar.gz` and summarised in `results.csv`, `results.json` and `REPORT.md`.

## Status

- **Harness only.** The checker, specs, reference models and hand-written reference fixtures are done,
  and the unit tests pass (including mutation tests that confirm broken designs are caught).
- **No AI generation results yet.** Live generation runs are coming next, using the Codex CLI as the
  generator. Results will be added here when they exist.

## How to run

Requirements: Python 3.10+, `iverilog` and `yosys` on your PATH (e.g. `sudo apt install iverilog yosys`).
No Python packages needed.

```bash
# 1. Unit tests
python3 -m unittest discover -s tests -v

# 2. Self-check the harness on the reference fixtures (not an AI score)
python3 -m bench.runner --fixtures --out results/fixture-check --runs 3

# 3. Create empty projects (one spec each) for a generator to fill in
python3 -m bench.prepare --out results/projects --runs 3
#    Put generated Verilog in results/projects/<design>/run-N/rtl/*.v
#    and optionally fill metadata.json (model, retries, tokens, generation_seconds).

# 4. Score the generated RTL
python3 -m bench.runner --candidates results/projects --out results/live-1 --runs 3
```

Output paths must be inside this repo, and an existing output folder is never overwritten.

## License

MIT for this harness, its specs and fixtures. VeriFlow-CC is a separate project; see its repository for its terms.
