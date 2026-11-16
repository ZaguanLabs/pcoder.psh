# Development

zcoder targets psh 1.0.0-rc2 and newer. Keep application logic psh-first and preserve
the separation between Ollama, tool dispatch, persistence, remote transport,
and curses.

## Project checks

Run the complete required suite before handing off changes:

```sh
make test
```

`make test` first parses the entry points, libraries, tests, and fixtures with `psh -n`,
then runs the complete shell-level suite, including terminal and integration
fixtures. For a shorter development loop, use:

```sh
make test-fast
```

The fast target retains core behavior, command approvals, workspace confinement,
JSON/protocol validation, session fault injection, stale-writer checks, and UI
logic with a curses recorder. It omits slower integration groups, including
real PTYs, native setup, live remote session storage, and interactive
connection/timeout fixtures. Omitted groups are listed explicitly; they are not
counted as passing assertions. Some cheap child-process and socket checks remain
in the fast target. `make test` is still required before handoff.

To locate expensive groups, run either mode with timings:

```sh
psh -df tests/run.zsh --timings
psh -df tests/run.zsh --fast --timings
```

The final count is **assertions**, not independent scenarios or a coverage score.
Each run reports its mode, elapsed time, and number of omitted integration groups.
The [suite audit](test-suite-audit.md) explains the retained coverage and the
consolidation decisions. The complete suite covers:

- strict native JSON grammar, Unicode controls, and encoding
- both supported MCP protocol generations
- paginated MCP discovery and nested tool calls
- reasoning and tool history
- serialized per-call dispatch and transport recovery
- context accounting and compaction
- path and symlink confinement, including inherited ripgrep configuration
- file reads, writes, search, and patch fallback
- loop detection and completion recovery
- sessions, Skills, and project instructions
- interrupted session publication, immutable record reuse, reader leases, and generation collection
- stale session writers, unavailable-skill reloads, and session/turn-scoped remote cancellation
- Ollama, delegate, and remote cancellation
- command approval, denial, and safety guards
- authenticated remote events and approvals
- partial ACP/MCP frames, top-level response IDs, and request-bound ACP permissions
- same-host relay framing, discovery, delivery, and origin isolation
- input handling and curses rendering
- queued-input ordering, stable IDs, interrupted consumption recovery, and HTTP/ACP admission

Run syntax checks alone with:

```sh
make check
```

Run `make compile` after changes and after a Git push. It also runs the syntax
checks, then compiles application libraries with the installed psh. Rebuild
wordcode with the destination host's psh instead of assuming it is portable.

The TUI integration checks run real local and remote entrypoints in PTYs against
native TCP fixtures. They cover startup cancellation, draft recovery, streaming,
inspectors, terminal re-entry, persistence, and shutdown cleanup alongside the
individual process, MCP, discovery, and approval tests. A thousand-entry
transcript check counts layout and curses operations: idle refreshes and draft
editing must not re-render history, while stream updates lay out only the
changed entry. These are deterministic regression checks, not terminal-emulator
latency benchmarks or measurements of live Ollama inference.

The [overlapping-operation audit](test-gap-audit.md) records two reproduced
test gaps, the regression cases added for them, and remaining limitations.
The [TUI review](tui-review.md) assesses event-loop and overlay complexity and
records the stock-curses modal paste regression and its coverage.

`tests/context_accounting.zsh` checks retained reasoning and Skill content,
interrupted stream previews, missing usage reports, and attribution of runtime,
routing, and verifier guidance. The agent-loop tests also cover a tool response
with measured usage followed by a final response without a prompt count.

`tests/input_queue.zsh` exercises the real agent loop with controlled responses:
all tool results must precede steering, and follow-ups must wait for completion.
Its PTY fixture checks Enter, Ctrl+G, Unicode/multiline paste, draft preservation,
and cancellation using the actual editor and queue.

## Bundled components

psh supplies zjson, zdraw and zmdown. The application uses the installed psh
components directly; no submodules or private shell build are required.

## Performance measurements

Run the opt-in native microbenchmarks with:

```sh
make benchmark
```

The target runs syntax checks, then `tests/benchmark.zsh`. Each case uses three
warmups and five measured samples by default and reports elapsed milliseconds
as median/minimum/maximum, alongside Zsh, platform, and locale information.
To change the sample counts:

```sh
ZCODER_BENCHMARK_WARMUPS=3 ZCODER_BENCHMARK_SAMPLES=7 make benchmark
```

At least one warmup and three samples are required. Cases cover paste decoding,
Unicode JSON controls, fresh and cached input layout, cold and warm context
accounting, and cached transcript redraw. The redraw case mocks curses; the
benchmarks require no Ollama server or interactive terminal and measure neither
network latency nor actual terminal painting. Timing thresholds are deliberately
absent from `make test`.

Compare the same fixture, locale, Zsh version, and sample settings on a quiet
machine. The [v0.12.2 release notes](releases/v0.12.2.md) record targeted local
before/after measurements, including ranged file reads; those targeted fixtures
are separate from the reusable benchmark target. Functional assertions remain
the gate for correctness. Broaden performance checks when a change affects a
new path or a measurement exposes a regression.

Measure real TUI startup in a PTY with:

```sh
make benchmark-startup
```

This reports first-frame and first-input readiness for stock and automatic
curses selection, with one discarded warmup and seven samples per backend.
It uses an isolated workspace containing instructions, a skill and an MCP
configuration, starts the local relay, and disables model warm-up. No Ollama
or MCP server is contacted. The times begin inside the fixture shell; shell
process creation and private-runtime selection are excluded. `make test`
also checks that the screen precedes workspace/session preparation, input
typed during preparation survives, approvals still apply, and deferred dialog
helpers load exactly once. It has no elapsed-time threshold.

The October 2026 startup investigation found that ACP was already mode-gated
and MCP connections already happened after curses initialization. In a local
profile, eager MCP library loading cost about 0.1 ms, skill discovery/catalog
building about 16 ms, and synchronous relay startup about 23 ms. The relay's
20 ms readiness polling interval dominated its normal bind time. Starting the
listener alongside workspace preparation removes that wait when preparation
outlasts the bind; the bounded wait remains available on slower starts.

Across nine local PTY runs with compiled libraries, Zsh 5.9.2, 120×24 cells,
16 installed skills, relay enabled, explicit context size and no warm-up,
source-to-first-frame median improved from 59.9 ms to 12.3 ms. First-input
readiness improved from 60.3 ms to 40.2 ms. These are local measurements, not
latency guarantees; terminal links, filesystem caches, configuration size and
session-lock contention can change them. Remaining workspace preparation is
synchronous after the first frame so commands always see complete state.

Session persistence tests distinguish interruption before publication from a
committed save. They do not establish durability against power loss: generation
publication uses atomic rename and checked writes without an `fsync` guarantee.
See [session persistence](architecture.md#session-persistence) for reader and
writer coordination and [upgrade precautions](releases/v0.12.2.md#session-storage-and-upgrade-precautions)
before testing a downgrade against saved user sessions.

## Real-model evaluation

Real inference is opt-in and not part of `make test`. The evaluation target
creates isolated temporary workspaces, denies shell commands, and reports
tab-separated results for repeated reads, dependent search, edit-and-verify,
failure recovery, project-instruction compliance, implicit Skill routing,
Skill non-match precision, and conversational scenarios.

```sh
ZCODER_EVAL_MODELS='ornith-1.5:9b,laguna-xs-2.1' \
ZCODER_EVAL_REPEATS=3 \
make model-eval
```

Runs are grouped by model to amortize model-loading time. Use
`ZCODER_EVAL_SCENARIOS` for a comma-separated subset when doing a quick probe,
and `ZCODER_EVAL_OUTPUT_DIR` to retain the human transcript and JSONL model/tool
history for every run:

```sh
ZCODER_EVAL_MODELS='lfm2.5-8b-q6-128k' \
ZCODER_EVAL_SCENARIOS='conversational,independent_reads' \
ZCODER_EVAL_OUTPUT_DIR=/tmp/zcoder-eval \
ZCODER_EVAL_REPEATS=1 \
make model-eval
```

The TSV output includes elapsed time, transcript, and history paths. A model's
first scenario may include its Ollama load time; compare later scenarios for
warm performance.

Set `ZCODER_EVAL_BASELINE_PROMPT_FILE` to a complete earlier system prompt to
compare `current` and `baseline` variants. The `{{WORKSPACE}}` placeholder is
replaced with each temporary fixture path.

Model availability, quantization, sampling defaults, and Ollama configuration
remain the operator's responsibility.

## Implementation expectations

- Prefer native Zsh modules and parameter expansion for application logic.
- Use external tools when they are the capability: `rg`, `git apply`, `patch`, and approved commands.
- Keep model-exposed file operations inside `ZCODER_WORKSPACE`, including symlink resolution.
- Never bypass the `run_command` approval policy.
- Keep tool dispatch independently testable from curses and Ollama.
- Update the patch release before a Git push; change the minor release only when directed by a maintainer.

[Documentation index](README.md) · [Architecture](architecture.md) · [Project README](../README.md)
