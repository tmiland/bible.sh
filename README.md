<div align="center">

# 📖 bible.sh

**The whole Bible app in one shell file.**

Everything — interactive app, CLI, offline KJV, YouVersion API,
highlights and the *"Are You Saved?"* gospel walkthrough — lives inside
a single self-contained `bible.sh` executable. Download it, chmod it,
run it. No packages, no companion files, no config.

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Shell: bash](https://img.shields.io/badge/shell-bash-4EAA25.svg)](bible.sh)
[![Platform: Linux](https://img.shields.io/badge/platform-Linux-lightgrey.svg)](#)
[![Single file](https://img.shields.io/badge/single-file-yes-brightgreen.svg)](#)

</div>

---

## ✨ Highlights

- **One file, zero deps** — the entire app is a single ~3400-line bash script
- **Interactive app frontend** — menus for Read, Search, Compare, Listen,
  Verse of the Day, Translate, Version picker, Offline and Help
- **Straight CLI** — `bible -b John 3:16 KJV`, pipe it to your clipboard
- **Offline KJV** — full searchable local database (SQLite FTS5, no internet)
- **YouVersion Platform** — licensed read/search via `api.youversion.com`
- **Highlights** — sync your favorites/notes (OAuth)
- **"Are You Saved?"** — an interactive gospel walkthrough built on the
  Way of the Master method of Ray Comfort (Living Waters)
- **A proverb a day** — one chapter of Proverbs per day of the month,
  read in **Read** or listened to in **Listen**
- **The Lord's prayer** — one keystroke to Matthew 6:9-13 in Read, or its
  audio in Listen
- **Reading plans** — add a plan like *Psalm 65*; it continues where you
  left off whether you read it (Read) or listen to it (Listen), and the
  index `Continue` resumes the same spot
- **Flexible references** — `2Timoteus 1:2`, `2 Timoteus 1 2`, ranges, no-colon…
- **Arrow-key navigation** — `→`/`←` work like `[n]ext`/`[p]rev` in every
  chapter loop (Read, Listen, plans, Continue), plus the single-letter keys
- **Self-update** — `bible self-update` (or `-u`) pulls the latest version
  from this repo, syntax-checks it and swaps itself in atomically; a
  silent version check runs on launch and shows updates in the header
  (`--no-update-check` / `BIBLE_NO_UPDATE_CHECK=1` to disable)

---

## 🚀 Install

```shell
wget -q https://github.com/tmiland/bible.sh/raw/main/bible.sh -O ~/.scripts/bible.sh
chmod +x ~/.scripts/bible.sh
```

Symlink it into your `PATH` (optional, so you can keep calling it `bible`):

```shell
ln -sfn ~/.scripts/bible.sh ~/.local/bin/bible
```

That's it. `bible -b John 3:16 KJV` works standalone — there are no
companion files anymore.

---

## ⚡ Quick start

**The app** — run with no arguments for greeting, daily verse,
continue-reading and the interactive menu:

```shell
bible
```

**The CLI** — run with arguments for verse, search, compare, listen,
translate …:

```shell
bible -b Isaiah 54:17 KJV
```

Output:

```shell
“No weapon that is formed against thee shall prosper; and every tongue that
shall rise against thee in judgment thou shalt condemn. This is the heritage
of the servants of the LORD, and their righteousness is of me, saith the
LORD.”

Isaiah 54:17 - (KJV)
https://www.bible.com/bible/1/ISA.54.17.KJV
```

---

## 🗂 Usage

| Arguments | Example usage |
|---|---|
| `--help` \| `-h` | Show this help text. |
| `--bible` \| `-b` | `bible -b Isaiah 54:17 KJV` |
| `--search` \| `-s` | `bible -s "keyword" KJV` |
| `--votd` \| `-v` | `bible -v` |
| `--listen` \| `-l` | `bible -l Isaiah 54 KJV` |
| `--compare` \| `-c` | `bible -c Isaiah 54:17 KJV NIV NLT NKJV ESV` |
| `--translate` \| `-t` | `bible -t Isaiah 54:17 hebrew en` |
| `install` | `bible install [VERSION] [--all]` |
| `update` | `bible update [VERSION] [--all]` |
| `status` | `bible status` |

### 🔀 Compare versions

```shell
bible -c Isaiah 54:17 KJV NIV NLT NKJV ESV
```

…or the shortcut for all English/Norwegian versions:

```shell
bible -c Isaiah 54:17 [en|no]
```

…or store versions in a variable:

```shell
export compare_versions=(KJV NIV NLT NKJV ESV N78BM)
bible -c Isaiah 54 17 $compare_versions
```

### 🔍 Search

```shell
bible -s "<keywords>"
```

Searches the YouVersion Platform API first (for licensed versions):
a **pickable list of results** showing each verse's text — one search
request plus at most one passage request per result on the shown page,
cached for the session, no per-verse fetching on repeat — with
pagination via the next-page token and "did you mean" / "search
instead for" hints surfaced. Interactive runs let you pick a match to
open its chapter or page through the rest; non-interactive ones print
the page of results. Falls back to the offline KJV database, then the
bible.com search page, when the API can't run — search tells you when
it does.

### 📖 Flexible reference parsing

`-b`, `-c`, `-l` and `-t` parse references flexibly — colon or space,
with or without a space after a numbered book, single verses or ranges:

```shell
bible -b 2 Timoteus 1 2        # with space, no colon
bible -b 2Timoteus 1 2         # no space, no colon
bible -b 2 Timoteus 1:2        # with space, colon
bible -b 2Timoteus 1:2         # no space, colon
bible -b "2 Timoteus 1 2"      # whole reference as one quoted token
bible -b Psalm 23 3            # chapter only
bible -b 1 Corinthians 13 4-6  # verse range, no colon
```

A default version (KJV) is used when none is given.

### 📋 Copy to clipboard

```shell
clip() {
	xclip -selection clipboard
}
bible -b Isaiah 54 17 KJV | clip
```

---

## 📅 Verse of the day

```shell
bible votd
```

<a href="https://raw.githubusercontent.com/tmiland/bible.sh/main/assets/votd.png">![votd](https://raw.githubusercontent.com/tmiland/bible.sh/main/assets/votd.png)</a>

**Desktop notification**

<a href="https://raw.githubusercontent.com/tmiland/bible.sh/main/assets/votd_notify.png">![votd_notify](https://raw.githubusercontent.com/tmiland/bible.sh/main/assets/votd_notify.png)</a>

---

## 🌐 Offline Bible

The King James Version is fully readable, searchable and comparable
**offline**. `bible install KJV` downloads the public-domain text once;
after that every `-b`, `-s`, `-c` and frontend Read/Listen lookup for
KJV uses the local database.

```shell
bible install           # install KJV offline text
bible install KJV       # same
bible update            # refresh the local text
bible status            # show installed versions
```

Data lives in `~/.cache/bible/`:

- `KJV.db` — SQLite with an FTS5 full-text index (fastest search)
- `KJV.json` — automatic fallback when `sqlite3` isn't installed

Text source: [github.com/aruljohn/Bible-kjv](https://github.com/aruljohn/Bible-kjv)
(public domain). Set `BIBLE_ONLINE_ONLY=1` to force bible.com lookups
even for an installed version; `bible install --all` installs every
supported offline version. Other versions (NIV, NORSK, …) and VOTD /
Translate remain online-only.

---

## 👾 Self-update

Since the whole app is one file, updating is one command:

```shell
bible self-update        # or: bible -u
```

It fetches the latest `bible.sh` from this repo, compares the `VERSION`
header, runs a bash syntax check on the download and then swaps the new
file in atomically. It asks before overwriting; set `SELF_UPDATE_YES=1`
for unattended upgrades. If the installed copy isn't writable it falls
back to printing the one-line `curl` install command. The updater block
is self-contained and sets `SELF_UPDATE_URL` to another repo/file to
reuse it in any other script.

**On launch** the app silently compares against the latest version and,
when a newer one exists, shows it in the header:

```shell
Update available: v1.2.0 → v1.3.0 — run: bible self-update (or -u)
```

The remote version is cached in `~/.cache/bible/self-version` and only
re-fetched every `SELF_UPDATE_TTL` seconds (default 6 hours — set `0`
to check at every launch). To skip the check entirely:
`bible --no-update-check`, or `BIBLE_NO_UPDATE_CHECK=1`.

---

## 🗓 A proverb a day

Proverbs has exactly 31 chapters — one for each day of the month — so
the app picks the chapter matching today's date. **Read** reads it
(also `bible proverb`); **Listen** plays it:

```shell
Read → "A proverb a day"      # shows Proverbs 15
Listen → "A proverb a day"    # plays Proverbs 15 audio + transcript
```

Reading records it as your reading spot (Continue picks it up); either
way you pick up where you left off.

---

## 📘 Reading plans

Make a book your reading plan and the app remembers your spot. Start
one from **Read → "Add a reading plan"**:

```shell
Read → "Add a reading plan" → Psalm 65
Reading plan: Psalm 65 (KJV).
```

It opens at that chapter and — from then on — **Read** and **Listen**
are split cleanly:

- Both open with **`Continue reading plan: Psalm 66`** — straight back
  into your most recent plan, read or listened as appropriate.
- **Read** shows plans for reading; move on with `[n]ext` / `[p]prev`
  (or the `→` / `←` arrow keys), stop anywhere.
- **Listen** mirrors the same list for audio; each chapter plays and
  offers the same forward/back (then quits).
- Both keep the plan in step: wherever you quit/leave/go back becomes the
  continuation, the plan listing shows the current chapter, and the index
  `Continue: Psalm 66` resumes the same spot either way.

The **Lord's prayer** sits in both lists too — Read shows Matthew 6:9-13,
Listen plays it. One plan per book; remove any from
**Read → "Remove a reading plan"**.

Plans live in `~/.cache/bible/plans` (one `name|osis|chapter|version`
line per book).

---

## ☁️ YouVersion Platform API

Read and search your *licensed* versions through `api.youversion.com`
— faster, richer search metadata, and the same verses you already get.
Active when an app key is configured and the requested version is
licensed; otherwise everything falls back to the regular scraping
paths.

## ⭐ Highlights

OAuth PKCE login with the YouVersion Data-Exchange flow, then sync your
favorites/notes via `/v1/highlights`:

```shell
bible hl login      # start the OAuth approval flow
bible hl list       # list your highlights
bible hl add ...    # add a highlight
```

---

## 🙏 "Are You Saved?"

An interactive, self-directed gospel walkthrough built on the
**Way of the Master** questioning method of Ray Comfort
([Living Waters](https://livingwaters.com)):

```shell
bible saved
```

Go through the Law and the Good Person Test, judgment, grace, the
Four Things About God, a sinner's-prayer step and next steps — paged
to your terminal, one earnest question at a time.

---

## 🗣 Translate

Requires [translate-shell](https://github.com/soimort/translate-shell):

```shell
apt install translate-shell
bible -t Isaiah 54:17 hebrew en
```

Or source auto-detected (hebrew for OT, greek for NT):

```shell
bible -t John 3:16 auto no
bible -t Matthew 17:21 greek en [google|bing] [brief|full]
```

Engines with working free endpoints are google (default) and bing;
output is brief and color-free unless `full` is given. The original
verse prints above its translation for comparison.

---

## 📚 Credits

- [bible_verse-cli](https://github.com/RaynardGerraldo/bible_verse-cli/blob/master/bible_verse)
- [Iterate over arguments](https://stackoverflow.com/a/37056727) — Stack Overflow
- [Translate Shell](https://github.com/soimort/translate-shell)
- [Fastest way to view images from the terminal](https://unix.stackexchange.com/a/745334) — Unix & Linux
- [Show Notifications from Scripts Using notify-send](https://delightlylinux.wordpress.com/2020/10/25/bash-show-notifications-from-scripts-using-notify-send/)
- Offline KJV text: [Bible-kjv](https://github.com/aruljohn/Bible-kjv) (public domain)
- "Are You Saved?" gospel walkthrough: method of Ray Comfort — [Living Waters](https://livingwaters.com) (Way of the Master)

**Full write-up on the blog:** https://tmiland.com/bible-sh/

---

## ❤️ Donations

<a href="https://coindrop.to/tmiland" target="_blank"><img src="https://coindrop.to/embed-button.png" style="border-radius: 10px; height: 57px !important;width: 229px !important;" alt="Coindrop.to me"></img></a>

---

## ⚠️ Disclaimer

***Use at own risk.***

## 📄 License

[![MIT License Image](https://upload.wikimedia.org/wikipedia/commons/thumb/0/0c/MIT_logo.svg/220px-MIT_logo.svg.png)](LICENSE)

[MIT License](LICENSE) © Tommy Miland