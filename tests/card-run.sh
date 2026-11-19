#!/bin/sh
# tests/card-run.sh FILE -- run one pattern file of docs/card.md, for the
# lang kit's card check.  X is the x under test; the input is on standard
# input.
exec "${X:-x}" -l grep -- -f "$1"
