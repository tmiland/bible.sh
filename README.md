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
- **Flexible references** — `2Timoteus 1:2`, `2 Timoteus 1 2`, ranges, no-colon…
- **Self-update** — `bible self-update` (or `-u`) pulls the latest version
  from this repo, syntax-checks it and swaps itself in atomically

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

---

## ☁️ YouVersion Platform API

Read and search your *licensed* versions through `api.youversion.com`
— faster, richer search metadata, and the same verses you already get.
Active only when an app key is configured and the requested version is
licensed; otherwise everything falls back to the regular scraping paths.

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