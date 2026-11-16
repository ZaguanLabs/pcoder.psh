#!/usr/bin/env psh
# Keep exit-status recording outside the test runner's inherited trap scope.
emulate -R zsh
zmodload zsh/mapfile
typeset -g fixture_root="$1" fixture_base="$2"
ZCODER_HOME="$fixture_base.home" ZCODER_DEBUG_LOG='' command psh -f "$fixture_root/pcoder.psh" --connect "${mapfile[$fixture_base.endpoint]}" --token-file "$fixture_base.token" --no-warmup
mapfile[$fixture_base.application_exit]="$?"
