#!/usr/bin/env psh
# Trusted argv only: this worker never evaluates model-provided shell source.
emulate -R zsh
source "${0:A:h:h}/lib/psh.zsh" || exit 1
source "${0:A:h:h}/lib/search.zsh" || exit 1
search_worker "$@"
