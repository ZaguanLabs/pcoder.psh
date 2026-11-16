#!/usr/bin/env psh
0="${ZERO:-${${0:#$ZSH_ARGZERO}:-${(%):-%N}}}"
0="${${(M)0:#/*}:-$PWD/$0}"
exec psh "${0:A:h}/pcoder.psh" "$@"
