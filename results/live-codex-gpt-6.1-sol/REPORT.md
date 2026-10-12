# Live results: Codex CLI (gpt-6.1-sol, medium reasoning) using the VeriFlow-CC four-stage method

Equivalence here means bounded cycle agreement, not a formal proof. Unknown costs remain N/A.

| Design | Checks | Golden | Lint clean | Synth | Overall |
|---|---:|---:|---:|---:|---:|
| fifo | 3 | 3/3 | 3/3 | 3/3 | 3/3 |
| uart | 3 | 3/3 | 3/3 | 3/3 | 3/3 |
| axi_lite | 3 | 3/3 | 3/3 | 3/3 | 3/3 |
| cordic | 3 | 3/3 | 3/3 | 3/3 | 3/3 |
| cache | 3 | 3/3 | 3/3 | 3/3 | 3/3 |

| Design | Seed | Golden | Lint | Synth | Retries | Tokens | Generation s | Check s | Archive |
|---|---:|---|---|---|---:|---:|---:|---:|---|
| fifo | 0 | pass | pass | pass | 0 | 10481 | 151 | 0.1306 | [fifo-run-1](fifo-run-1/rtl) |
| fifo | 1 | pass | pass | pass | 0 | 15005 | 97 | 0.132 | [fifo-run-2](fifo-run-2/rtl) |
| fifo | 2 | pass | pass | pass | 0 | 25450 | 103 | 0.1922 | [fifo-run-3](fifo-run-3/rtl) |
| uart | 0 | pass | pass | pass | 0 | 17240 | 105 | 0.124 | [uart-run-1](uart-run-1/rtl) |
| uart | 1 | pass | pass | pass | 0 | 14481 | 145 | 0.1071 | [uart-run-2](uart-run-2/rtl) |
| uart | 2 | pass | pass | pass | 0 | 12179 | 164 | 0.1298 | [uart-run-3](uart-run-3/rtl) |
| axi_lite | 0 | pass | pass | pass | 0 | 25032 | 261 | 0.2499 | [axi_lite-run-1](axi_lite-run-1/rtl) |
| axi_lite | 1 | pass | pass | pass | 0 | 28063 | 152 | 0.2414 | [axi_lite-run-2](axi_lite-run-2/rtl) |
| axi_lite | 2 | pass | pass | pass | 0 | 24561 | 251 | 0.2395 | [axi_lite-run-3](axi_lite-run-3/rtl) |
| cordic | 0 | pass | pass | pass | 0 | 22477 | 222 | 0.3415 | [cordic-run-1](cordic-run-1/rtl) |
| cordic | 1 | pass | pass | pass | 0 | 20274 | 121 | 0.4283 | [cordic-run-2](cordic-run-2/rtl) |
| cordic | 2 | pass | pass | pass | 0 | 17082 | 114 | 0.3432 | [cordic-run-3](cordic-run-3/rtl) |
| cache | 0 | pass | pass | pass | 0 | 22736 | 176 | 1.4843 | [cache-run-1](cache-run-1/rtl) |
| cache | 1 | pass | pass | pass | 0 | 30082 | 104 | 1.5183 | [cache-run-2](cache-run-2/rtl) |
| cache | 2 | pass | pass | pass | 0 | 18798 | 126 | 1.5259 | [cache-run-3](cache-run-3/rtl) |
