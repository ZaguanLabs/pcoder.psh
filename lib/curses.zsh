# Select zdraw or stock curses before starting a terminal session.
# Never replace an already loaded module or modify the system installation.
typeset -g ZCODER_CURSES_BACKEND=unloaded
typeset -g ZCODER_CURSES_MODULE=zsh/curses ZCODER_CURSES_COMMAND=zcurses

# No locals: module output parameters must reach the caller's dynamic scope.
zcoder_curses() { builtin "$ZCODER_CURSES_COMMAND" "$@"; }

# Return the selected module's optional features in the caller-owned reply array.
zcoder_curses_features() {
  emulate -L zsh
  local feature_parameter=${ZCODER_CURSES_COMMAND}_features
  reply=()
  zmodload -F -e "$ZCODER_CURSES_MODULE" "+p:$feature_parameter" || return 1
  reply=("${(@P)feature_parameter}")
}

zcoder_curses_load() {
  emulate -L zsh
  local policy=${ZCODER_CURSES:-auto}
  case "$policy" in
    auto|stock) ;;
    *) print -u2 -r -- 'Error: ZCODER_CURSES expects auto or stock'; return 1 ;;
  esac
  if [[ $ZCODER_CURSES_BACKEND != unloaded ]] && zmodload -e "$ZCODER_CURSES_MODULE"; then
    return 0
  fi
  if zmodload -e zsh/curses; then
    ZCODER_CURSES_MODULE=zsh/curses ZCODER_CURSES_COMMAND=zcurses
    ZCODER_CURSES_BACKEND=preloaded
    return 0
  fi
  if zmodload -e zdraw; then
    ZCODER_CURSES_MODULE=zdraw ZCODER_CURSES_COMMAND=zdraw
    ZCODER_CURSES_BACKEND=preloaded
    return 0
  fi
  if [[ $policy == auto ]] && zmodload zdraw 2>/dev/null; then
    ZCODER_CURSES_BACKEND=installed
    ZCODER_CURSES_MODULE=zdraw ZCODER_CURSES_COMMAND=zdraw
    return 0
  fi
  zmodload zsh/curses || return 1
  ZCODER_CURSES_BACKEND=stock
  ZCODER_CURSES_MODULE=zsh/curses ZCODER_CURSES_COMMAND=zcurses
}
