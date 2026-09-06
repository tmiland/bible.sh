# Changelog

All notable changes to this project are documented in this file.

## [1.0.0] - 2026-09-06

### Added
- Flexible reference parsing in `args()`: supports references with or without
  colons (`` `John 3 16` `` / `` `John 3:16` ``), verse ranges, no-space
  numbered books (`2Timoteus` -> `2 Timoteus`), single-token quoted
  references, and defaults the version to `KJV` when none is given.
- CHANGELOG.md

### Fixed
- `--votd` / `bible votd` now works with the updated bible.com API. The VOTD
  response moved to `.response.data.arrayOfVerses[]`, and the default version
  is now resolved to a version id *before* the request, so the API no longer
  rejects `versionId=`. Added a `jq` dependency check and a clear
  "No verse of the day available" message when the endpoint returns nothing.
- `bible()` no longer clobbers the requested book/version when a verse is
  omitted from a comparison version (e.g. `-c Mark 11 26 en`).
- `get_bible_verse` no longer treats an empty/failed page fetch as a valid
  result; it reports "No result." instead of a misleading "verse omitted"
  message.
- All unquoted variable usages flagged by ShellCheck (`SC2086`) were quoted
  (temp file paths, redirects, `cat`/`rm` calls).

### Changed
- Flag handling: `--debug`/`--nocolor` (and the barewords `debug`/`nocolor`)
  are now stripped via a dedicated pre-scan instead of regex-matching `$*`,
  so they no longer leak into command-line argument parsing.
- Temporary files now use `mktemp` and are removed automatically via
  `trap cleanup EXIT` instead of being written to hard-coded `/tmp/*.tmp`
  paths.
- The main command dispatcher rejects unrecognized arguments instead of
  silently collecting them. `bible votd` is dispatched as a command.
- Replaced the redundant grep-guards in `output_correction` with unconditional
  parameter substitutions (`${var// ... /...}`).
- Replaced the shadowing nested `votd()` function with direct `jq` queries.
- Simplified search-query encoding to `[[ $query == *" "* ]]` / `${query// /+}`.
- Removed dead code: the undocumented `trans` output branch, `fb_share`/
  `listen` variables, the collection-then-reparse `ARGS` loop, and commented-out
  blocks.

## Credits

The argument-parsing refactor, inline flag handling, temp-file cleanup,
and the verse-of-the-day API fix in this release were contributed by
[opencode](https://opencode.ai), an AI coding assistant, working with the
maintainer.