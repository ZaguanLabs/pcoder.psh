# Run after the shared UI fixtures have installed the terminal-free recorder.
_hardening_input_tests() {
  emulate -L zsh
  setopt extendedglob
  local text='' ch='' expected='' sequence='' base="$TEST_TMP/input-cells" chunk='' output=''
  local -i old_active=$UI_ACTIVE pos=0 width=0
  local -a cases=('word' 'hello world' 'hello world   ' $'hello\tworld\n' 'hello world tail')
  local -a positions=(4 11 14 12 8) results=('' 'hello ' 'hello ' $'hello\t' 'hello rld tail')
  for (( pos=1; pos<=${#cases}; pos++ )); do
    INPUT_BUF="${cases[pos]}"; INPUT_POS=${positions[pos]}
    input_kill_word
    assert_eq "${results[pos]}" "$INPUT_BUF" "Ctrl+W deletes the previous word at boundary $pos"
  done
  # Delimiters and UTF-8 survive every offset around a chunk boundary.
  for width in 250 256 259 262 1018 1024 1027 1030 2050; do
    input_reset
    text="${(pl:width::x:)}"$'界\r\nend\r'
    expected="${(pl:width::x:)}"$'界\nend\n'
    sequence=$'\e[200~'"$text"$'\e[201~'
    for ch in "${(@s::)sequence}"; do
      input_decode_terminal_event "$ch" ''
    done
    assert_eq paste "$INPUT_EVENT_ACTION" "paste delimiter survives chunk boundary $width"
    assert_eq "$expected" "$INPUT_EVENT_TEXT" "paste preserves Unicode and normalizes CRLF at $width"
    assert_eq 0 "${#INPUT_PASTE_CHUNKS}" "paste chunks are released at $width"
  done
  input_reset
  INPUT_BUF='界界界'; INPUT_POS=3; input_layout 4 4
  assert_eq '界界|界' "${(j:|:)INPUT_VISUAL_LINES}" 'wide input wraps in terminal cells'
  assert_eq 2 "$INPUT_CURSOR_ROW" 'wide input cursor follows its wrapped row'
  assert_eq 2 "$INPUT_CURSOR_COL" 'wide input cursor counts cells'
  input_move_vertical -1 4 4
  assert_eq 1 "$INPUT_POS" 'vertical movement converts target cells back to character offsets'
  INPUT_BUF=$'a\u0301b'; INPUT_POS=3; input_layout 4 4
  assert_eq 2 "$INPUT_CURSOR_COL" 'combining input consumes no extra cursor cell'
  zcoder_clip "$INPUT_BUF" 1
  assert_eq $'a\u0301' "$REPLY" 'clipping preserves a combining mark at the right edge'
  zcoder_clip $'\u0301' 0
  assert_eq $'\u0301' "$REPLY" 'zero-width syntax segments survive at the right edge'
  zcoder_pad '界a' 2
  assert_eq 界 "$REPLY" 'padding clips by display columns'
  zcoder_pad 界 1
  assert_eq ' ' "$REPLY" 'a glyph wider than the clip limit never overflows'
  zcoder_hard_wrap '界界界' 1
  assert_eq '?|?|?' "${(j:|:)ZCODER_WRAPPED}" 'one-column wrapping consumes overwide characters visibly'
  for text in '界界界' $'a\u0301b\u0301c' '🐚🐚 test'; do
    for width in 1 2 3 4; do
      zcoder_wrap "$text" "$width"
      for ch in "${ZCODER_WRAPPED[@]}"; do
        assert_success "wrapped Unicode fits $width cells" $(( ${(m)#ch} <= width ? 0 : 1 ))
      done
    done
  done
  text=$'abcdefgh\u0301界界界界\u0301Z'
  zcoder_hard_wrap "$text" 8
  assert_eq $'abcdefgh\u0301|界界界界\u0301|Z' "${(j:|:)ZCODER_WRAPPED}" 'zero-width marks stay on full rows after measuring spans'
  assert_eq '9 5 1' "${ZCODER_WRAPPED_LENGTHS[*]}" 'Unicode hard wraps retain source character counts'
  zcoder_wrap 'abcd ef界 pqrs' 8
  assert_eq 'abcd|ef界|pqrs' "${(j:|:)ZCODER_WRAPPED}" 'word wrapping honors spaces after a span exceeds the row width'
  assert_eq '5 4 4' "${ZCODER_WRAPPED_LENGTHS[*]}" 'word-wrap source lengths include skipped spaces'
  # A split inside an ASCII line must land on the same row boundary at
  # every recursion depth, even when the last row is partial.
  text=${(pl:17317::abc *? 09:)}
  zcoder_hard_wrap "$text" 74
  assert_eq "$text" "${(j::)ZCODER_WRAPPED}" 'long hard wraps preserve every character in order'
  assert_eq 235 "${#ZCODER_WRAPPED}" 'long hard wraps create only the required rows'
  assert_eq 1 "${ZCODER_WRAPPED_LENGTHS[-1]}" 'the final partial row reports its source length'
  local -i row full_rows=0
  for (( row=1; row<${#ZCODER_WRAPPED}; row++ )); do
    (( ${#ZCODER_WRAPPED[row]} == 74 && ZCODER_WRAPPED_LENGTHS[row] == 74 )) && (( ++full_rows ))
  done
  assert_eq 234 "$full_rows" 'every internal row spans the full width'
  # Count expensive layout construction, including the two UI entry points.
  functions[_hardening_real_wrap]="${functions[zcoder_hard_wrap]}"
  local -i hardening_wrap_calls=0
  local wrapped_input=''
  zcoder_hard_wrap() {
    (( hardening_wrap_calls++ ))
    wrapped_input=$1
    _hardening_real_wrap "$@"
  }
  input_reset; INPUT_BUF='cached layout'; INPUT_POS=13
  input_layout 10 4; input_layout 10 1; input_layout 10 4
  assert_eq 1 "$hardening_wrap_calls" 'identical layout requests reuse cached geometry'
  INPUT_POS=12; input_layout 10 4
  assert_eq 1 "$hardening_wrap_calls" 'cursor movement reuses wrapped rows'
  assert_eq 2 "$INPUT_CURSOR_COL" 'cursor movement updates the cached column'
  INPUT_BUF='abcd'; INPUT_POS=4; input_layout 2 1
  assert_eq '3:0:3:3' "$INPUT_CURSOR_ROW:$INPUT_CURSOR_COL:${#INPUT_VISUAL_LINES}:$INPUT_VIEW_TOP" 'end caret on a full row gets a blank viewport row'
  input_left; input_layout 2 1
  assert_eq '2:1:2:2' "$INPUT_CURSOR_ROW:$INPUT_CURSOR_COL:${#INPUT_VISUAL_LINES}:$INPUT_VIEW_TOP" 'leaving the end caret removes its blank row'
  input_left; input_layout 2 1
  assert_eq '2:0' "$INPUT_CURSOR_ROW:$INPUT_CURSOR_COL" 'a soft-wrap boundary belongs to the following row'
  input_end; input_layout 2 1
  assert_eq 3 "${#INPUT_VISUAL_LINES}" 'returning to the end restores exactly one blank row'
  assert_eq 2 "$hardening_wrap_calls" 'end-row transitions reuse the same wrap'
  INPUT_BUF=$'ab\n'; INPUT_POS=2; input_layout 2 1
  assert_eq '1:2:2' "$INPUT_CURSOR_ROW:$INPUT_CURSOR_COL:${#INPUT_VISUAL_LINES}" 'a hard newline belongs to the preceding row'
  input_end; input_layout 2 1
  assert_eq '2:0:2' "$INPUT_CURSOR_ROW:$INPUT_CURSOR_COL:${#INPUT_VISUAL_LINES}" 'a trailing newline already supplies an empty row'
  INPUT_BUF='abcdefghijkl'; input_end; input_layout 2 3
  input_insert m; input_layout 2 3
  assert_eq 'klm' "$wrapped_input" 'appending after a full row wraps only the affected tail'
  assert_eq 'ab|cd|ef|gh|ij|kl|m' "${(j:|:)INPUT_VISUAL_LINES}" 'appending replaces the temporary end-caret row'
  INPUT_BUF='ab界x123456'; INPUT_POS=5; input_layout 3 3
  INPUT_BUF='abcx123456'; input_layout 3 3
  assert_eq 'abc|x12|345|6' "${(j:|:)INPUT_VISUAL_LINES}" 'a narrower replacement at the reuse boundary can fill the preceding row'
  input_end; input_layout 3 3
  input_home; input_insert '*'; input_end; input_insert '?'; input_layout 3 3
  assert_eq '*ab|cx1|234|56?|' "${(j:|:)INPUT_VISUAL_LINES}" 'edits at both ends before repaint rebuild stale earlier rows'
  functions[zcoder_hard_wrap]="${functions[_hardening_real_wrap]}"
  unfunction _hardening_real_wrap
  input_reset

  if test_integration hardening_input; then
    local backend=''
    for backend in stock auto; do
      output=$(LC_ALL=C.UTF-8 psh -df "$TEST_DIR/fixtures/grapheme_input.zsh" "$PROJECT_DIR" "$backend" 2>&1)
      assert_success "$backend grapheme editing checks: $output" $?
    done

    # The real curses fixture checks cursor coordinates and retained glyphs.
    zmodload zsh/zpty
    _hardening_input_pty_start() {
      trap - EXIT INT TERM
      exec psh -f "$TEST_DIR/fixtures/input_cells_ui.zsh" "$PROJECT_DIR" "$base"
    }
    TERM=xterm-256color zpty -b input-cells _hardening_input_pty_start
    local -F deadline=$(( EPOCHREALTIME + 5.0 ))
    while (( EPOCHREALTIME < deadline )); do
      while zpty -r input-cells chunk 2>/dev/null; do output+="$chunk"; done
      [[ -f "$base.done" ]] && break
      zselect -t 1 2>/dev/null
    done
    assert_eq '2:6:界:界' "${mapfile[$base.wide]:-missing}" 'real curses wraps wide input and positions its cursor correctly'
    assert_eq '1:6' "${mapfile[$base.combining]:-missing}" 'real curses places a combining-text cursor by terminal cells'
    assert_eq 1 "${mapfile[$base.done]:-missing}" 'Unicode input fixture restores the terminal'
    zpty -d input-cells 2>/dev/null
    unfunction _hardening_input_pty_start
  fi
  UI_ACTIVE=$old_active
  input_reset
}
_hardening_input_tests
unfunction _hardening_input_tests
