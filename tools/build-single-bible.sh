#!/usr/bin/env bash
## Build a single self-contained `bible.single` executable by
## internalizing bible.sh and its module libraries (bible_offline,
## bible_api, bible_highlights, bible_witness) into one file.
##
## Regenerate after editing any source file:
##     tools/build-single-bible.sh
##
## The result is a drop-in for the `bible` frontend: `bible.single`
## alone has no companion-file or directory dependency.
set -eu

cd "$(dirname "$0")/.."

readonly out="bible.single"

{
  # Frontend header: shebang + license/comment block only. The
  # companion-file sourcing and trap move into the merged body below.
  sed -n '1,26p' bible
  printf '\n## ---------------------------------------------------------------\n'
  printf '## Single-file build - bible.sh and its module libraries\n'
  printf '## (bible_offline, bible_api, bible_highlights, bible_witness)\n'
  printf '## are internalized below.  Regenerate with\n'
  printf '## tools/build-single-bible.sh after editing any source file.\n'
  printf '## ---------------------------------------------------------------\n\n'

  # bible.sh header pieces: shellcheck pragma + MIT license banner.
  sed -n '2,43p' bible.sh
  printf '\n'

  # Module libraries, in their original source order (shebang lines
  # and their leading blank stripped — they are comments-only here).
  printf '# ---------------------------------------------------------------\n'
  printf '# module: bible_offline.sh - offline SQLite/JSON storage\n'
  printf '# ---------------------------------------------------------------\n'
  tail -n +2 bible_offline.sh | sed '1{/^$/d}'
  printf '\n'
  printf '# ---------------------------------------------------------------\n'
  printf '# module: bible_api.sh - YouVersion Platform API\n'
  printf '# ---------------------------------------------------------------\n'
  tail -n +2 bible_api.sh | sed '1{/^$/d}'
  printf '\n'
  printf '# ---------------------------------------------------------------\n'
  printf '# module: bible_highlights.sh - highlights OAuth + CRUD\n'
  printf '# ---------------------------------------------------------------\n'
  tail -n +2 bible_highlights.sh | sed '1{/^$/d}'
  printf '\n'
  printf '# ---------------------------------------------------------------\n'
  printf '# module: bible_witness.sh - "Are You Saved?" walkthrough\n'
  printf '# ---------------------------------------------------------------\n'
  tail -n +2 bible_witness.sh | sed '1{/^$/d}'
  printf '\n'

  # Inline flag stripping (--debug/--nocolor) — unconditional in a
  # single executable (the sourced-as-library guard is gone).
  sed -n '84,100p' bible.sh
  printf 'set -- "${_args[@]}"\n'
  sed -n '104,112p' bible.sh
  printf '\n'

  # The rest of the library: cleanup, globals, functions, usage().
  # bible.sh's own CLI dispatcher at the tail is not needed — the
  # frontend entry below handles arguments.
  sed -n '113,1562p' bible.sh
  printf '\n'

  # Frontend: menu machinery and the entry point.
  sed -n '37,596p' bible
} > "$out"

chmod +x "$out"
printf 'built %s (%s lines)\n' "$out" "$(wc -l < "$out")"