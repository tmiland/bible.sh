# Changelog

All notable changes to this project are documented in this file.

## Unreleased

### Added
- `bible self-update` (`-u`): fetch the latest `bible.sh` from the
  GitHub repo, compare the `VERSION` header, bash syntax-check the
  download and swap it in atomically. Prompts before overwriting
  (`SELF_UPDATE_YES=1` skips); falls back to a one-line curl command
  when the installed copy is not writable. The updater is a portable
  block — override `SELF_UPDATE_URL` to reuse it in other scripts.
- Launch check: the app silently checks for a newer version on start
  and, when one exists, shows `Update available: vX → vY — run: bible
  self-update (or -u)` in the home header. The remote version is cached
  in `~/.cache/bible/self-version` and re-fetched at most every
  `SELF_UPDATE_TTL` seconds (default 21600 / 6 h; `0` = check each
  launch). Disable with `bible --no-update-check` or
  `BIBLE_NO_UPDATE_CHECK=1`.
- **A proverb a day**: Read → "A proverb a day" opens the chapter of
  Proverbs matching today's date (31 chapters ↔ 31 days); reading
  records the reading spot (Continue picks it up). Also `bible proverb`.
- **The Lord's prayer**: one pick in Read (shows Matthew 6:9-13) or
  Listen (plays the verse-range audio).
- **Reading plans**: Read → "Add a reading plan" (e.g. `Psalm 65`)
  starts a plan at that chapter. Read and Listen are split: **Read**
  shows plans for reading, **Listen** mirrors the list for audio, and
  both keep the same position — wherever you quit/leave/go back becomes
  the continuation, the plan listing shows the current chapter, and the
  index's `Continue` resumes it either way. One plan per book
  (`~/.cache/bible/plans`, lines `name|osis|chapter|version`); remove
  via Read → "Remove a reading plan".
- **Arrow-key navigation**: `→`/`←` act as `[n]ext`/`[p]rev` in every
  chapter loop (Continue spot, Read browse, Listen browse, plan read,
  plan listen).
- **Continue reading plan**: Read and Listen open with a
  `Continue reading plan: <name> <ch>` shortcut for the most recently
  active plan, jumping straight back into reading/listening it.
- **Index layout**: the home hotkey bar wraps at the terminal width
  (default 80 columns) so longer labels never mid-word overflow.

## [1.2.0] - 2026-09-15

### Added
- Single-file `bible.sh`: the main script and every module
  (`bible_offline`, `bible_api`, `bible_highlights`,
  `bible_witness`) are internalized into one self-contained
  executable. One-line download and install, no companion files
  needed.
- Offline Bible support (`bible_offline.sh`): local KJV storage under
  `~/.cache/bible/` as SQLite (`KJV.db`, FTS5 full-text search) with a
  JSON fallback (`KJV.json`, jq/grep search) when `sqlite3` is absent.
- `bible install [VERSION] [--all]` and `bible update [VERSION] [--all]`
  commands: download the public-domain KJV from
  github.com/aruljohn/Bible-kjv (66 book files, parallel download) and
  build the local database. `bible status` lists installed versions.
- Offline-first routing: `bible()` (single verses and ranges), `search()`
  and `compare()` return KJV from the local database; `listen()` renders
  chapter text from it (audio unaffected). `BIBLE_ONLINE_ONLY=1` forces
  bible.com lookups.
- Frontend: `[o]ffline` menu (status, install/update/reinstall KJV) and
  CLI passthrough for install/update/status.
- YouVersion Platform API support (`bible_api.sh`): key-gated read and
  search via api.youversion.com. Active only when an app key is set
  (`YVP_APP_KEY` or `~/.credentials/.bible.com_token`) and the requested
  version is licensed to that key (20 English versions, incl. AMP, NIV,
  GNV); every failure falls back to the existing bible.com paths. Version
  licenses are discovered via `/v1/bibles` and TTL-cached; passages use
  `/v1/bibles/{id}/passages/{usfm}?format=text`; search uses
  `/v1/search-verses`. New module sourced by bible.sh when present.
- `bible hl` / `bible highlights` scaffolding (`bible_highlights.sh`):
  full OAuth PKCE login + data-exchange approval flow and
  `/v1/highlights` CRUD (list/add/delete), gated on an app key plus a
  registered OAuth client (`YVP_CLIENT_ID`, `YVP_REDIRECT_URI`). Without
  those, commands print setup instructions.
- `"Are You Saved?"` / `bible saved` walkthrough (`bible_witness.sh`):
  forward-only, interactive gospel mission following the questioning
  and preaching method of Ray Comfort (Living Waters, Way of the Master).
  Linear W/D/J/D flow through the Law and the Good Person Test, the
  Four Things About God, a sinner's-prayer stage, and next-steps.
  Credited on screen to Ray Comfort / LivingWaters.com.

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