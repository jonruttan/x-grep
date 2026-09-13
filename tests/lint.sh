#!/bin/sh
# # x-grep -- grep for x-lang
#
# ## tests/lint.sh -- shim onto the lang kit's linter
#
# @description Sources the PLATFORM's lint; vendors nothing.  --strict
#   fails on the structural rules, which is how this bundle wants them.
# @author [Jon Ruttan](jonruttan@gmail.com)
# @copyright 2026 Jon Ruttan
# @license MIT No Attribution (MIT-0)
#
#     ., .,
#     {O,O}
#     (   )
#      " "
#
# THE BUNDLE WAS SWEPT BY NOTHING.  x-lang's `make lint-x` covers lib/ and
# apps/; a lang under languages/ was covered by neither, so every rule the
# linter knows was advice this bundle never heard.
#
# It hears them now and has nothing to answer for: all six files clean,
# --strict included.  That is not luck -- #3 ("match, not a ladder of ifs")
# already did by hand what the linter's `ladder` rule asks for, before
# anything could run the rule here.  This is what keeps it true.
#
# X_LANG_KIT names a checkout's tools/lang-kit directly; otherwise the kit
# is found where x says its share tree is.  An x is needed either way --
# the kit's lint.sh asks it for --share-dir and --engine-path itself.
set -e

BUNDLE="$(cd "$(dirname "$0")/.." && pwd)"
X="${X:-x}"

command -v "$X" >/dev/null 2>&1 || {
	echo "x-grep: no x on PATH.  Set X=/path/to/x and retry." >&2
	exit 2
}

# The tree the kit's lint.sh will actually read, whatever X_LANG_KIT says:
# it resolves its linter from --share-dir, so that is what the probe judges.
X_ROOT="$("$X" --share-dir)"
KIT="${X_LANG_KIT:-$X_ROOT/tools/lang-kit}"

# A GATE THE PLATFORM CANNOT RUN YET SKIPS; it does not fail the build.
# The kit linter is new -- no released x carries it -- and `check` will
# depend on this, so hard-failing would break the build on every x that
# exists until a release lands.  A cadence this bundle does not set.
[ -f "$KIT/lint.sh" ] || {
	echo "x-grep: SKIPPING lint -- no $KIT/lint.sh in this x." >&2
	echo "x-grep: it arrives with the lang kit's linter; upgrade x to gate on it." >&2
	exit 0
}

# No targets are named: the kit's default is every .x the bundle ships minus
# the generated harness, and since x-lang#692 it stops at the bundle root
# rather than descending into a checkout nested under it.  This bundle needs
# no capability probe beyond the kit itself -- it declares no requires-lang,
# and it lints clean on every x that ships lint.sh at all.
BUNDLE="$BUNDLE" X="$X" sh "$KIT/lint.sh" --strict "$@"
