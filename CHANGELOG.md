# Changelog

All notable changes to this project are documented in this file.

## [1.1.0] - 2026-09-11

### Added
- New `bible` frontend (no extension): app-like menus over bible.sh —
  Read (OT/NT browse with next/prev navigation), Search, Compare,
  Listen, Verse of the Day, Translate, Version picker, Help, plus
  full CLI passthrough (`bible -b John 3:16 KJV`). fzf list-picking
  when installed (numbered fallback, `NO_FZF=1` opt-out).
- Apocrypha via bible.com KJVAAE (Tobit, Judith, Wisdom, Baruch
  incl. ch 6 Epistle, 1–2 Maccabees, Bel and the Dragon, Esther
  additions); 7 new `book_case` entries with Norwegian aliases.
- Home screen: time-of-day greeting, cached daily verse
  (`~/.cache/bible`, stale fallback offline), continue-reading,
  reading streak, favorites shelf (`[f]av` in chapter nav).
- `votd()` text-only mode (`VOTD_TEXT=1`) for the home screen.
- Translate: engine picker (google|bing, `TRANS_ENGINE`), target
  quick-pick, auto source testament (hebrew OT / greek NT),
  brief-clean color-free output by default (`full` opt-in),
  engine-failure auto-retry, post-translation loop.
- `testament()` OSIS helper; shared `chapter_text()` renderer.

### Fixed
- Verse parser rewritten for the new bible.com markup: chapter
  pages lost their `twitterCard` JSON (every lookup returned
  "omitted"); verses now come from `data-usfm` spans, books from
  the localized page heading. Bonus: footnote callers, cross-ref
  notes, headings and poetry wrappers no longer leak into verses.
- `--listen` prints numbered verses instead of the raw transcript.
- `votd`/`search` no longer die on unbound `$1`/`$2` under
  `set -u` callers (the frontend runs nounset).

## [1.0.2] - 2026-09-09

### Fixed
- `--listen` / `-l`: audio filenames for non-KJV versions. The download cleanup
  stripped only `?version_id=1` from the CDN filename, so NIV
  (`?version_id=116`) produced a mangled `*.mp311` path, the `mv` failed, and
  the player fell back to the remote URL. Any version id is now stripped, the
  download is written directly to the temp path, and the player receives the
  local, properly named file.
- `--listen` transcripts: `xargs` collapsed JSON `\n` escapes into literal
  `n` (`woman,nyou`) and choked on apostrophes (`xargs: unmatched single
  quote`). The `\n` sequences are now converted to real newlines, restoring
  verse and paragraph line breaks.

### Added
- `--listen` cache: chapters already present in the audio library are no
  longer re-downloaded. Cached files are matched by their ID3-title name
  (`BookNN_VERSION.mp3`, 2-digit padded chapter); files without an ID3 title
  are stored as `BookNN_VERSION.mp3`.
- Missing-audio guard: an invalid book/chapter/version now prints
  "No audio found for ..." instead of feeding an empty URL to ffmpeg.
- Player fallback: `ffplay` (ships with ffmpeg) is used when `vlc` is not
  installed.

## [1.0.1] - 2026-09-06

### Fixed
- `--translate` / `-t` now supports space-separated references in addition to
  the colon form (`bible -t Forkynneren 12 13 greek no` /
  `bible -t Matthew 17:21 greek en`), and checks for the correct binary name:
  the `translate-shell` package installs `trans`.
- Piped output no longer leaks literal `\033[...]` color escapes. When stdout
  is not a terminal, colors are now disabled instead of falling back to
  backslash sequences that `echo` (without `-e`) prints verbatim — this also
  keeps the text fed to `trans` during translation clean.

### Changed
- Removed the WIP marker from README.md.
- Documented the testament coverage of the translate source versions in the
  help text: `greek` maps to TR1624 (New Testament only) and `hebrew` covers
  the Old Testament only, so e.g. `bible -t Forkynneren 12:13 greek no` can
  never resolve (Ecclesiastes is OT); NT verses such as
  `bible -t Filemon 1:6 greek no` work.

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
verse-of-the-day API fix, and translate command fixes were contributed by
[opencode](https://opencode.ai), an AI coding assistant, working with the
maintainer.