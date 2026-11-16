# Locate the scripts shipped alongside psh's autoload functions.
zcoder_psh_script() {
  local directory
  for directory in "${fpath[@]}"; do
    if [[ -r "$directory/zjson" && -r "$directory:h/scripts/$1" ]]; then
      REPLY="$directory:h/scripts/$1"
      return 0
    fi
  done
  print -ru2 -- "Error: psh bundled script unavailable: $1"
  return 1
}
