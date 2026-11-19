# pcoder.psh performance on psh 1.0.0-rc3

On a Ryzen 9 5950X workstation, three application changes reduced the median time to normalize a multiline code paste by 94%, update a streamed transcript by 40%, and frame a 16 MiB HTTP response by 21%. Each uses native shell operations available on rc2.

## Measurements

Times are median milliseconds. The first two columns isolate the application changes on rc3. The last column runs the edited application on the previous installed shell build.

| Workload | Original on rc3 | Edited on rc3 | Edited on rc2 |
| --- | ---: | ---: | ---: |
| Native paste, 2,048 tab-indented CRLF code lines | 79.81 | 4.56 | 5.53 |
| Stream preview update after 1,000 messages, native Markdown | 3.43 | 2.05 | 2.82 |
| Content-Length feed, 1 MiB in 32 KiB reads | 5.05 | 4.12 | 7.52 |
| Content-Length feed, 4 MiB in 32 KiB reads | 20.28 | 16.39 | 29.55 |
| Content-Length feed, 16 MiB in 32 KiB reads | 85.44 | 67.54 | 121.56 |

**Paste.** The terminal supplies a completed native paste as one string. Replacing each CRLF and tab individually was costly on code with many short lines. The editor now uses quoted split/join passes only when a separator is present. This preserves consecutive delimiters, leading indentation and trailing blank lines. UTF-8 repair and terminal-control filtering still run. On separate 57,000-character fixtures, plain ASCII took about 3.4 ms and repeated é took about 11.7 ms, down from 4.1 and 14.3 ms.

**Transcript.** With 1,000 preceding messages, native Markdown and mocked terminal I/O, `zsh/zprof` attributed 59% of the preview workload to time inside `_ui_paint_chat` exclusive of callees. Updating the last event expanded the retained prefix of ten layout arrays. Range deletion lets psh discard stale rows and spans directly. In a separate fresh-process run with 5,000 preceding events and 150 successive text updates, peak RSS fell from 19,524 to 14,148 KiB. A comparison of twelve layout arrays across eighteen first, middle and last event edits produced byte-identical output, including empty replacements, styled text and Unicode.

**HTTP.** Most socket reads within a response body are consumed whole. The parser now appends that buffer directly and slices only when a framing boundary falls inside the read. The benchmark includes parser calls and byte counting. Socket I/O, model generation and disk spooling are outside the timing.

## Other costs measured in the first pass

| Edited rc3 workload | Median ms |
| --- | ---: |
| First frame / first input readiness, automatic terminal backend | 12.69 / 22.73 |
| First frame / first input readiness, stock terminal backend | 12.54 / 26.51 |
| Parse one short Ollama stream record / one tool response | 0.28 / 0.86 |
| Lay out a 100,000-character draft, fresh / cached | 22.67 / 0.10 |
| Context accounting, 1,000 × 1 KiB messages, cold / warm | 35.62 / 13.28 |
| Serialize a chat request for the same history | 14.60 |
| Transcript with 1,000 events, complete fallback layout / cached repaint | 165.51 / 1.48 |

The legacy paste decoder took 642 ms for 100,000 individually delivered characters. That fixture exercises a different input path from a completed native paste. Whole-benchmark peak RSS was about 103 MiB on both application revisions, including the synthetic multi-megabyte buffer comparisons.

## Long-draft cursor movement

With a 100,000-character ASCII draft, the first implementation wrapped the entire draft on every cursor move. The editor now reuses its visual rows while text and width match. It finds the cursor row by binary search over the cached character offsets, then measures the display width of the prefix on that row.

| rc3 workload, milliseconds per keypress | Before cursor change | After cursor change |
| --- | ---: | ---: |
| Left arrow and layout | 23.160 | 0.115 |
| Alternating Home and End, including layout | 23.174 | 0.145 |
| Left arrow through the editor handler and repaint | 25.758 | 2.761 |

These runs used compiled code on CPU 5, a width of 74 cells and a four-row viewport. Each figure is the median of seven 20-key batches after one warmup batch. The handler fixture enabled native grapheme navigation and mocked terminal writes and refresh. The regular `make benchmark` also times a single left arrow and checks its resulting coordinates.

On both rc2 and rc3, 2,400 before-and-after layout snapshots matched across widths, viewport heights and cursor positions. The comparison included empty lines, wide characters, combining marks, joined emoji and a caret at the exact end of a full row.

## Repainting the prompt

After the cursor change, `zsh/zprof` attributed 62% of a long-draft Left-arrow handler to constructing the input window key. Both key constructions shell-quoted the entire draft. The window now compares the text directly, and slash completion retains a copy only for a command candidate. The updated key construction accounted for 2% of handler time in the same profile.

| rc3 workload, milliseconds per operation | Before repaint change | After repaint change |
| --- | ---: | ---: |
| Left/Right, 100,000 ASCII characters, native zdraw in an 80×24 PTY | 2.834 | 0.947 |
| Left/Right, 100,000 characters of multiline shell text, mocked terminal writes | 2.998 | 0.780 |
| Check an unchanged 100,000-character ASCII prompt, mocked terminal writes | 0.974 | 0.115 |
| Left/Right, 64 ASCII characters, mocked terminal writes | 0.230 | 0.236 |

The PTY measurement includes window painting and refresh. It calls the key handler directly and verifies the retained cursor coordinates after each batch. All four comparisons used CPU 5 and the median of seven 20-operation batches after a warmup. The regular benchmark now exercises the editor handler as well as layout in isolation.

## Typing into a wrapped draft

Appending to a 100,000-character ASCII line took **1.42 ms per keypress** through the editor and native zdraw refresh, down from **19.51 ms**. The editor restarts wrapping one visual row before the previous caret. It compares the old and new text through the first character of that row, since a narrower replacement could fit on the preceding row. A failed comparison or a width change triggers a full wrap. The editor uses the existing layout arrays for this check.

| rc3 location of first insertion | Before, ms | After, ms |
| --- | ---: | ---: |
| End, native zdraw in an 80×24 PTY | 19.51 | 1.42 |
| End, mocked terminal writes | 18.84 | 1.36 |
| Middle, mocked terminal writes | 19.89 | 10.90 |
| Beginning, mocked terminal writes | 20.09 | 19.67 |

Each run started with one 100,000-character line at a width of 74 cells and inserted 160 characters at the advancing caret. The table reports medians of seven 20-key batches after one warmup batch on CPU 5. The PTY fixture checked the retained cursor coordinates after each batch. The amount of text after the edit still determines how much needs wrapping, and comparing the retained prefix also has a cost.

On rc2 and rc3, 9,744 layout snapshots per run matched the original implementation with native grapheme navigation enabled and again with it disabled. The fixtures covered insertion, backward and forward deletion, batched edits, direct draft replacement, hard and soft breaks, combining marks, joined emoji, and control characters. The regular benchmark now includes an end-of-draft insertion through the editor handler.

## Edits near the start of a draft

On rc3, `zsh/zprof` attributed 79% of the single-line handler time and 69% of the multiline handler time to the cell wrapper itself. A long printable ASCII line produced an array entry for each character. The multiline fixture also invoked the wrapper 69,040 times across 40 keypresses because each edit reflowed the following lines.

The editor now records a logical line directly when its display width fits. For longer printable ASCII lines, the hard wrapper splits the scalar at whole-row boundaries and slices those smaller blocks into rows. This bounds the distance each row subscript has to scan and avoids the per-character array.

| 100,000-character draft, ms per inserted character | Before | After |
| --- | ---: | ---: |
| Single line of printable ASCII with varied characters | 19.66 | 11.47 |
| Multiline shell text | 44.24 | 8.66 |

Both runs started at the beginning of the draft in an 80×24 PTY with native zdraw painting and refresh. Each figure is the median of seven five-key batches after one warmup batch, pinned to CPU 5. For the separate memory check, three fresh psh processes each hard-wrapped one printable ASCII line at 74 columns. Median peak RSS for 100,000 characters fell from 13.0 to 5.5 MiB. For 1 MiB of input it fell from 105.5 to 25.0 MiB.

On both rc2 and rc3, the original and edited implementations produced identical row text, offsets, lengths, viewport and cursor state across 9,744 UTF-8 snapshots per navigation mode and 12,936 snapshots in the C locale. The benchmark target includes both early-edit fixtures.

## Unicode row wrapping

On a mixed Unicode line, `zprof` attributed about 95% of the editor handler time to the wrapper. The wrapper now uses the previous row's character count to estimate how much of the next row will fit. It measures that span with psh's native display-width expansion, tries a shorter span once if needed, and finishes the boundary character by character. That last step accounts for combining marks even when the row already fills the available cells.

| 25,000-character line | Before, ms per keypress | After, ms per keypress |
| --- | ---: | ---: |
| Source code with Latin text, CJK and symbols | 62.26 | 11.82 |
| CJK ideographs | 84.37 | 32.86 |
| Combining marks and joined emoji | 75.02 | 22.45 |

Each run inserted characters near the beginning of one line in an 80×24 PTY at a wrap width of 74 cells. The medians cover seven three-key batches after one warmup batch on CPU 5, including native zdraw painting and refresh. Each pair produced byte-identical terminal output and the expected caret coordinates. In three separate processes wrapping a 100,000-character mixed line, median peak RSS was 16.4 MiB on both versions.

The previous and updated wrappers produced identical row text and source lengths in 2,112 cases per build and locale. The comparisons covered rc2 and rc3 under both `C` and `C.UTF-8`, including hard wrapping, word wrapping, control characters, malformed bytes and both multibyte option settings. The regular benchmark includes the mixed-source insertion workload.

## Inserting and deleting inside Unicode drafts

After the wrapping change, `zprof` put 47% of the CJK editor time in the wrapper itself and another 35% in insertion and grapheme lookup, including the native lookup. Assigning to a character range lets psh insert or delete text without extracting and joining both sides of the caret. When the entire draft is one logical line, the grapheme lookup can also pass that line directly to the existing boundary logic.

| 25,000-character draft | Before, ms per keypress | After, ms per keypress |
| --- | ---: | ---: |
| Single line of CJK ideographs | 31.92 | 26.44 |
| Single line with combining marks and joined emoji | 22.54 | 18.59 |
| Single line of mixed source code | 11.91 | 11.71 |
| Multiple short lines of mixed Unicode text | 9.58 | 9.14 |

Each workload ran twice per version, reversing the order on the second run. The table gives the median over 14 three-key batches after discarding one warmup batch per run. Each run typed from the start of the draft and included zdraw refresh in an 80×24 PTY on CPU 5. Before and after produced identical terminal bytes for all four workloads. The regular benchmark includes the advancing-caret CJK insertion case.

In a separate memory check, five fresh rc3 processes per version inserted one character and deleted its neighbor near the beginning of a 250,000-character CJK buffer. With rendering and grapheme lookup disabled to isolate the edit, median peak RSS fell from 7.91 to 6.19 MiB.

On each of rc2 and rc3, 9,744 UTF-8 layout snapshots, 12,936 C-locale layout snapshots, and 4,680 buffer and caret snapshots matched the preceding implementation. The buffer checks included literal NULs, malformed UTF-8, combining marks, and joined emoji under both multibyte settings. The full rc3 suite passed all 3,928 assertions after this change.

## Preparing an Ollama request

On rc3, joining 1,000 ordinary messages took 11.99 ms of a 15.94 ms request build. The serializer now searches the requested slice of the history array with a native psh pattern. If every record is ready to send, it joins the slice directly. The request builder also inserts that history into the final JSON once. History entries requiring normalization still go through the per-message loop.

| History with 1,000 messages of 1 KiB each | Before, ms per request | After, ms per request |
| --- | ---: | ---: |
| Ordinary assistant messages | 15.94 | 8.29 |
| Every tenth message has a queue receipt | 17.25 | 16.37 |
| Every tenth message has a legacy system role | 16.00 | 14.85 |
| Every message has both a legacy role and a receipt | 32.73 | 32.55 |

These measurements call `agent_build_payload` with an empty tool catalog and exclude network and model time. Each version ran twice on CPU 5 in opposite order, with three warmups and eight timed calls per run. Ordinary history serialization alone fell to 4.82 ms. In a separate run with 4,096 ordinary messages, median peak RSS for building one request fell from 54.4 to 50.3 MiB across five fresh processes per version.

The receipt matcher requires the string field to end the record. A nested tool argument named `input_id` now survives even when a content field follows it. The regression test also covers a nested argument and a real queue receipt on the same message. An additional 720 history and payload comparisons matched across rc2 and rc3 in `C` and `C.UTF-8`, covering range selection, escaped receipt strings, stream and thinking settings, and routing requests. On all four build and locale combinations, the serializer also matched independently generated expected JSON for 2,048 records with nested arguments, escaped characters, and Unicode.

## Reproduction and checks

The baseline was revision `b490547`. The runs used compiled libraries, Linux x86-64, `C.UTF-8`, rc3 build `9cb81e1e9294` and rc2 build `8f0d81052393`. For the comparison table, both revisions used the updated benchmark driver, CPU 5, three warmups and five timed samples per case. The stream case used real zmdown layout and zdraw text measurement with screen writes mocked. Startup used a real PTY, a separate workspace, one warmup and seven samples. The JSON fixture used seven samples. All timings are workstation measurements.

```sh
LC_ALL=C.UTF-8 make compile
LC_ALL=C.UTF-8 taskset -c 5 psh -df tests/benchmark.zsh
LC_ALL=C.UTF-8 psh -df tests/benchmark_json.zsh
LC_ALL=C.UTF-8 make benchmark-startup
LC_ALL=C.UTF-8 make test
```

The first rc3 pass completed 3,904 assertions. The full suite passed 3,912 assertions after the cursor change, 3,916 after the repaint change, 3,920 after incremental wrapping, 3,924 after the early-edit changes, and 3,928 after the Unicode wrapping change. Every run included all integration groups. Compilation and the benchmark completed on the tested rc2 build. Its fast suite had the same 23 UTF-8 failures on both revisions. In an isolated check loading only its bundled zjson, rc2 produced the expected replacement characters for malformed bytes and then returned `invalid_utf8` when parsing the resulting JSON. The rc3 build passed that round trip.
