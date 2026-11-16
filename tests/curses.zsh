# Exercise installed module selection without initializing a terminal.
() {
  local ZCODER_CURSES=auto ZCODER_CURSES_BACKEND=unloaded
  local ZCODER_CURSES_MODULE=zsh/curses ZCODER_CURSES_COMMAND=zcurses preloaded=''
  local -a loaded_modules=()
  local -i draw_result=0 stock_result=0
  zmodload() {
    if [[ $1 == -e ]]; then [[ $2 == "$preloaded" ]]; return $?; fi
    loaded_modules+=("$1")
    [[ $1 == zdraw ]] && return $draw_result
    return $stock_result
  }
  {
    zcoder_curses_load
    assert_eq installed:zdraw:zdraw "$ZCODER_CURSES_BACKEND:$ZCODER_CURSES_MODULE:$ZCODER_CURSES_COMMAND" 'auto loads installed zdraw'
    ZCODER_CURSES=stock ZCODER_CURSES_BACKEND=unloaded
    zcoder_curses_load
    assert_eq stock:zsh/curses:zcurses "$ZCODER_CURSES_BACKEND:$ZCODER_CURSES_MODULE:$ZCODER_CURSES_COMMAND" 'stock policy selects curses'
    ZCODER_CURSES=auto ZCODER_CURSES_BACKEND=unloaded draw_result=1
    zcoder_curses_load
    assert_eq stock "$ZCODER_CURSES_BACKEND" 'failed zdraw load falls back to stock'
    ZCODER_CURSES_BACKEND=unloaded stock_result=1
    zcoder_curses_load 2>/dev/null
    assert_failure 'failure of both modules propagates' $?
    preloaded=zdraw ZCODER_CURSES_BACKEND=unloaded
    zcoder_curses_load
    assert_eq preloaded:zdraw "$ZCODER_CURSES_BACKEND:$ZCODER_CURSES_COMMAND" 'preloaded zdraw is retained'
    ZCODER_CURSES=invalid
    zcoder_curses_load 2>/dev/null
    assert_failure 'invalid curses policy fails' $?
  } always { unfunction zmodload }
}
