#!/bin/sh
# Regenerates every page's PCB background tile. Run from the repo root:  sh _tools/build-pcb.sh
# A page picks its tile with `pcb: NAME` in its front matter (home when unset). To change a page's
# board, change its seed here; the same seed always gives the same board.
set -e
mkdir -p assets/img/pcb
gen() { perl _tools/pcbgen.pl "assets/img/pcb/$1.svg" "$2"; }
gen home 7
gen projects 12
gen synth 3
gen upcoming 21
gen 404 4043
