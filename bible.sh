#!/usr/bin/env bash

## Author: Tommy Miland (@tmiland) - Copyright (c) 2026
##
######################################################################
####                            bible                             ####
####   Single-file interactive Bible app and CLI — browse the      ####
####   Bible like an app: menus for Read, Search, Compare,         ####
####   Listen, VOTD, Translate.  Run with args directly:           ####
####   bible -b John 3:16 KJV                                      ####
######################################################################
#   wget -q https://github.com/tmiland/bible.sh/raw/main/bible.sh -O ~/.scripts/bible.sh
#   chmod +x ~/.scripts/bible.sh
# Symlink (call it just `bible`):
#   ln -sfn ~/.scripts/bible.sh ~/.local/bin/bible
#
# Single-file build: bible.sh and its module libraries
# (bible_offline, bible_api, bible_highlights, bible_witness)
# are internalized in this one file — no companions needed.
#
# MIT License — see LICENSE in this repo.

set -u

# shellcheck disable=SC2004,SC2317,SC2053

## Author: Tommy Miland (@tmiland) - Copyright (c) 2024


######################################################################
####                          bible.sh                            ####
####           Script to get bible verse from bible.com           ####
####        Easily get a bible verse for reading or sharing       ####
####                   Maintained by @tmiland                     ####
######################################################################

# VERSION='1.2.0' # Must stay on line 14 for updater to fetch the numbers

#------------------------------------------------------------------------------#
#
# MIT License
#
# Copyright (c) 2024 Tommy Miland
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
#------------------------------------------------------------------------------#

audio_folder="$HOME/Audio/Listen Bible"


# ---------------------------------------------------------------
# module: bible_offline.sh - offline SQLite/JSON storage
# ---------------------------------------------------------------
# shellcheck disable=SC2004,SC2001,SC2016

## Offline Bible support for bible.sh
## Provides local SQLite (with JSON fallback) storage for Bible text,
## enabling read/search/compare without an internet connection.

######################################################################
####                       bible_offline.sh                        ####
####     Local Bible database: install, update, query, search      ####
######################################################################

# --- Paths -----------------------------------------------------------
# Respect an already-set BIBLE_CACHE (allows env override for testing).
BIBLE_CACHE="${BIBLE_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/bible}"
width="${width:-80}"

_offline_db()   { echo "$BIBLE_CACHE/$1.db"; }
_offline_json() { echo "$BIBLE_CACHE/$1.json"; }

# --- Detect storage backend ------------------------------------------
_has_sqlite3=false
if command -v sqlite3 >/dev/null 2>&1; then
  _has_sqlite3=true
fi

# --- Book metadata: OSIS|API-Name|Chapters|Testament ----------------
# API names are what bible-api.com accepts in its URL path.
_OFFLINE_BOOKS=(
  "GEN|Genesis|50|ot"       "EXO|Exodus|40|ot"       "LEV|Leviticus|27|ot"
  "NUM|Numbers|36|ot"       "DEU|Deuteronomy|34|ot"  "JOS|Joshua|24|ot"
  "JDG|Judges|21|ot"        "RUT|Ruth|4|ot"           "1SA|1 Samuel|31|ot"
  "2SA|2 Samuel|24|ot"      "1KI|1 Kings|22|ot"       "2KI|2 Kings|25|ot"
  "1CH|1 Chronicles|29|ot"  "2CH|2 Chronicles|36|ot"  "EZR|Ezra|10|ot"
  "NEH|Nehemiah|13|ot"      "EST|Esther|10|ot"        "JOB|Job|42|ot"
  "PSA|Psalm|150|ot"        "PRO|Proverbs|31|ot"      "ECC|Ecclesiastes|12|ot"
  "SNG|Song of Solomon|8|ot" "ISA|Isaiah|66|ot"       "JER|Jeremiah|52|ot"
  "LAM|Lamentations|5|ot"   "EZK|Ezekiel|48|ot"      "DAN|Daniel|12|ot"
  "HOS|Hosea|14|ot"         "JOL|Joel|3|ot"           "AMO|Amos|9|ot"
  "OBA|Obadiah|1|ot"        "JON|Jonah|4|ot"          "MIC|Micah|7|ot"
  "NAM|Nahum|3|ot"          "HAB|Habakkuk|3|ot"      "ZEP|Zephaniah|3|ot"
  "HAG|Haggai|2|ot"         "ZEC|Zechariah|14|ot"    "MAL|Malachi|4|ot"
  "MAT|Matthew|28|nt"       "MRK|Mark|16|nt"          "LUK|Luke|24|nt"
  "JHN|John|21|nt"          "ACT|Acts|28|nt"          "ROM|Romans|16|nt"
  "1CO|1 Corinthians|16|nt" "2CO|2 Corinthians|13|nt" "GAL|Galatians|6|nt"
  "EPH|Ephesians|6|nt"     "PHP|Philippians|4|nt"    "COL|Colossians|4|nt"
  "1TH|1 Thessalonians|5|nt" "2TH|2 Thessalonians|3|nt"
  "1TI|1 Timothy|6|nt"     "2TI|2 Timothy|4|nt"      "TIT|Titus|3|nt"
  "PHM|Philemon|1|nt"      "HEB|Hebrews|13|nt"       "JAS|James|5|nt"
  "1PE|1 Peter|5|nt"        "2PE|2 Peter|3|nt"        "1JN|1 John|5|nt"
  "2JN|2 John|1|nt"         "3JN|3 John|1|nt"         "JUD|Jude|1|nt"
  "REV|Revelation|22|nt"
)

# --- Helpers ---------------------------------------------------------
_offline_book_lookup() {
  # $1 = OSIS code → echoes "API_Name Chapters Testament"
  local osis="$1" entry
  for entry in "${_OFFLINE_BOOKS[@]}"; do
    if [[ "$(cut -d'|' -f1 <<<"$entry")" == "$osis" ]]; then
      cut -d'|' -f2- <<<"$entry"
      return 0
    fi
  done
  return 1
}

_offline_is_installed() {
  # $1 = version (e.g. KJV). Returns 0 if local DB exists and is non-empty.
  local ver="${1^^}" db json
  db="$(_offline_db "$ver")"
  json="$(_offline_json "$ver")"
  if [[ "$_has_sqlite3" == true && -f "$db" ]]; then
    local count
    count=$(sqlite3 "$db" "SELECT COUNT(*) FROM verses;" 2>/dev/null || echo 0)
    (( count > 0 )) && return 0
  fi
  if [[ -f "$json" ]]; then
    local count
    count=$(jq '.verses | length' "$json" 2>/dev/null || echo 0)
    (( count > 0 )) && return 0
  fi
  return 1
}

_offline_verse_count() {
  local ver="${1^^}" db json
  db="$(_offline_db "$ver")"
  json="$(_offline_json "$ver")"
  if [[ "$_has_sqlite3" == true && -f "$db" ]]; then
    sqlite3 "$db" "SELECT COUNT(*) FROM verses;" 2>/dev/null || echo 0
  elif [[ -f "$json" ]]; then
    jq '.verses | length' "$json" 2>/dev/null || echo 0
  else
    echo 0
  fi
}

# --- Install / Update ------------------------------------------------
_offline_raw_url() {
  # $1 = OSIS code → echo the raw-bible GitHub file name
  local osis="$1" name
  case "$osis" in
    PSA) echo "Psalms" ;;
    SNG) echo "SongofSolomon" ;;
    *)
      name=$(_offline_book_lookup "$osis" | cut -d'|' -f1)
      echo "${name// /}"
      ;;
  esac
}

_offline_download_all() {
  # Download every book to $1 (an existing dir) in parallel.
  # Files are named RAW-<OSIS>.json. Echoes success (0).
  local dest="$1" tmp_dir entry osis raw
  tmp_dir=$(mktemp -d)
  # Control file: one "osis<TAB>rawname" pair per line.
  : > "$tmp_dir/jobs"
  for entry in "${_OFFLINE_BOOKS[@]}"; do
    osis=$(cut -d'|' -f1 <<<"$entry")
    raw=$(_offline_raw_url "$osis")
    printf '%s\t%s\n' "$osis" "$raw" >> "$tmp_dir/jobs"
  done
  xargs -P 8 -n 2 -a "$tmp_dir/jobs" bash -c '
    dir="$1"; osis="$2"; raw="$3"
    src="https://raw.githubusercontent.com/aruljohn/Bible-kjv/master/${raw}.json"
    curl -fsSL --max-time 30 "$src" -o "$dir/$osis-DL.json" 2>/dev/null \
      || { echo "FAILED $osis" >&2; exit 0; }
  ' _ "$tmp_dir" 2>/dev/null || true
  # Move downloads into place
  local f
  for f in "$tmp_dir"/*-DL.json; do
    [[ -e "$f" ]] || continue
    osis=$(basename "$f" | sed 's/-DL\.json$//')
    mv "$f" "$dest/RAW-$osis.json"
  done
  rm -rf "$tmp_dir"
}

install_version() {
  # $1 = version code (e.g. KJV), $2 = --all (optional)
  local ver="${1^^}"
  local do_all=false
  [[ "${2:-}" == "--all" ]] && do_all=true

  if [[ "$do_all" == true ]]; then
    _install_all_versions
    return $?
  fi

  if [[ "$ver" != "KJV" ]]; then
    echo "Offline install is currently only supported for KJV."
    echo "Other versions remain online-only."
    return 1
  fi

  if _offline_is_installed "$ver"; then
    echo "$ver is already installed locally."
    echo "Use 'bible update $ver' to refresh."
    return 0
  fi

  _fetch_and_build "$ver"
}

update_version() {
  local ver="${1^^}"
  local do_all=false
  [[ "${2:-}" == "--all" ]] && do_all=true

  if [[ "$do_all" == true ]]; then
    _install_all_versions
    return $?
  fi

  if [[ "$ver" != "KJV" ]]; then
    echo "Offline update is currently only supported for KJV."
    return 1
  fi

  _fetch_and_build "$ver"
}

_install_all_versions() {
  install_version "KJV"
}

_fetch_and_build() {
  local ver="$1"
  mkdir -p "$BIBLE_CACHE"

  if [[ "$_has_sqlite3" == true ]]; then
    _fetch_to_sqlite "$ver"
  else
    _fetch_to_json "$ver"
  fi
}

_fetch_to_sqlite() {
  local ver db raw_dir
  ver="$1"
  db="$(_offline_db "$ver")"
  raw_dir=$(mktemp -d)

  echo "Installing $ver to SQLite (${#_OFFLINE_BOOKS[@]} books)..."
  echo "Database: $db"

  echo "Downloading Bible text..."
  _offline_download_all "$raw_dir"

  # Remove old DB if updating
  rm -f "$db"

  # Create schema
  sqlite3 "$db" <<'SQL'
CREATE TABLE books (
  osis TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  chapters INTEGER NOT NULL,
  testament TEXT NOT NULL
);
CREATE TABLE verses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  osis TEXT NOT NULL,
  chapter INTEGER NOT NULL,
  verse INTEGER NOT NULL,
  text TEXT NOT NULL,
  UNIQUE(osis, chapter, verse)
);
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE INDEX idx_verses_ref ON verses(osis, chapter, verse);
SQL

  # Insert book metadata
  local entry osis api_name chapters testament
  for entry in "${_OFFLINE_BOOKS[@]}"; do
    osis=$(cut -d'|' -f1 <<<"$entry")
    api_name=$(cut -d'|' -f2 <<<"$entry")
    chapters=$(cut -d'|' -f3 <<<"$entry")
    testament=$(cut -d'|' -f4 <<<"$entry")
    sqlite3 "$db" "INSERT INTO books VALUES('$osis', '$api_name', $chapters, '$testament');"
  done
  sqlite3 "$db" "INSERT INTO meta VALUES ('version', '$ver'), ('source', 'https://github.com/aruljohn/Bible-kjv (KJV public domain)'), ('installed', datetime('now'));"

  # Load each raw book file (in canonical order)
  local osis raw
  : > "$raw_dir/verses.tsv"
  for entry in "${_OFFLINE_BOOKS[@]}"; do
    osis=$(cut -d'|' -f1 <<<"$entry")
    raw="$raw_dir/RAW-$osis.json"
    if [[ ! -f "$raw" ]]; then
      echo "Warning: missing $osis"
      continue
    fi
    # jq splits the book into one tab-separated record per verse
    jq -r --arg osis "$osis" '
      .chapters[] as $c |
      $c.verses[] |
      [$osis, ($c.chapter | tonumber), (.verse | tonumber), (.text | gsub("[ \t\r\n]+"; " "))] |
      @tsv
    ' "$raw" >> "$raw_dir/verses.tsv"
  done
  sqlite3 "$db" "CREATE TABLE verses_raw_import (osis TEXT, chapter INTEGER, verse INTEGER, text TEXT);"
  sqlite3 "$db" <<SQL
.mode tabs
.import '$raw_dir/verses.tsv' verses_raw_import
SQL
  sqlite3 "$db" <<'SQL'
INSERT OR IGNORE INTO verses(osis, chapter, verse, text)
  SELECT osis, chapter, verse, text FROM verses_raw_import;
DROP TABLE verses_raw_import;
SQL

  # Build FTS5 index
  echo ""
  echo "Building search index..."
  sqlite3 "$db" "CREATE VIRTUAL TABLE IF NOT EXISTS verses_fts USING fts5(text, osis, chapter, verse);"
  sqlite3 "$db" "INSERT INTO verses_fts(rowid, text, osis, chapter, verse) SELECT id, text, osis, chapter, verse FROM verses;"

  local count
  count=$(sqlite3 "$db" "SELECT COUNT(*) FROM verses;")
  echo "Installed $ver: $count verses in $db"
  rm -rf "$raw_dir"
}

_fetch_to_json() {
  local ver json_file raw_dir
  ver="$1"
  json_file="$(_offline_json "$ver")"
  raw_dir=$(mktemp -d)
  local tmp_json="$json_file.tmp"

  echo "Installing $ver to JSON (${#_OFFLINE_BOOKS[@]} books)..."
  echo "Database: $json_file"

  echo "Downloading Bible text..."
  _offline_download_all "$raw_dir"

  # Start building JSON
  echo '{"books":[' > "$tmp_json"

  # Insert book metadata
  local first=true entry osis api_name chapters testament
  for entry in "${_OFFLINE_BOOKS[@]}"; do
    osis=$(cut -d'|' -f1 <<<"$entry")
    api_name=$(cut -d'|' -f2 <<<"$entry")
    chapters=$(cut -d'|' -f3 <<<"$entry")
    testament=$(cut -d'|' -f4 <<<"$entry")
    if [[ "$first" == true ]]; then
      first=false
    else
      echo ',' >> "$tmp_json"
    fi
    printf '{"osis":"%s","name":"%s","chapters":%s,"testament":"%s"}' \
      "$osis" "$api_name" "$chapters" "$testament" >> "$tmp_json"
  done

  echo '],"verses":[' >> "$tmp_json"

  # Append verse records in canonical book/chapter order
  first=true
  local osis raw
  for entry in "${_OFFLINE_BOOKS[@]}"; do
    osis=$(cut -d'|' -f1 <<<"$entry")
    raw="$raw_dir/RAW-$osis.json"
    if [[ ! -f "$raw" ]]; then
      echo "Warning: missing $osis"
      continue
    fi
    jq -c --arg osis "$osis" '
      .chapters[] as $c |
      $c.verses[] |
      {osis: $osis, chapter: ($c.chapter | tonumber), verse: (.verse | tonumber),
       text: (.text | gsub("[ \t\r\n]+"; " "))}
    ' "$raw" > "$raw_dir/V-$osis.ndjson"
    while IFS= read -r obj; do
      [[ -z "$obj" ]] && continue
      if [[ "$first" == true ]]; then
        first=false
      else
        echo "," >> "$tmp_json"
      fi
      echo "$obj" >> "$tmp_json"
    done < "$raw_dir/V-$osis.ndjson"
  done

  echo ']}' >> "$tmp_json"
  mv "$tmp_json" "$json_file"

  local count
  count=$(jq '.verses | length' "$json_file" 2>/dev/null || echo 0)
  echo ""
  echo "Installed $ver: $count verses in $json_file"
  rm -rf "$raw_dir"
}

# --- Local Query Layer -----------------------------------------------
local_verse() {
  # $1=OSIS $2=chapter $3=verse $4=version
  # Returns verse text from local DB, or empty string if not found.
  local osis="$1" ch="$2" v="$3" ver="${4:-KJV}"
  ver="${ver^^}"
  local db json

  if [[ "$_has_sqlite3" == true ]]; then
    db="$(_offline_db "$ver")"
    if [[ -f "$db" ]]; then
      sqlite3 "$db" "SELECT text FROM verses WHERE osis='$osis' AND chapter=$ch AND verse=$v LIMIT 1;" 2>/dev/null
      return $?
    fi
  fi

  json="$(_offline_json "$ver")"
  if [[ -f "$json" ]]; then
    jq -r --arg o "$osis" --argjson c "$ch" --argjson v "$v" \
      '.verses[] | select(.osis == $o and .chapter == $c and .verse == $v) | .text' \
      "$json" 2>/dev/null | head -n 1
    return $?
  fi

  return 1
}

local_chapter_text() {
  # $1=OSIS $2=chapter $3=version — prints "N text" per verse, like chapter_text().
  local osis="$1" ch="$2" ver="${3:-KJV}"
  ver="${ver^^}"
  local db json vnum vtext

  if [[ "$_has_sqlite3" == true ]]; then
    db="$(_offline_db "$ver")"
    if [[ -f "$db" ]]; then
      while IFS='|' read -r vnum vtext; do
        if [[ -n "$vtext" ]]; then
          printf "\n${BOLD}%s${NC} %s\n" "$vnum" "$(echo "$vtext" | fold -w "${width}" -s)"
        fi
      done < <(sqlite3 "$db" "SELECT verse, text FROM verses WHERE osis='$osis' AND chapter=$ch ORDER BY verse;" 2>/dev/null)
      return 0
    fi
  fi

  json="$(_offline_json "$ver")"
  if [[ -f "$json" ]]; then
    while IFS='|' read -r vnum vtext; do
      if [[ -n "$vtext" ]]; then
        printf "\n${BOLD}%s${NC} %s\n" "$vnum" "$(echo "$vtext" | fold -w "${width}" -s)"
      fi
    done < <(jq -r --arg o "$osis" --argjson c "$ch" \
      '.verses[] | select(.osis == $o and .chapter == $c) | "\(.verse)|\(.text)"' \
      "$json" 2>/dev/null)
    return 0
  fi

  return 1
}

local_chapter_verses() {
  # $1=OSIS $2=chapter $3=version — echoes "BOOK.CH.VERSE" lines (like chapter_usfms).
  local osis="$1" ch="$2" ver="${3:-KJV}"
  ver="${ver^^}"
  local db json

  if [[ "$_has_sqlite3" == true ]]; then
    db="$(_offline_db "$ver")"
    if [[ -f "$db" ]]; then
      sqlite3 "$db" "SELECT '$osis.$ch.' || verse FROM verses WHERE osis='$osis' AND chapter=$ch ORDER BY verse;" 2>/dev/null
      return 0
    fi
  fi

  json="$(_offline_json "$ver")"
  if [[ -f "$json" ]]; then
    jq -r --arg o "$osis" --argjson c "$ch" \
      '.verses[] | select(.osis == $o and .chapter == $c) | "\($o).\(.chapter).\(.verse)"' \
      "$json" 2>/dev/null
    return 0
  fi

  return 1
}

local_range_text() {
  # $1=OSIS $2=chapter $3=verse_range $4=version — concatenated verse text.
  local osis="$1" ch="$2" range="$3" ver="${4:-KJV}"
  local start="${range%-*}" end="${range#*-}"
  local description="" vtext v

  for (( v=start; v<=end; v++ )); do
    vtext=$(local_verse "$osis" "$ch" "$v" "$ver")
    if [[ -n "$vtext" ]]; then
      description+="${description:+ }$vtext"
    fi
  done
  echo "$description"
}

local_search() {
  # $1=query $2=version — searches local DB, prints formatted results.
  local query="$1" ver="${2:-KJV}"
  ver="${ver^^}"
  local db json

  if [[ "$_has_sqlite3" == true ]]; then
    db="$(_offline_db "$ver")"
    if [[ -f "$db" ]]; then
      echo "Search results from local $ver database"
      echo ""
      divider_line
      while IFS='|' read -r v_osis v_ch v_verse v_text; do
        local book_name
        book_name=$(_offline_book_name_from_osis "$v_osis")
        local cv="$v_ch:$v_verse"
        local description
        description=$(echo "$v_text" | fold -w "${width}" -s)
        printf "\n"
        echo -n "${BQUOTE}${description}${EQUOTE}"
        printf "\n"
        echo -n "${GREEN}$book_name $cv${NC} - ${YELLOW}($ver)${NC}"
        printf "\n"
        divider_line
      done < <(sqlite3 "$db" "
        SELECT v.osis, v.chapter, v.verse, v.text
        FROM verses_fts f
        JOIN verses v ON f.rowid = v.id
        WHERE verses_fts MATCH '$(echo "$query" | sed "s/'/''/g")'
        LIMIT 20;
      " 2>/dev/null)
      return 0
    fi
  fi

  json="$(_offline_json "$ver")"
  if [[ -f "$json" ]]; then
    echo "Search results from local $ver database"
    echo ""
    divider_line
    local count=0
    while IFS='|' read -r v_osis v_ch v_verse v_text; do
      [[ -z "$v_osis" ]] && continue
      local book_name
      book_name=$(_offline_book_name_from_osis "$v_osis")
      local cv="$v_ch:$v_verse"
      local description
      description=$(echo "$v_text" | fold -w "${width}" -s)
      printf "\n"
      echo -n "${BQUOTE}${description}${EQUOTE}"
      printf "\n"
      echo -n "${GREEN}$book_name $cv${NC} - ${YELLOW}($ver)${NC}"
      printf "\n"
      divider_line
      count=$((count + 1))
      (( count >= 20 )) && break
    done < <(jq -r --arg q "$query" \
      '.verses[] | select(.text | test($q; "i")) | "\(.osis)|\(.chapter)|\(.verse)|\(.text)"' \
      "$json" 2>/dev/null)
    return 0
  fi

  return 1
}

_offline_book_name_from_osis() {
  local osis="$1" entry
  for entry in "${_OFFLINE_BOOKS[@]}"; do
    if [[ "$(cut -d'|' -f1 <<<"$entry")" == "$osis" ]]; then
      cut -d'|' -f2 <<<"$entry"
      return
    fi
  done
  echo "$osis"
}

# --- Status ----------------------------------------------------------
_OFFLINE_SUPPORTED_VERSIONS=("KJV")

offline_status() {
  echo "Offline Bible Status"
  echo ""
  divider_line
  printf "%-10s %-8s %-10s %s\n" "VERSION" "STATUS" "VERSES" "FILE"
  divider_line

  local ver db json status count
  for ver in "${_OFFLINE_SUPPORTED_VERSIONS[@]}"; do
    db="$(_offline_db "$ver")"
    json="$(_offline_json "$ver")"
    status="not installed"
    count=0
    if [[ "$_has_sqlite3" == true && -f "$db" ]]; then
      count=$(sqlite3 "$db" "SELECT COUNT(*) FROM verses;" 2>/dev/null || echo 0)
      if (( count > 0 )); then
        status="installed (SQLite)"
        printf "%-10s %-8s %-10s %s\n" "$ver" "$status" "$count" "$db"
        continue
      fi
    fi
    if [[ -f "$json" ]]; then
      count=$(jq '.verses | length' "$json" 2>/dev/null || echo 0)
      if (( count > 0 )); then
        status="installed (JSON)"
        printf "%-10s %-8s %-10s %s\n" "$ver" "$status" "$count" "$json"
        continue
      fi
    fi
    printf "%-10s %-8s\n" "$ver" "$status"
  done

  echo ""
  echo "Storage backend: $([ "$_has_sqlite3" == true ] && echo "SQLite" || echo "JSON (install sqlite3 for faster search)")"
  divider_line
}

# ---------------------------------------------------------------
# module: bible_api.sh - YouVersion Platform API
# ---------------------------------------------------------------
# shellcheck disable=SC2001,SC2317

## YouVersion Platform API support for bible.sh
## Reading and searching through the official Platform API
## (api.youversion.com) instead of scraping bible.com. Key-gated:
## nothing changes unless an app key is configured ($YVP_APP_KEY or
## ~/.credentials/.bible.com_token) AND the requested version is
## licensed to that key. Callers fall back to their existing
## scraping paths on any failure.

## App key: https://developers.youversion.com — 48 chars, sent as the
## x-yvp-app-key header (not a secret). Rate-limited: 429 + Retry-After.

_YVP_API="https://api.youversion.com/v1"
_YVP_KEY_FILE="$HOME/.credentials/.bible.com_token"
BIBLE_CACHE="${BIBLE_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/bible}"
_YVP_KEY_CACHE="$BIBLE_CACHE/bibles"

# --- Key / licensing --------------------------------------------------

_yvp_key() {
  # Echo the configured app key (non-zero when none is set):
  # 1. $YVP_APP_KEY env var
  # 2. ~/.credentials/.bible.com_token
  local key="${YVP_APP_KEY:-}"
  if [[ -z "$key" && -s "$_YVP_KEY_FILE" ]]; then
    key=$(cat "$_YVP_KEY_FILE")
  fi
  if [[ -z "$key" ]]; then
    return 1
  fi
  printf '%s' "$key"
}

_yvp_api_get() {
  # $1 = URL (extra curl args may follow). Echo the 200 body,
  # retrying once on 429 (Retry-After). Non-zero on any other status
  # or network error.
  local url="$1" tmp hdr code retry
  shift
  tmp=$(mktemp)
  hdr=$(mktemp)
  code=$(curl -s -m 20 -w '%{http_code}' -D "$hdr" -o "$tmp" -H "x-yvp-app-key: $(_yvp_key)" "$url" "$@")
  if [[ "$code" == "200" ]]; then
    cat "$tmp"
    rm -f "$tmp" "$hdr"
    return 0
  fi
  if [[ "$code" == "429" ]]; then
    retry=$(awk 'tolower($1)=="retry-after:"{print $2}' "$hdr" | tr -dc '0-9')
    rm -f "$tmp" "$hdr"
    sleep "${retry:-2}"
    tmp=$(mktemp)
    hdr=$(mktemp)
code=$(curl -s -m 20 -w '%{http_code}' -D "$hdr" -o "$tmp" -H "x-yvp-app-key: $(_yvp_key)" "$url" "$@")
    if [[ "$code" == "200" ]]; then
      cat "$tmp"
      rm -f "$tmp" "$hdr"
      return 0
    fi
  fi
  rm -f "$tmp" "$hdr"
  return 1
}

_yvp_bible_id() {
  # $1 = web version id (version_case num), $2 = lang (en).
  # Echo the Platform API bible id when that version is licensed to
  # the configured key, else non-zero. The API reuses the same
  # canonical ids as bible.com (NIV11=111, AMP=1588, GNV=2163), so
  # this is purely a licensing check against a TTL-cached collection.
  local num="$1" lang="${2:-en}" cache json id
  _yvp_key >/dev/null 2>&1 || return 1 # no key → caller falls back to scraping
  cache="$_YVP_KEY_CACHE-$lang.json"
  if [[ -f "$cache" ]] && [[ -n "$(find "$cache" -mmin -20160 2>/dev/null)" ]]; then
    json=$(<"$cache")
  elif json=$(_yvp_api_get "$_YVP_API/bibles?language_ranges[]=$lang&fields[]=id&fields[]=abbreviation&page_size=*"); then
    mkdir -p "$BIBLE_CACHE"
    printf '%s' "$json" > "$cache"
  elif [[ -f "$cache" ]]; then
    json=$(<"$cache") # stale cache beats an empty response
  else
    return 1
  fi
  id=$(printf '%s' "$json" | jq -r --arg n "$num" \
    '[.data[]? | select((.id|tostring)==$n) | .id][0] // empty' 2>/dev/null)
  [[ -n "$id" ]] || return 1
  printf '%s' "$id"
}

# --- Reading / searching ----------------------------------------------

_yvp_passage_text() {
  # $1 = platform bible id, $2 = USFM (single verse or a range,
  # e.g. "JHN.3.16" or "JHN.3.16-18"). Echo the passage text.
  local bid="$1" usfm="$2" body content
  body=$(_yvp_api_get "$_YVP_API/bibles/$bid/passages/$usfm?format=text") || return 1
  content=$(printf '%s' "$body" | jq -r '.content // empty' 2>/dev/null)
  [[ -n "$content" ]] || return 1
  printf '%s' "$content"
}

_yvp_search() {
  # $1 = platform bible id, $2 = query, $3 = max results.
  # Echo one USFM reference per line for matching verses.
  local bid="$1" query="$2" total="${3:-5}" body
  body=$(_yvp_api_get "$_YVP_API/search-verses" \
    -G --data-urlencode "query=$query" --data-urlencode "bible_id=$bid" \
    --data-urlencode "page_size=$total") || return 1
  printf '%s' "$body" | jq -r '.verses[]?.reference' 2>/dev/null
}

_yvp_book_name() {
  # $1 = OSIS code (e.g. "JHN"). Echo a displayable book name for
  # search results, reusing the offline book metadata when present.
  local osis="$1"
  if declare -f _offline_book_lookup >/dev/null 2>&1; then
    local name
    name=$(_offline_book_lookup "$osis" 2>/dev/null | cut -d'|' -f1)
    if [[ -n "$name" ]]; then
      printf '%s' "$name"
      return 0
    fi
  fi
  printf '%s' "$osis"
}
# ---------------------------------------------------------------
# module: bible_highlights.sh - highlights OAuth + CRUD
# ---------------------------------------------------------------
# shellcheck disable=SC2001,SC2317

## YouVersion Highlights — OAuth + Data-Exchange support for bible.sh
## Full scaffolding of the Platform API's highlights (favorites / notes)
## feature: OAuth PKCE authorization, and /v1/highlights CRUD.  Requires
## a registered Platform app: the App Key doubles as the OAuth client_id
## (YVP_APP_KEY or ~/.credentials/.bible.com_token) plus a Redirect URI
## (YVP_REDIRECT_URI or ~/.credentials/.bible_yvp_oauth).
##
## Without OAuth configured, every command prints clear setup instructions.
## With tokens cached, CRUD calls go through directly.

_YVP_HL_BASE="${YVP_API_BASE:-https://api.youversion.com}"
_YVP_HL_TOKEN_CACHE="${BIBLE_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/bible}/youversion-tokens.json"
# OAuth client credentials can be entered interactively (bible hl login)
# and saved here; environment variable YVP_REDIRECT_URI always wins over
# the saved value. The Platform App Key doubles as the OAuth client_id
# (YVP_APP_KEY or ~/.credentials/.bible.com_token).
_YVP_HL_CONFIG="$HOME/.credentials/.bible_yvp_oauth"
_YVP_HL_REDIRECT_DEFAULT="http://localhost:8080/oauth"

# Load the saved Redirect URI (env var wins). The file holds one line:
# YVP_REDIRECT_URI=…
_hl_config_load() {
  [[ -f "$_YVP_HL_CONFIG" ]] || return 0
  local redir
  redir=$(sed -n 's/^YVP_REDIRECT_URI=//p' "$_YVP_HL_CONFIG" | tail -1)
  [[ -z "${YVP_REDIRECT_URI:-}" && -n "$redir" ]] && YVP_REDIRECT_URI="$redir"
}

_hl_config_save() {
  mkdir -p "$HOME/.credentials"
  chmod 700 "$HOME/.credentials"
  printf 'YVP_REDIRECT_URI=%s\n' "${YVP_REDIRECT_URI:-}" > "$_YVP_HL_CONFIG"
  chmod 600 "$_YVP_HL_CONFIG"
}

_hl_configure_prompt() {
  # Collect the Platform credentials interactively. The App Key is also
  # the OAuth client_id; the Redirect URI has to be registered with the
  # app in the YouVersion Platform Portal and match exactly.
  local def
  echo "Highlights sync needs a free YouVersion Platform app."
  echo "  Register one at https://developers.youversion.com, then enter"
  echo "  its App Key and Redirect URI (found under App Basic Info and"
  echo "  OAuth Settings). Enter=skip keeps any already-saved values."
  echo "  The Redirect URI only has to match exactly -- it never has to"
  echo "  load. You'll paste the callback URL from the browser's address"
  echo "  bar."
  if _yvp_key >/dev/null 2>&1; then
    echo "  App Key (set) — also used as the OAuth client_id."
  else
    local appkey
    read -rp "App Key: " appkey </dev/tty
    if [[ -n "$appkey" ]]; then
      mkdir -p "${_YVP_KEY_FILE%/*}"
      chmod 700 "${_YVP_KEY_FILE%/*}"
      printf '%s\n' "$appkey" > "$_YVP_KEY_FILE"
      chmod 600 "$_YVP_KEY_FILE"
      echo "  App Key saved to ~/.credentials/.bible.com_token."
    else
      echo >&2 "  No App Key: syncing will fail until one is set (YVP_APP_KEY or the key file)."
    fi
  fi
  def="${YVP_REDIRECT_URI:-$_YVP_HL_REDIRECT_DEFAULT}"
  if [[ -n "$def" && -z "${YVP_REDIRECT_URI:-}" ]]; then
    echo "  Redirect URI (saved): $def"
  fi
  read -rp "Redirect URI [Enter = ${_YVP_HL_REDIRECT_DEFAULT}]: " redir </dev/tty
  YVP_REDIRECT_URI="${redir:-$def}"
}

# --- OAuth helpers ----------------------------------------------------

_hl_rand() { openssl rand -base64 "$1" | tr '+/' '-_' | tr -d '='; }

_hl_pkce_verifier() {
  # 32 bytes → 43-char base64url string
  _HL_CODE_VERIFIER=$(_hl_rand 32)
}

_hl_pkce_challenge() {
  # base64url( sha256( code_verifier ) )
  _HL_CODE_CHALLENGE=$(printf '%s' "$_HL_CODE_VERIFIER" \
    | openssl dgst -sha256 -binary \
    | openssl enc -base64 \
    | tr '+/' '-_' | tr -d '=')
}

_hl_read_tokens() {
  # Load access/refresh/id tokens from cache. Non-zero if absent.
  [[ -f "$_YVP_HL_TOKEN_CACHE" ]] || return 1
  _HL_ACCESS_TOKEN=$(jq -r '.access_token // empty' "$_YVP_HL_TOKEN_CACHE")
  _HL_REFRESH_TOKEN=$(jq -r '.refresh_token // empty' "$_YVP_HL_TOKEN_CACHE")
  _HL_ID_TOKEN=$(jq -r '.id_token // empty' "$_YVP_HL_TOKEN_CACHE")
  [[ -n "$_HL_ACCESS_TOKEN" ]]
}

_hl_write_tokens() {
  mkdir -p "$(dirname "$_YVP_HL_TOKEN_CACHE")"
  printf '{"access_token":"%s","refresh_token":"%s","id_token":"%s"}\n' \
    "$_HL_ACCESS_TOKEN" "$_HL_REFRESH_TOKEN" "$_HL_ID_TOKEN" > "$_YVP_HL_TOKEN_CACHE"
  chmod 600 "$_YVP_HL_TOKEN_CACHE"
}

_hl_id_claims() {
  # Decode the id_token payload (base64url JWT). Echoes a JSON object with
  # name/email; empty output when the token is missing or unreadable.
  local tok="${_HL_ID_TOKEN:-}" payload
  [[ -n "$tok" ]] || return 1
  payload=$(printf '%s' "$tok" | cut -d. -f2)
  payload=$(printf '%s' "$payload" | tr '_-' '/+')
  case $((${#payload} % 4)) in
    2) payload+="==" ;;
    3) payload+="=" ;;
  esac
  printf '%s' "$payload" | base64 -d 2>/dev/null | jq -c 'select((.name? != null) or (.email? != null)) | {name, email}' 2>/dev/null
}

_hl_configured() {
  # 0 when an App Key (env or key file; doubles as client_id) and a
  # Redirect URI are available.
  _hl_config_load
  _yvp_key >/dev/null 2>&1 && [[ -n "${YVP_REDIRECT_URI:-}" ]]
}

# --- Authorization ----------------------------------------------------

hl_authorize_url() {
  # Build + echo the PKCE authorization URL. The App Key is the OAuth
  # client_id (docs: "note the app_key. This will be the oauth client_id").
  # Caller must run _hl_pkce_verifier/_hl_pkce_challenge first and set
  # _HL_STATE + _HL_NONCE (commands run via $( ) can't persist them).
  local cid redir
  if ! cid=$(_yvp_key); then
    echo "No App Key configured. Set YVP_APP_KEY or ~/.credentials/.bible.com_token." >&2
    return 1
  fi
  redir="${YVP_REDIRECT_URI:-}"
  if [[ -z "$redir" ]]; then
    echo "No Redirect URI configured. Set YVP_REDIRECT_URI or run: bible hl login" >&2
    return 1
  fi
  local scope="${YVP_HL_SCOPE:-openid%20profile%20email}"
  local url="${_YVP_HL_BASE}/auth/authorize"
  printf '%s?client_id=%s&response_type=code&redirect_uri=%s&scope=%s&nonce=%s&code_challenge=%s&code_challenge_method=S256&state=%s&requested_permissions[]=%s' \
    "$url" "$cid" "$redir" "$scope" "${_HL_NONCE:-}" "${_HL_CODE_CHALLENGE:-}" "$_HL_STATE" "highlights"
}

hl_login() {
  # Interactive PKCE login (current two-hop flow): print authorize URL,
  # wait for the user to paste the callback URL from the browser, replay
  # state to /auth/callback to obtain the code, then exchange for tokens.
  # When not configured yet, prompt for the App Key / Redirect URI first
  # and offer to save them for next time.
  if _hl_read_tokens; then
    echo "Already logged in (tokens cached)."
    return 0
  fi
  if ! _hl_configured; then
    _hl_configure_prompt || return 1
    local save_ans
    if _hl_configured; then
      read -rp "Save credentials to ~/.credentials/.bible_yvp_oauth? [y/N] " save_ans </dev/tty
      case "$save_ans" in
        y | Y) _hl_config_save; echo "Saved." ;;
      esac
    fi
  fi
  local auth_url cb code tkn_url
  _hl_pkce_verifier
  _hl_pkce_challenge
  _HL_STATE=$(_hl_rand 16)
  _HL_NONCE=$(_hl_rand 16)
  auth_url=$(hl_authorize_url) || return 1
  echo "Open the following URL in your browser:"
  echo
  echo "  $auth_url"
  echo
  # Try to open automatically
  if command -v xdg-open >/dev/null; then
    xdg-open "$auth_url" 2>/dev/null &
  fi
  local try=0
  while (( try < 3 )); do
    (( try++ ))
    echo "After approving, copy the full URL from the browser's address bar"
    echo "and paste it here. It starts with ${YVP_REDIRECT_URI} and may look"
    echo "like a broken page — that's fine, the URL itself is what we need."
    read -r cb
    cb="${cb%%#*}"                # strip any fragment
    local cb_state cb_code cb_err
    cb_state=$(printf '%s' "$cb" | sed -n 's/^.*[?&]state=\([^&]*\).*$/\1/p')
    cb_code=$(printf '%s' "$cb" | sed -n 's/^.*[?&]code=\([^&]*\).*$/\1/p')
    cb_err=$(printf '%s' "$cb" | sed -n 's/^.*[?&]error=\([^&]*\).*$/\1/p')
    if [[ "$cb" == *"auth/authorize"* || "$cb" == *"client_id="* ]]; then
      echo >&2 "  That looks like the authorize URL, not the callback URL."
      echo >&2 "  Approve in the browser first; your address bar will then show"
      echo >&2 "  ${YVP_REDIRECT_URI}?state=... — paste that one."
      continue
    fi
    if [[ -n "$cb_err" ]]; then
      local cb_ed
      cb_ed=$(printf '%s' "$cb" | sed -n 's/^.*[?&]error_description=\([^&]*\).*$/\1/p' | sed 's/+/ /g')
      echo >&2 "  Authorization failed on YouVersion's side: $cb_err${cb_ed:+ ($cb_ed)}"
      return 1
    fi
    if [[ -z "$cb_code" && -n "$cb_state" ]]; then
      # First (state-only) callback: replay state to /auth/callback. A CLI
      # can do this with curl -L; a browser cannot (fetch hides Location).
      echo "  Obtaining the authorization code…"
      local eff eff_err
      eff=$(curl -s -L -m 20 -o /dev/null -w '%{url_effective}' \
        "${_YVP_HL_BASE}/auth/callback?state=$cb_state")
      cb_code=$(printf '%s' "$eff" | sed -n 's/^.*[?&]code=\([^&]*\).*$/\1/p')
      eff_err=$(printf '%s' "$eff" | sed -n 's/^.*[?&]error=\([^&]*\).*$/\1/p')
      if [[ -z "$cb_code" && -n "$eff_err" ]]; then
        echo >&2 "  Authorization failed on YouVersion's side: $eff_err"
        return 1
      fi
      if [[ -n "$cb_code" ]]; then break; fi
      echo >&2 "  No code yet — approve in the browser, then paste the callback"
      echo >&2 "  URL from the address bar again."
      continue
    fi
    if [[ -n "$cb_code" ]]; then break; fi
    echo >&2 "  I couldn't find a code or state in that. Paste the full"
    echo >&2 "  callback URL from the browser's address bar."
  done
  if [[ -z "${cb_code:-}" ]]; then
    echo "No authorization code." >&2
    return 1
  fi
  # Exchange code for tokens (App Key as client_id)
  local body cid
  cid=$(_yvp_key) || return 1
  body=$(_yvp_api_get "${_YVP_HL_BASE}/auth/token" \
    --data-urlencode "grant_type=authorization_code" \
    --data-urlencode "code=$cb_code" \
    --data-urlencode "client_id=$cid" \
    --data-urlencode "redirect_uri=${YVP_REDIRECT_URI}" \
    --data-urlencode "code_verifier=${_HL_CODE_VERIFIER}" \
    2>/dev/null) || { echo "Token exchange failed." >&2; return 1; }
  _HL_ACCESS_TOKEN=$(printf '%s' "$body" | jq -r '.access_token // empty' 2>/dev/null)
  _HL_REFRESH_TOKEN=$(printf '%s' "$body" | jq -r '.refresh_token // empty' 2>/dev/null)
  _HL_ID_TOKEN=$(printf '%s' "$body" | jq -r '.id_token // empty' 2>/dev/null)
  if [[ -z "$_HL_ACCESS_TOKEN" ]]; then
    echo "No access_token in response. Raw:" >&2
    printf '%s\n' "$body" >&2
    return 1
  fi
  _hl_write_tokens
  echo "Login successful."
}

# --- Data-Exchange approval -------------------------------------------

_hl_de_start() {
  # Start the data-exchange approval. Requires a valid access token.
  _hl_read_tokens || { echo "Not logged in. Run: bible hl login" >&2; return 1; }
  local body
  body=$(curl -s -m 20 \
    -X POST \
    -H "x-yvp-app-key: $(_yvp_key)" \
    -H "Authorization: Bearer $_HL_ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"requested_permissions":["highlights"]}' \
    "${_YVP_HL_BASE}/data-exchange/token") || return 1
  _HL_DE_TOKEN=$(printf '%s' "$body" | jq -r '.token // empty' 2>/dev/null)
  if [[ -z "$_HL_DE_TOKEN" ]]; then
    echo "data-exchange token request failed:" >&2
    printf '%s\n' "$body" >&2
    return 1
  fi
}

_hl_de_complete() {
  # Complete the data exchange (must be called AFTER user approval).
  [[ -n "${_HL_DE_TOKEN:-}" ]] || { echo "No pending data exchange." >&2; return 1; }
  local body
  body=$(curl -s -m 20 \
    -X POST \
    -H "x-yvp-app-key: $(_yvp_key)" \
    -H "Authorization: Bearer $_HL_ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    "${_YVP_HL_BASE}/data-exchange?token=$_HL_DE_TOKEN") || return 1
  local status
  status=$(printf '%s' "$body" | jq -r '.status // empty' 2>/dev/null)
  echo "Data exchange status: ${status:-unknown}"
}

hl_approve() {
  # One-shot approval: start exchange → print URL → complete.
  if ! _hl_configured; then
    echo "OAuth not configured. Run: bible hl login --help" >&2
    return 1
  fi
  _hl_de_start || return 1
  echo "Approve highlights access at the following URL:"
  echo
  echo "  ${_YVP_HL_BASE}/data-exchange?token=${_HL_DE_TOKEN}"
  echo
  if command -v xdg-open >/dev/null; then
    xdg-open "${_YVP_HL_BASE}/data-exchange?token=$_HL_DE_TOKEN" 2>/dev/null &
  fi
  echo "Press Enter after approval to complete."
  read -r
  _hl_de_complete
}

# --- Highlights CRUD --------------------------------------------------

hl_list() {
  # List highlights for an optional bible/passage filter.
  _hl_read_tokens || { echo "Not logged in. Run: bible hl login" >&2; return 1; }
  local bid="${1:-}" url="${_YVP_HL_BASE}/v1/highlights"
  [[ -n "$bid" ]] && url+="?bible_id=$bid"
  local body
  body=$(curl -s -m 20 \
    -H "x-yvp-app-key: $(_yvp_key)" \
    -H "Authorization: Bearer $_HL_ACCESS_TOKEN" \
    "$url") || return 1
  local count
  count=$(printf '%s' "$body" | jq '.highlights | length' 2>/dev/null || echo 0)
  if [[ "$count" -eq 0 ]]; then
    echo "No highlights found."
    return 0
  fi
  printf '%s' "$body" | jq -r '
    .highlights[] |
    "\(.reference // "unknown")  [\(.content | split("\n")[0][:60])]"' 2>/dev/null
}

hl_add() {
  # Add a highlight.  Usage: bible hl add <bible_id> <usfm> <content>
  _hl_read_tokens || { echo "Not logged in. Run: bible hl login" >&2; return 1; }
  local bid="$1" usfm="$2" content="$3"
  if [[ -z "$bid" || -z "$usfm" || -z "$content" ]]; then
    echo "Usage: bible hl add <bible_id> <usfm> <content>" >&2
    return 1
  fi
  local chapter verse
  chapter="${usfm%.*}"; chapter="${chapter#*.}"
  verse="${usfm##*.}"
  local body
  body=$(curl -s -m 20 \
    -X POST \
    -H "x-yvp-app-key: $(_yvp_key)" \
    -H "Authorization: Bearer $_HL_ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$(printf '{"content":"%s","version_id":%s,"book_id":0,"chapter":%s,"verse":%s,"reference":"%s"}' \
      "$content" "$bid" "$chapter" "$verse" "$usfm")" \
    "${_YVP_HL_BASE}/v1/highlights") || return 1
  printf '%s' "$body" | jq -r '.id // "error: \(.error_description // .error)"' 2>/dev/null
}

hl_delete() {
  # Delete a highlight by id.
  _hl_read_tokens || { echo "Not logged in. Run: bible hl login" >&2; return 1; }
  local hid="$1"
  if [[ -z "$hid" ]]; then
    echo "Usage: bible hl delete <highlight_id>" >&2
    return 1
  fi
  curl -s -m 20 \
    -X DELETE \
    -H "x-yvp-app-key: $(_yvp_key)" \
    -H "Authorization: Bearer $_HL_ACCESS_TOKEN" \
    "${_YVP_HL_BASE}/v1/highlights/$hid" >/dev/null
  echo "Deleted."
}

hl_status() {
  _hl_config_load
  if _yvp_key >/dev/null 2>&1; then
    echo "App Key:          set (also the OAuth client_id)"
  else
    echo "App Key:          not set"
  fi
  echo "OAuth configured: $(if _hl_configured; then echo yes; else echo no; fi)"
  if _hl_configured; then
    echo "Redirect URI:     ${YVP_REDIRECT_URI}"
  fi
  [[ -f "$_YVP_HL_CONFIG" ]] && echo "Config file:      $_YVP_HL_CONFIG"
  if _hl_read_tokens 2>/dev/null; then
    echo "Tokens cached:    yes"
    local claims nm em
    claims=$(_hl_id_claims)
    if [[ -n "$claims" ]]; then
      nm=$(printf '%s' "$claims" | jq -r '.name // empty')
      em=$(printf '%s' "$claims" | jq -r '.email // empty')
      if [[ -n "$nm" && -n "$em" ]]; then
        echo "Account:          $nm <$em>"
      elif [[ -n "$nm" ]]; then
        echo "Account:          $nm"
      elif [[ -n "$em" ]]; then
        echo "Account:          $em"
      fi
    fi
  else
    echo "Tokens cached:    no"
  fi
}

# ---------------------------------------------------------------
# module: bible_witness.sh - "Are You Saved?" walkthrough
# ---------------------------------------------------------------
# shellcheck disable=SC2317

## "Are You Saved?" — the Way of the Master walkthrough for bible.sh
##
## An interactive gospel walkthrough following the questioning and
## preaching method of Ray Comfort (Living Waters Publications;
## "The Way of the Master", with Kirk Cameron).  The method is WDJD:
##   W — Would you consider yourself a good person?
##   D — Do you think you have kept the Ten Commandments?
##   J — If God judges you by the Ten Commandments, guilty or innocent?
##   D — Then would you go to heaven or to hell?
## followed by the Law-driven gospel ("Four Things You Need to Know
## About God") and a repentance-and-faith prayer.
##
## Questions are directed at the user — this is a personal examination,
## not coaching someone else to witness.  After going through it, the
## user is equipped to lead others the same way.
##
## Method accredited to Ray Comfort — Living Waters, Way of the Master.
## https://livingwaters.com

_witness_enter() {
  printf "${DIM}▶ [enter]${NC}\n" >&2
  read -rsn1 _ </dev/tty || true
  printf '\n' >&2
}

# Self-directed yes/no — answer for yourself, one keypress each.
_witness_confirm() {
  local q="$1" key
  _witness_ans=""
  printf "  %s ${DIM}[y]es / [n]o${NC} " "$q" >&2
  read -rsn1 key </dev/tty || true
  case "${key,,}" in
    y)
      _witness_ans=y
      ;;
    *)
      _witness_ans=n
      ;;
  esac
  printf '\n' >&2
}

# Question directed at you.
_witness_q() {
  printf "${YELLOW}%s${NC}\n" "$1"
}

# Sober truth spoken over you — the Law's conclusions.
_witness_t() {
  printf "${YELLOW}%s${NC}\n" "$1"
}

# Notes and asides.
_witness_note() {
  printf "${DIM}%s${NC}\n" "$1"
}

# Section headings.
_witness_heading() {
  printf "${GREEN}%s${NC}\n" "$1"
  printf "${DIM}%s${NC}\n" "——————————————————————————————————————"
}

# Bare verse text via the library renderer with links/headers stripped
# (BIBLE_PLAIN mode emits only the description).
_witness_verse_text() {
  ( BIBLE_PLAIN=1 bible "$1" "$WITNESS_VERSION" ) 2>/dev/null
}

# One verse or a short range — clean output: ref header + folded text
# only.  No link, no duplicate book/chapter/verse header.
_witness_show() {
  local ref="$1" text
  printf '\n'
  printf "${BLUE}%s${NC}\n" "$ref"
  text=$(_witness_verse_text "$ref")
  if [[ -n "$text" ]]; then
    printf '%s\n' "$(echo "$text" | fold -w "${width:-80}" -s)"
  fi
  printf '\n'
}

# Pager state — the walkthrough pages long sections against the real
# terminal height so the section top never scrolls off first.
_WITNESS_PAGE_ROWS=0
_WITNESS_PAGE_H=24
_WITNESS_PAGE_TITLE=""

# Pager pause — shown between pages of a long listing. Any key goes on.
# The screen clears and the section heading reprints at the true top
# row, so it never scrolls away.
_witness_page_pause() {
  printf "${DIM}[space] continue${NC} " >&2
  read -rsn1 _ </dev/tty || true
  printf '\n' >&2
  if [[ -n "${_WITNESS_PAGE_TITLE:-}" ]]; then
    tput clear 2>/dev/null || printf '\033[2J\033[H'
    printf "${GREEN}%s${NC} ${DIM}(continued)${NC}\n" "$_WITNESS_PAGE_TITLE"
    _WITNESS_PAGE_ROWS=1
  else
    _WITNESS_PAGE_ROWS=0
  fi
}

# Measure the terminal (minus room for the [space] prompt row) and
# reset the row counter.  Call at the top of a section to be paged;
# pass the section title to keep it on screen across pages.  The
# screen is cleared so the heading starts at the true top row and
# cannot scroll off on the first page.
_witness_pager_begin() {
  local h
  tput clear 2>/dev/null || printf '\033[2J\033[H'
  h=$(tput lines 2>/dev/null || echo 24)
  (( h -= 2 ))
  (( h < 8 )) && h=8
  _WITNESS_PAGE_H=$h
  _WITNESS_PAGE_ROWS=0
  _WITNESS_PAGE_TITLE="${1:-}"
}

# Print one block and count its visible rows; pause when the screen
# tip is reached.
_witness_pager_print() {
  local s="$1" rows
  printf '%s\n' "$s"
  rows=$(printf '%s\n' "$s" | fold -w "${width:-80}" -s | wc -l)
  _WITNESS_PAGE_ROWS=$(( _WITNESS_PAGE_ROWS + rows ))
  if (( _WITNESS_PAGE_ROWS >= _WITNESS_PAGE_H )); then
    _witness_page_pause
  fi
}

# A whole range, verse by verse — numbered and separated (useful for
# the Ten Commandments).  Pages against terminal height: spacebar
# advances, Enter finishes.
_witness_show_verses() {
  local ref="$1" book ch start end v text folded rows
  if [[ "$ref" =~ ^(.+)[[:space:]]+([0-9]+):([0-9]+)-([0-9]+)$ ]]; then
    book="${BASH_REMATCH[1]}"
    ch="${BASH_REMATCH[2]}"
    start="${BASH_REMATCH[3]}"
    end="${BASH_REMATCH[4]}"
    if (( start <= end && end - start <= 50 )); then
      _witness_pager_print ""
      _witness_pager_print "${BLUE}${ref}${NC}"
      for (( v = start; v <= end; v++ )); do
        text=$(_witness_verse_text "$book $ch:$v")
        if [[ -n "$text" ]]; then
          folded=$(echo "$text" | fold -w "${width:-80}" -s)
          printf '%s  %s\n' "${BOLD}${v}${NC}" "$folded"
          printf '\n'
          # Exact rendered rows, including wrap from the number prefix
          # and the blank separator line.
          rows=$(printf '%s\n' "$v  $text" | fold -w "${width:-80}" -s | wc -l)
          rows=$(( rows + 1 ))
          _WITNESS_PAGE_ROWS=$(( _WITNESS_PAGE_ROWS + rows ))
          if (( v < end && _WITNESS_PAGE_ROWS >= _WITNESS_PAGE_H )); then
            _witness_page_pause
          fi
        fi
      done
      return
    fi
  fi
  _witness_show "$1"
}

witness_saved() {
  WITNESS_VERSION="${1:-${DEF_VERSION:-KJV}}"

  _witness_heading "ARE YOU SAVED?"
  printf '\n'
  printf "%s\n" \
    "There is one question that matters most:  Are you saved?"
  printf "%s\n" \
    "The path to the answer goes through God's Law, then through"
  printf "%s\n" \
    "His grace.  Follow it."
  printf '\n'
  _witness_enter

  # --- W: the good person question -----------------------------------
  _witness_heading "1 · ARE YOU A GOOD PERSON?"
  _witness_q "Would you consider yourself to be a good person?"
  _witness_note "Be honest with yourself."
  _witness_show "Romans 3:23"
  _witness_enter

  # --- D: the Ten Commandments ---------------------------------------
  _witness_heading "2 · THE TEN COMMANDMENTS"
  _witness_q "Do you think you have kept the Ten Commandments?"
  _witness_note "Let's find out — honestly."
  _witness_enter

  _witness_heading "3 · THE GOOD PERSON TEST"
  _witness_q "Have you ever told a lie?"
  _witness_confirm "Have you?"
  if [[ "$_witness_ans" == y ]]; then
    _witness_t "What does that make you?  A liar."
  else
    _witness_t "You have never told one lie in your whole life?"
  fi
  _witness_enter
  _witness_show "Revelation 21:8"
  _witness_enter

  _witness_q "Have you ever stolen anything, no matter how small?"
  _witness_confirm "Have you?"
  if [[ "$_witness_ans" == y ]]; then
    _witness_t "What does that make you?  A thief."
  else
    _witness_t "Never even a paper clip or a ballpoint pen?"
  fi
  _witness_enter

  _witness_q "Have you ever taken God's name in vain — even 'Oh my God!'?"
  _witness_confirm "Have you?"
  if [[ "$_witness_ans" == y ]]; then
    _witness_t "What does that make you?  A blasphemer."
  else
    _witness_note "Be honest — your conscience already knows."
  fi
  _witness_enter

  _witness_q "Have you ever looked at someone with lust?"
  _witness_confirm "Have you?"
  if [[ "$_witness_ans" == y ]]; then
    _witness_t "Jesus said that makes you an adulterer at heart."
  fi
  _witness_enter
  _witness_show "Matthew 5:27-28"
  _witness_enter

  _witness_q "Have you ever hated anyone?"
  _witness_confirm "Have you?"
  if [[ "$_witness_ans" == y ]]; then
    _witness_t "Then you are a murderer at heart."
  fi
  _witness_enter
  _witness_show "1 John 3:15"
  _witness_enter

  # --- Law standard ---------------------------------------------------
  _witness_pager_begin "4 · THE LAW STANDARD"
  _witness_pager_print "${GREEN}4 · THE LAW STANDARD${NC}"
  _witness_pager_print "${DIM}——————————————————————————————————————${NC}"
  _witness_pager_print ""
  _witness_pager_print "${YELLOW}By your own words you are a liar, a thief, a blasphemer, an${NC}"
  _witness_pager_print "${YELLOW}adulterer and a murderer at heart.  If you are found guilty of${NC}"
  _witness_pager_print "${YELLOW}breaking one of the Ten Commandments, you are guilty of all.${NC}"
  _witness_pager_print ""
  _witness_pager_print "${BLUE}James 2:10${NC}"
  jtext=$(_witness_verse_text "James 2:10")
  if [[ -n "$jtext" ]]; then
    _witness_pager_print "$jtext"
  fi
  _witness_pager_print "${DIM}Read the Law in full:${NC}"
  _witness_show_verses "Exodus 20:1-17"
  _witness_enter

  # --- J: judgment ---------------------------------------------------
  _witness_heading "5 · JUDGMENT"
  _witness_q \
    "If God judges you by the Ten Commandments on the Day of Judgment,"
  _witness_q \
    "would you be innocent or guilty?"
  _witness_confirm "Guilty?"
  if [[ "$_witness_ans" == n ]]; then
    _witness_t "Your own conscience has already shown you — you are guilty."
  else
    _witness_t "Guilty.  That is exactly what the Law is for — to show us our sin."
  fi
  _witness_show "Romans 3:19-20"
  _witness_enter

  _witness_q "Does that concern you?"
  _witness_q "If God were to give you justice, what would you deserve?"
  _witness_show "Romans 6:23"
  _witness_note "Sin must be punished — a good judge is just.  God is holy and just."
  _witness_show "Psalm 89:14"
  _witness_enter

  # --- D: destiny ----------------------------------------------------
  _witness_heading "6 · DESTINY"
  _witness_q "If you were to die tonight and face this holy God,"
  _witness_q "would you go to heaven or to hell?"
  _witness_note "Now the bad news is clear — and it makes the good news good."
  _witness_enter

  # --- The gospel ----------------------------------------------------
  _witness_heading "7 · THE GOOD NEWS"
  _witness_t "God is holy and just — yet He is also rich in mercy."
  _witness_show "Ephesians 2:4-5"
  _witness_t "God came to us in Jesus Christ and paid the fine that you owe."
  _witness_show "John 3:16"
  _witness_t "Jesus took your punishment on the cross, and rose again from"
  _witness_t "the dead — defeating death.  You do not pay; He paid it all."
  _witness_show "1 Corinthians 15:3-4"
  _witness_t "Eternal life is a gift.  You cannot earn it — you can only"
  _witness_t "receive it by repentance and faith."
  _witness_show "Ephesians 2:8-9"
  _witness_enter

  # --- The prayer ----------------------------------------------------
  _witness_heading "8 · DO YOU WANT TO BE SAVED?"
  _witness_q "Would you like to repent and trust in Jesus today?"
  _witness_confirm "Will you?"
  if [[ "$_witness_ans" == n ]]; then
    _witness_note "You can come back to this moment anytime."
  fi
  _witness_note "Pray, in your own words, from the heart:"
  printf '\n'
  printf "  ${GREEN}Dear God, I understand that I have broken Your Law and${NC}\n"
  printf "  ${GREEN}sinned against You.  Please forgive my sins.  Thank You${NC}\n"
  printf "  ${GREEN}that Jesus suffered and died on the cross in my place${NC}\n"
  printf "  ${GREEN}and rose again.  I now place my trust in Him as my${NC}\n"
  printf "  ${GREEN}Savior and Lord.  In Jesus' name I pray.  Amen.${NC}\n"
  printf '\n'
  _witness_enter

  # --- Saved ---------------------------------------------------------
  _witness_heading "9 · SAVED"
  printf "${GREEN}%s${NC}\n" \
    "If you repented and trusted in Jesus, then you are forgiven."
  printf "${GREEN}%s${NC}\n" \
    "You have passed from death to life.  YOU ARE SAVED."
  _witness_show "John 5:24"
  _witness_enter

  _witness_heading "10 · NEXT STEPS"
  _witness_q "Read the Bible daily — let it grow your faith."
  _witness_show "1 Peter 2:1-3"
  _witness_q "Pray when you need God — He hears you."
  _witness_show "1 John 5:15"
  _witness_q "Get baptized, and find a church that teaches the Bible."
  _witness_t "God is able to keep you from stumbling and to present"
  _witness_t "you faultless in His presence with exceeding joy."
  _witness_show "Jude 1:24"
  _witness_enter

  printf "${GREEN}%s${NC}\n" \
    "You leave saved.  Welcome to the family of God."
  printf '\n'
  printf "${DIM}%s${NC}\n" "Method: The Way of the Master — Ray Comfort, Living Waters"
  printf "${DIM}%s${NC}\n" "LivingWaters.com"
  printf "${DIM}%s${NC}\n" "https://www.youtube.com/@LivingWaters"
  printf '\n'
}
# Inline flags are stripped here so they don't leak into argument parsing
DEBUG=''
NOCOLOR=false
_args=()
for _arg in "$@"; do
  case "$_arg" in
    --debug|debug)
      DEBUG=true
      ;;
    --nocolor|--no-color|nocolor)
      NOCOLOR=true
      ;;
    *)
      _args+=("$_arg")
      ;;
  esac
done
set -- "${_args[@]}"
unset _args

if [[ "$DEBUG" == true ]]
then
  set -o errexit
  set -o pipefail
  set -o nounset
  set -o xtrace
fi


# Temporary files are cleaned up on exit
tmp_files=()
cleanup() {
  if [[ ${#tmp_files[@]} -gt 0 ]]; then
    rm -f "${tmp_files[@]}"
  fi
}
trap cleanup EXIT
# Symlink: ln -sfn ~/.scripts/bible.sh ~/.local/bin/bible
CROSS='✝'
BQUOTE='“'
EQUOTE='”'
# Use colors, but only if connected to a terminal, and that terminal
# supports them.
if which tput >/dev/null 2>&1; then
  ncolors=$(tput colors)
fi

if [[ "$NOCOLOR" == true ]]
then
  #RED='\033[0;31m'
  GREEN=''
  YELLOW=''
  BLUE=''
  BOLD=""
  DIM=""
  NC=''
else
  if [ -t 1 ] && [ -n "$ncolors" ] && [ "$ncolors" -ge 8 ]; then
    #RED="$(tput setaf 1)"
    GREEN="$(tput setaf 2)"
    YELLOW="$(tput setaf 3)"
    BLUE="$(tput setaf 4)"
    BOLD="$(tput bold)"
    DIM="$(tput dim)"
    NC="$(tput sgr0)"
  else
    # Not a terminal: no colors, so piped output (e.g. translate) stays clean.
    GREEN=''
    YELLOW=''
    BLUE=''
    BOLD=""
    DIM=""
    NC=''
  fi
fi
# Maximum column width
width=$((80))
bible_book_name=
bible_book=
book=
chapter=
verse=
version=
lang=
compare_versions_no=(B2024BM NORSK NB N78BM N11BM BGO_HVER BGO)
compare_versions_en=(KJV NKJV NIV NLT ESV)

divider_line() {
  # Credit: https://stackoverflow.com/a/42762743
  printf '%*s\n' "$width" '' | tr ' ' -
}

version_case() {
  case "$version" in
    B2024BM)
      num=4779
      lang=no
      ;;
    NORSK)
      num=121
      lang=no
      ;;
    NB)
      num=102
      lang=no
      ;;
    N78BM)
      num=30
      lang=no
      ;;
    N11BM)
      num=29
      lang=no
      ;;
    ELB)
      num=115
      lang=no
      ;;
    BGO_HVER)
      num=2321
      lang=no
      ;;
    BGO)
      num=2216
      lang=no
      ;;
    KJV)
      num=1
      lang=en
      ;;
    KJVAAE)
      num=546
      lang=en
      ;;
    KJVAE)
      num=547
      lang=en
      ;;
    NKJV)
      num=114
      lang=en
      ;;
    NIV)
      num=111
      lang=en
      ;;
    ESV)
      num=59
      lang=en
      ;;
    NLT)
      num=116
      lang=en
      ;;
    AMP)
      num=1588
      lang=en
      ;;
    GNV)
      num=2163
      lang=en
      ;;
    WBMS)
      num=2407
      lang=en
      ;;
    TR1624) # Elzevir textus receptus 1624
      num=182
      lang=gr
      ;;
    תנ\"ך)
      num=2376
      lang=heb
      ;;
  esac
}

book_case() {
  shopt -s nocasematch
  case "$book" in
    GEN|Genesis|"1 Mosebok")
      bible_book_name="Genesis"
      bible_book="GEN"
      ;;
    EXO|Exodus|"2 Mosebok")
      bible_book_name="Exodus"
      bible_book="EXO"
      ;;
    LEV|Leviticus|"3 Mosebok")
      bible_book_name="Leviticus"
      bible_book="LEV"
      ;;
    NUM|Numbers|"4 Mosebok")
      bible_book_name="Numbers"
      bible_book="NUM"
      ;;
    DEU|Deuteronomy|"5 Mosebok")
      bible_book_name="Deuteronomy"
      bible_book="DEU"
      ;;
    JOS|Joshua|Josva)
      bible_book_name="Joshua"
      bible_book="JOS"
      ;;
    JDG|Judges|Dommerne)
      bible_book_name="Judges"
      bible_book="JDG"
      ;;
    RUT|Ruth|Rut)
      bible_book_name="Ruth"
      bible_book="RUT"
      ;;
    1SA|"1 samuel"|"1 Samuelsbok")
      bible_book_name="1 samuel"
      bible_book="1SA"
      ;;
    2SA|"2 samuel"|"2 Samuelsbok")
      bible_book_name="2 samuel"
      bible_book="2SA"
      ;;
    1KI|"1 Kings"|"1 Kongebok")
      bible_book_name="1 Kings"
      bible_book="1KI"
      ;;
    2KI|"2 Kings"|"2 Kongebok")
      bible_book_name="2 Kings"
      bible_book="2KI"
      ;;
    1CH|"1 Chronicles"|1Chronicles|"1 Krønikebok"|1Krønikebok)
      bible_book_name="1 Chronicles"
      bible_book="1CH"
      ;;
    2CH|"2 Chronicles"|"2 Krønikebok")
      bible_book_name="2 Chronicles"
      bible_book="2CH"
      ;;
    EZR|Ezra|Esra)
      bible_book_name="Ezra"
      bible_book="EZR"
      ;;
    NEH|Nehemiah|Nehemja)
      bible_book_name="Nehemiah"
      bible_book="NEH"
      ;;
    EST|Esther|Ester)
      bible_book_name="Esther"
      bible_book="EST"
      ;;
    JOB|Job)
      bible_book_name="Job"
      bible_book="JOB"
      ;;
    PSA|Psalm|psalms|Salmene)
      bible_book_name="Psalm"
      bible_book="PSA"
      ;;
    PRO|Proverbs|Ordspråkene)
      bible_book_name="Proverbs"
      bible_book="PRO"
      ;;
    ECC|Ecclesiastes|Forkynneren)
      bible_book_name="Ecclesiastes"
      bible_book="ECC"
      ;;
    SNG|"Song of Solomon"|Høysangen)
      bible_book_name="Song of Solomon"
      bible_book="SNG"
      ;;
    ISA|Isaiah|Jesaja)
      bible_book_name="Isaiah"
      bible_book="ISA"
      ;;
    JER|Jeremiah|Jeremia)
      bible_book_name="Jeremiah"
      bible_book="JER"
      ;;
    LAM|Lamentations|Klagesangene)
      bible_book_name="Lamentations"
      bible_book="LAM"
      ;;
    EZK|Ezekiel|Esekiel)
      bible_book_name="Ezekiel"
      bible_book="EZK"
      ;;
    DAN|Daniel)
      bible_book_name="Daniel"
      bible_book="DAN"
      ;;
    HOS|Hosea)
      bible_book_name="Hosea"
      bible_book="HOS"
      ;;
    JOL|Joel)
      bible_book_name="Joel"
      bible_book="JOL"
      ;;
    AMO|Amos)
      bible_book_name="Amos"
      bible_book="AMO"
      ;;
    OBA|Obadiah|Obadja)
      bible_book_name="Obadiah"
      bible_book="OBA"
      ;;
    JON|Jonah|Jona)
      bible_book_name="Jonah"
      bible_book="JON"
      ;;
    MIC|Micah|Mika)
      bible_book_name="Micah"
      bible_book="MIC"
      ;;
    NAM|Nahum)
      bible_book_name="Nahum"
      bible_book="NAM"
      ;;
    HAB|Habakkuk)
      bible_book_name="Habakkuk"
      bible_book="HAB"
      ;;
    ZEP|Zephaniah|Sefanja)
      bible_book_name="Zephaniah"
      bible_book="ZEP"
      ;;
    HAG|Haggai)
      bible_book_name="Haggai"
      bible_book="HAG"
      ;;
    ZEC|Zechariah|Sakarja)
      bible_book_name="Zechariah"
      bible_book="ZEC"
      ;;
    MAL|Malachi|Malaki)
      bible_book_name="Malachi"
      bible_book="MAL"
      ;;
    TOB|Tobit)
      bible_book_name="Tobit"
      bible_book="TOB"
      ;;
    JDT|Judith|Judit)
      bible_book_name="Judith"
      bible_book="JDT"
      ;;
    WIS|Wisdom|"Wisdom of Solomon"|Visdommen)
      bible_book_name="Wisdom of Solomon"
      bible_book="WIS"
      ;;
    BAR|Baruch|Baruk)
      bible_book_name="Baruch"
      bible_book="BAR"
      ;;
    1MA|"1 Maccabees"|1Maccabees|"1 Makkabeerbok"|1Makkabeerbok)
      bible_book_name="1 Maccabees"
      bible_book="1MA"
      ;;
    2MA|"2 Maccabees"|2Maccabees|"2 Makkabeerbok"|2Makkabeerbok)
      bible_book_name="2 Maccabees"
      bible_book="2MA"
      ;;
    BEL|"Bel and the Dragon"|Bel)
      bible_book_name="Bel and the Dragon"
      bible_book="BEL"
      ;;
    MAT|Matthew|Matteus)
      bible_book_name="Matthew"
      bible_book="MAT"
      ;;
    MRK|Mark|Markus)
      bible_book_name="Mark"
      bible_book="MRK"
      ;;
    LUK|Luke|Lukas)
      bible_book_name="Luke"
      bible_book="LUK"
      ;;
    JHN|John|Johannes)
      bible_book_name="John"
      bible_book="JHN"
      ;;
    ACT|Acts|"Apostlenes gjerninger")
      bible_book_name="Acts"
      bible_book="ACT"
      ;;
    ROM|Romans|Romerne)
      bible_book_name="Romans"
      bible_book="ROM"
      ;;
    1CO|"1 Corinthians"|1Corinthians|"1 korinter"|1korinter)
      bible_book_name="1 Corinthians"
      bible_book="1CO"
      ;;
    2CO|"2 Corinthians"|2Corinthians|"2 korinter"|2korinter)
      bible_book_name="2 Corinthians"
      bible_book="2CO"
      ;;
    GAL|Galatians|Galaterne)
      bible_book_name="Galatians"
      bible_book="GAL"
      ;;
    EPH|Ephesians|Efeserne)
      bible_book_name="Ephesians"
      bible_book="EPH"
      ;;
    PHP|Philippians|Filliperne)
      bible_book_name="Philippians"
      bible_book="PHP"
      ;;
    COL|Colossians|Kolosserne)
      bible_book_name="Colossians"
      bible_book="COL"
      ;;
    1TH|"1 Thessalonians"|1Thessalonians|"1 Tessaloniker"|1Tessaloniker)
      bible_book_name="1 Thessalonians"
      bible_book="1TH"
      ;;
    2TH|"2 Thessalonians"|2Thessalonians|"2 Tessaloniker"|2Tessaloniker)
      bible_book_name="2 Thessalonians"
      bible_book="2TH"
      ;;
    1TI|"1 Timothy"|1Timothy|"1 Timoteus"|1Timoteus)
      bible_book_name="1 Timothy"
      bible_book="1TI"
      ;;
    2TI|"2 Timothy"|2Timothy|"2 Timoteus"|2Timoteus)
      bible_book_name="2 Timothy"
      bible_book="2TI"
      ;;
    TIT|Titus)
      bible_book_name="Titus"
      bible_book="TIT"
      ;;
    PHM|Philemon|Filemon)
      bible_book_name="Philemon"
      bible_book="PHM"
      ;;
    HEB|Hebrews|Hebreerne)
      bible_book_name="Hebrews"
      bible_book="HEB"
      ;;
    JAS|James|Jakob)
      bible_book_name="James"
      bible_book="JAS"
      ;;
    1PE|"1 Peter"|1Peter)
      bible_book_name="1 Peter"
      bible_book="1PE"
      ;;
    2PE|"2 Peter"|2Peter)
      bible_book_name="2 Peter"
      bible_book="2PE"
      ;;
    1JN|"1 John"|1John|"1 Johannes"|1Johannes)
      bible_book_name="1 John"
      bible_book="1JN"
      ;;
    2JN|"2 John"|2John|"2 Johannes"|2Johannes)
      bible_book_name="2 John"
      bible_book="2JN"
      ;;
    3JN|"3 John"|3John|"3 Johannes"|3Johannes)
      bible_book_name="3 John"
      bible_book="3JN"
      ;;
    JUD|Jude|Judas)
      bible_book_name="Jude"
      bible_book="JUD"
      ;;
    REV|Revelation|"Johannes åpenbaring")
      bible_book_name="Revelation"
      bible_book="REV"
      ;;
  esac
}

testament() {
  # Echoes ot|nt|apo for the current $bible_book (OSIS), empty if unknown.
  case "$bible_book" in
    GEN|EXO|LEV|NUM|DEU|JOS|JDG|RUT|1SA|2SA|1KI|2KI|1CH|2CH|EZR|NEH|EST|JOB|PSA|PRO|ECC|SNG|ISA|JER|LAM|EZK|DAN|HOS|JOL|AMO|OBA|JON|MIC|NAM|HAB|ZEP|HAG|ZEC|MAL)
      echo ot
      ;;
    MAT|MRK|LUK|JHN|ACT|ROM|1CO|2CO|GAL|EPH|PHP|COL|1TH|2TH|1TI|2TI|TIT|PHM|HEB|JAS|1PE|2PE|1JN|2JN|3JN|JUD|REV)
      echo nt
      ;;
    TOB|JDT|WIS|BAR|1MA|2MA|BEL)
      echo apo
      ;;
  esac
}

args() {
  local words=("$@")
  local i tok cv prev="" bookpart=""
  local ref_idx=-1 vers_idx=0

  book=
  chapter=
  verse=
  verse_range=
  version=
  compare_versions=()

  # The reference token is the one that looks like "N", "N:M" or "N:M1-M2",
  # possibly joined to the book name ("Psalm 23"). Versions never contain
  # digits, so scan from the end and take the last matching token.
  # A chapter and verse may also be given without a colon as two adjacent
  # bare numbers ("Isaiah 54 17").
  for (( i=${#words[@]}-1; i>=0; i-- )); do
    tok="${words[$i]}"
    if [[ "$tok" =~ ^[0-9]+(:[0-9]+(-[0-9]+)?|-[0-9]+)?$ ]]; then
      ref_idx=$i
      cv="$tok"
      bookpart=""
      # Adjacent bare number before it is the chapter, this one the verse
      if (( i > 0 )) && [[ "${words[$((i-1))]}" =~ ^[0-9]+$ ]] \
        && [[ "$cv" != *:* ]]
      then
        prev="${words[$((i-1))]}"
        ref_idx=$((i-1))
      fi
      break
    elif [[ "$tok" =~ ^(.+)\ ([0-9]+)\ ([0-9]+(-[0-9]+)?)$ ]]; then
      # "Book N M" or "Book N M-M" as a single token (no colon)
      ref_idx=$i
      cv="${BASH_REMATCH[3]}"
      prev="${BASH_REMATCH[2]}"
      bookpart="${BASH_REMATCH[1]}"
      break
    elif [[ "$tok" =~ ^(.+)\ ([0-9]+(:[0-9]+(-[0-9]+)?|-[0-9]+)?)$ ]]; then
      ref_idx=$i
      cv="${BASH_REMATCH[2]}"
      bookpart="${BASH_REMATCH[1]}"
      break
    fi
  done

  if (( ref_idx >= 0 )); then
    if (( ref_idx > 0 )); then
      book=$(printf '%s ' "${words[@]:0:ref_idx}")
      book=${book% }
    fi
    book+="$bookpart"
    if [[ "$cv" =~ ^([0-9]+):([0-9]+-[0-9]+)$ ]]; then
      chapter="${BASH_REMATCH[1]}"
      verse="${BASH_REMATCH[2]}"
      verse_range="$verse"
    elif [[ "$cv" =~ ^([0-9]+):([0-9]+)$ ]]; then
      chapter="${BASH_REMATCH[1]}"
      verse="${BASH_REMATCH[2]}"
    elif [[ -n "$prev" ]]; then
      chapter="$prev"
      verse="$cv"
      if [[ "$verse" =~ ^[0-9]+-[0-9]+$ ]]; then
        verse_range="$verse"
      fi
    elif [[ "$cv" == *-* ]]; then
      chapter="${cv%-*}"
      verse="${cv#*-}"
      verse_range="$verse"
    else
      chapter="$cv"
    fi
    # The reference may span two tokens (chapter + verse); versions follow
    if (( ref_idx == i - 1 )); then
      vers_idx=$((i + 1))
    else
      vers_idx=$((ref_idx + 1))
    fi
    if (( vers_idx < ${#words[@]} )); then
      words=("${words[@]:vers_idx}")
    else
      words=()
    fi
  else
    if [[ ${#words[@]} -gt 0 ]]; then
      book=$(printf '%s ' "${words[@]}")
      book=${book% }
    fi
    words=()
  fi

  # Normalize a no-space book number ("2Timoteus" -> "2 Timoteus") so that
  # book_case only ever needs the spaced form
  if [[ "$book" =~ ^([0-9]+)([A-Za-z].*)$ ]]; then
    book="${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
  fi

  # Remaining args are the version(s), or a language shortcut (no/en)
  if [[ ${#words[@]} -gt 0 ]]; then
    if [[ ${#words[@]} -eq 1 ]]; then
      if [[ "${words[0]}" == "no" ]]; then
        version="no"
        compare_versions=("${compare_versions_no[@]}")
        return
      elif [[ "${words[0]}" == "en" ]]; then
        version="en"
        compare_versions=("${compare_versions_en[@]}")
        return
      fi
    fi
    version="${words[0]}"
    compare_versions=("${words[@]}")
  fi

  # Default to KJV when no version was given
  if [[ -z "$version" ]]; then
    version="KJV"
  fi
}

get_bible_chapter() {
  # tmpfile — chapter pages server-render every verse as
  # <span data-usfm="BOOK.CH.VERSE">, so one fetch serves single
  # verses, ranges and (for the coming frontend) whole chapters.
  tmp=$(mktemp)
  tmp_files+=("$tmp")
  # Grab chapter and store in tmp file
  curl -s \
    --compressed \
    -H 'Accept: */*' \
    -H "Cookie: version=$num" \
    -H 'Pragma: no-cache' \
    -H 'Cache-Control: no-cache' \
    "https://www.bible.com/bible/$num/$1.$2.$3" > "$tmp"
  if [[ ! -s "$tmp" ]]; then
    echo "No result."
    echo
    exit 0
  fi
}

verse_text() {
  # $1 = chapter html file, $2 = USFM (e.g. ISA.54.17).
  # First occurrence wins: later duplicates live in footer/share cards.
  # The file is folded to one line first because verse tags wrap
  # their attributes across newlines. Verse text is harvested from
  # __content spans (this skips verse-number labels, footnote
  # callers like "#", cross-ref notes and poetry wrappers, whose
  # text all lives outside __content).
  # The verse chunk ends at the next verse span or at the closing
  # chapter divs (never at EOF: flight-data JSON would be swallowed;
  # never at a bare data-usfm=: cross-ref notes carry those too).
  tr '\n' ' ' < "$1" \
    | grep -Po "data-usfm=\"$2\">.*?(?=<span class=\"[^\"]*__verse\" data-usfm=\"|</div>|<script)" | head -n 1 \
    | grep -Po '<span class="[^"]*__content">\K.*?(?=</span>)' \
    | tr '\n' ' ' \
    | sed 's|<[^>]*>||g' \
    | sed -e "s/&#x27;/'/g" -e 's/&#39;/'\''/g' -e 's/&quot;/"/g' \
      -e 's/&lt;/</g' -e 's/&gt;/>/g' -e 's/&nbsp;/ /g' -e 's/&amp;/\&/g' \
    | tr -s ' ' \
    | sed 's/^ //; s/ $//' || true
}

chapter_usfms() {
  # $1 = chapter html file, $2 = "BOOK.CH" — ordered unique verse
  # USFMs of the chapter (for whole-chapter views in the frontend).
  sed 's|data-usfm="|\ndata-usfm="|g' "$1" \
    | grep -o "data-usfm=\"$2\.[0-9]*\"" \
    | sed 's/data-usfm="//; s/"//' \
    | awk '!seen[$0]++' || true
}

chapter_text() {
  # $1 = chapter html file, $2 = "BOOK.CH" — prints "N text" per verse.
  local usfm vnum vtext
  while IFS= read -r usfm; do
    vnum="${usfm##*.}"
    vtext=$(verse_text "$1" "$usfm")
    if [[ -n "$vtext" ]]; then
      printf "\n${BOLD}%s${NC} %s\n" "$vnum" "$(echo "$vtext" | fold -w ${width} -s)"
    fi
  done < <(chapter_usfms "$1" "$2")
}

output_correction() {
  # Strip unwanted symbol from version
  if [[ $version == "N78BM" ]]
  then
    description=${description//¬/}
  fi
  description=${description// ./.}
  description=${description// ,/,}
  description=${description// ;/;}
  description=${description//&#x27;/\'}
  description=${description//– /}
  chapter_verse=${chapter_verse//&#x27;/\'}
  if [ -z "$description" ]; then
    if [[ -n "${BIBLE_PLAIN:-}" ]]; then
      # Translators must not receive the error message.
      echo "No result." >&2
      echo >&2
      return 1
    fi
    echo "No result."
    echo
    exit 0
  fi
}

output() {
  if [[ -n "${BIBLE_PLAIN:-}" ]]; then
    # Pure verse text on stdout (for piping into translators);
    # nothing else, so the MT engine sees clean source. Unfolded:
    # trans translates line-by-line, wrapped fragments mistranslate.
    echo "$1"
    return
  fi
  # Fold description to set width
  description=$(echo "$1" | fold -w ${width} -s)
  printf "\n"
  echo -n "${BQUOTE}$description${EQUOTE}"
  echo ""
  echo ""
  echo -n "${GREEN}$2 $3${NC} - ${YELLOW}($4)${NC}"
  echo ""
  echo -n "${BLUE}$5${NC}"
  printf "\n"
  printf "\n"
}

bible() {
  args "$@"
  book_case

  version_case

  if [ -n "$verse_range" ]
  then
    verse="$verse_range"
  else
    if [[ "$chapter" =~ ^[[:digit:]]+$ ]] && [[ ! "$verse" =~ ^[[:digit:]]+$ ]]
    then
      echo "Please enter verse number"
      exit 0
    fi
  fi

  if [[ -z $book ]]
  then
    echo "Please enter a valid book name"
  fi

  if [[ -z $num ]]
  then
    echo "Please enter a valid version"
    exit 0
  fi

  # Offline-first: use the local database when the requested version
  # is installed locally (and thus not an original-language version).
  # Set BIBLE_ONLINE_ONLY=1 to force bible.com lookups regardless.
  if [[ -z "${BIBLE_ONLINE_ONLY:-}" ]] \
    && [[ "$version" == "KJV" ]] \
    && [[ -n "$bible_book" ]] && [[ -n "$chapter" ]] \
    && _offline_is_installed "KJV"; then

    if [ -n "$verse_range" ]; then
      description=$(local_range_text "$bible_book" "$chapter" "$verse_range" "KJV")
      chapter_verse="$chapter:$verse_range"
    elif [[ "$verse" =~ ^[[:digit:]]+$ ]]; then
      description=$(local_verse "$bible_book" "$chapter" "$verse" "KJV")
      chapter_verse="$chapter:$verse"
    else
      description=""
    fi

    if [[ -n "$description" ]]; then
      page_h1="${bible_book_name}"
      book="$bible_book_name"
      link="https://www.bible.com/bible/$num/$bible_book.$chapter.$verse.$version"

      # Strip unwanted symbol from version
      if [[ $version == "N78BM" ]]
      then
        description=${description//¬/}
      fi

      # Strip quotes from description if any
      if [[ $description =~ $BQUOTE ]] ||
      [[ $description =~ $EQUOTE ]]
      then
        BQUOTE=''
        EQUOTE=''
      fi

      # Fold description to set width
      description_folded=$(echo "$description" | fold -w ${width} -s)

      output "$description_folded" "$book" "$chapter_verse" "$version" "$link"
      return 0
    fi
    # Fall through to online if the local DB has no such verse
  fi

  # API-first: when an app key is set and the requested version is
  # licensed to it, read via the official Platform API (clean text,
  # no scraping). Falls back to the chapter-page path below on any
  # failure — that path stays byte-for-byte untouched as the default.
  if [[ -z "${BIBLE_ONLINE_ONLY:-}" ]]; then
    local api_id api_usfm api_desc
    if api_id=$(_yvp_bible_id "$num" "$lang" 2>/dev/null) && [[ -n "$api_id" ]]; then
      if [[ -n "$verse_range" ]]; then
        api_usfm="$bible_book.$chapter.$verse_range"
      elif [[ "$verse" =~ ^[[:digit:]]+$ ]]; then
        api_usfm="$bible_book.$chapter.$verse"
      else
        api_usfm="$bible_book.$chapter"
      fi
      if api_desc=$(_yvp_passage_text "$api_id" "$api_usfm" 2>/dev/null) && [[ -n "$api_desc" ]]; then
        description="$api_desc"
        book="$bible_book_name"
        chapter_verse="$chapter"
        if [[ -n "$verse_range" ]]; then
          chapter_verse+=":$verse_range"
        else
          chapter_verse+=":$verse"
        fi
        link="https://www.bible.com/bible/$num/$bible_book.$chapter.$verse.$version"
        # Mirrors the scraping tail: drop the quote wrappers when the
        # passage text already carries curly quotes (AMP et al.).
        if [[ $description =~ $BQUOTE ]] || [[ $description =~ $EQUOTE ]]; then
          BQUOTE=''
          EQUOTE=''
        fi
        output_correction
        output "$description" "$book" "$chapter_verse" "$version" "$link"
        return 0
      fi
    fi
  fi

  get_bible_chapter "$bible_book" "$chapter" "$version"

  # Chapter pages server-render every verse as <span data-usfm>.
  # First span occurrence wins (later ones are footer/share cards).
  if [ -n "$verse_range" ]
  then
    range_start="${verse_range%-*}"
    range_end="${verse_range#*-}"
    description=""
    for (( v=range_start; v<=range_end; v++ )); do
      verse_line=$(verse_text "$tmp" "$bible_book.$chapter.$v")
      if [[ -n "$verse_line" ]]; then
        description+="${description:+ }$verse_line"
      fi
    done
    chapter_verse="$chapter:$verse_range"
  else
    description=$(verse_text "$tmp" "$bible_book.$chapter.$verse")
    chapter_verse="$chapter:$verse"
  fi

  # Localized book name from the page heading ("Jesaja 54").
  # Fall back to the canonical English name; the requested version
  # is already canonical, so no page re-parse needed for it.
  page_h1=$(grep -Po '<h1[^>]*>\K.*?(?=</h1>)' "$tmp" | head -n 1 || true)
  if [[ -n "$page_h1" ]]; then
    book="${page_h1% *}"
  else
    book="$bible_book_name"
  fi

  link="https://www.bible.com/bible/$num/$bible_book.$chapter.$verse.$version"

  # Strip unwanted symbol from version
  if [[ $version == "N78BM" ]]
  then
    description=${description//¬/}
  fi

  # Strip quotes from description if any
  if [[ $description =~ $BQUOTE ]] ||
  [[ $description =~ $EQUOTE ]]
  then
    BQUOTE=''
    EQUOTE=''
  fi

  if [[ -z $description ]]
  then
    description=$(
      if [ $lang = "en" ]; then
        echo "This verse has been omitted from this Bible version ${YELLOW}($version)${NC},"
        echo "or a number out of range has been entered."
      elif [ $lang = "no" ]; then
        echo "Dette verset er utelatt fra denne bibelversjonen ${YELLOW}($version)${NC},"
        echo "eller et tall utenfor rekkevidden er tastet inn."
      fi
    )
  fi

  # Fold description to set width
  description_folded=$(echo "$description" | fold -w ${width} -s)

  if [[ $description =~ "omitted"|"utelatt" ]]
  then
    if [[ -n "${BIBLE_PLAIN:-}" ]]; then
      # Translators must not receive the error message: stderr only,
      # empty stdout, nonzero return.
      printf "\n%s\n\n" "$description_folded" >&2
      return 1
    fi
    printf "\n"
    echo -n "${BQUOTE}$description_folded${EQUOTE}"
    printf "\n"
    printf "\n"
  else
    # Display output
    output_correction
    if [[ -z "$description" ]]; then
      return 1 # PLAIN no-result already reported on stderr
    fi
    output "$description" "$book" "$chapter_verse" "$version" "$link"
  fi
}

audio_seek() {
  # $1=web version num, $2=USFM ref "GEN.1", $3=verse or "V1-V2",
  # $4=CDN mp3 filename (optional, to pick the matching narrator)
  # Echoes "<start> <end>" seconds into the chapter mp3, or nothing.
  local num="$1" ref="$2" sel="$3" fname="$4"
  local v1="${sel%-*}" v2="${sel#*-}" timing st en
  timing=$(curl -s "http://audio-bible.youversionapi.com/3.1/chapter.json?version_id=$num&reference=$ref")
  [[ -n "$timing" ]] || return 1
  if [[ -n "$fname" ]]; then
    st=$(jq -r --arg f "$fname" --arg u "$ref.$v1" '
      .response.data[]? as $d |
      select(($d.download_urls.format_mp3_32k // "") | contains($f)) |
      $d.timing[]? | select(.usfm == $u) | .start' <<<"$timing" | head -n 1)
    en=$(jq -r --arg f "$fname" --arg u "$ref.$v2" '
      .response.data[]? as $d |
      select(($d.download_urls.format_mp3_32k // "") | contains($f)) |
      $d.timing[]? | select(.usfm == $u) | .end' <<<"$timing" | head -n 1)
  fi
  if [[ -z "$st" ]]; then
    st=$(jq -r --arg u "$ref.$v1" \
      '.response.data[0].timing[]? | select(.usfm == $u) | .start' <<<"$timing" | head -n 1)
  fi
  if [[ -z "$en" ]]; then
    en=$(jq -r --arg u "$ref.$v2" \
      '.response.data[0].timing[]? | select(.usfm == $u) | .end' <<<"$timing" | head -n 1)
  fi
  if [[ -n "$st" && -n "$en" ]]; then
    echo "$st $en"
  fi
}

listen() {
  local num= seek_start= seek_end=
  listen_mp3_tmp=$(mktemp)
  tmp_files+=("$listen_mp3_tmp")
  args "$@"
  version_case
  book_case

  listen_mp3_url=$(
    curl --silent https://www.bible.com/audio-bible/"$num"/"$bible_book"."$chapter"."$version" > "$listen_mp3_tmp"
    grep -Po "https.*?(?=\")" "$listen_mp3_tmp" |
    grep -i audio-bible-cdn |
    head -n 1
  )

  if [ -z "$listen_mp3_url" ]; then
    echo "No audio found for $bible_book_name $chapter $version"
    exit 0
  fi

  listen_mp3_headline=$(
    grep -Po "headline\":\".*?(?=\")" "$listen_mp3_tmp" |
    sed "s|headline\":\"||g" |
    head -n 1
  )

  listen_mp3_transcript=$(
    grep -Po "transcript\":\".*?(?=\")" "$listen_mp3_tmp" |
    sed "s|transcript\":\"||g" |
    sed "s|\\\\n|\n|g"
  )

  listen_mp3_link=$(
    grep -Po '{"@id":"\K(.*?)","@type":"WebPage"}' "$listen_mp3_tmp" |
      sed 's|","@type":"WebPage"}||g'
  )

  listen_mp3_filename=$(
    echo "$listen_mp3_url" |
    awk -F '/' '{print $7}' |
    sed "s|?version_id=[0-9]*||g"
  )

  if [[ -n $(command -v 'vlc') ]]
  then
    player=(vlc --play-and-exit)
  elif [[ -n $(command -v 'ffplay') ]]
  then
    player=(ffplay -autoexit -nodisp -loglevel quiet)
  else
    echo "vlc or ffplay not installed..."
    exit 0
  fi

  # Verse-seek: when a verse (or range) is requested, play only that
  # span of the chapter mp3 using the YouVersion audio timing API.
  if [[ -n "$verse" ]]; then
    read -r seek_start seek_end <<< "$(audio_seek "$num" "$bible_book.$chapter" "$verse" "$listen_mp3_filename")"
    if [[ -n "$seek_start" ]]; then
      if [[ "${player[0]}" == vlc ]]; then
        player+=(--start-time="$seek_start" --stop-time="$seek_end")
      else
        player+=(-ss "$seek_start" -t "$(awk "BEGIN{printf \"%.2f\", $seek_end - $seek_start}")")
      fi
    fi
  fi

  chapter_pad=$(printf '%02d' "$chapter")
  if ! [ -d "$audio_folder"/"$version"/"$bible_book_name" ]; then
    mkdir -p "$audio_folder"/"$version"/"$bible_book_name"
  fi
  cd "$audio_folder/$version/$bible_book_name"
  mp3=""
  for cached in "$audio_folder/$version/$bible_book_name/"*"$bible_book_name""$chapter_pad"_"$version".mp3; do
    if [ -f "$cached" ]; then
      mp3="$cached"
      break
    fi
  done
  if [ -z "$mp3" ]; then
    tmp_mp3="$audio_folder/$version/$bible_book_name/$listen_mp3_filename"
    curl -s -o "$tmp_mp3" "$listen_mp3_url"
    mp3_title=$(ffmpeg -i "$tmp_mp3" 2>&1 | grep -Po "title\K.*" | tr -d ': ')
    if [ -n "$mp3_title" ]; then
      mp3="$audio_folder"/"$version"/"$bible_book_name"/"$mp3_title".mp3
    else
      mp3="$audio_folder"/"$version"/"$bible_book_name"/"$bible_book_name""$chapter_pad"_"$version".mp3
    fi
    if ! [ -f "$mp3" ]; then
      mv "$tmp_mp3" "$mp3"
    else
      rm "$tmp_mp3"
    fi
  fi
  cd - >/dev/null 2>&1
  "${player[@]}" "$mp3" >/dev/null 2>&1 &
  rm "$listen_mp3_tmp"

  printf "\n"
  echo -n "$listen_mp3_headline"
  printf "\n"
  printf "\n"
  # Numbered verses via the local database when available; otherwise
  # via the chapter text page, falling back to the raw transcript
  # (which has no verse numbers).  When a verse (or range) was given,
  # only the selected verses are shown.
  local local_usfms vstart vend v vtext
  local_usfms=$(local_chapter_verses "$bible_book" "$chapter" "$version" 2>/dev/null)
  if [[ -n "$local_usfms" ]]; then
    if [[ -n "$verse" ]]; then
      vstart="${verse%-*}"
      vend="${verse#*-}"
      for (( v=vstart; v<=vend; v++ )); do
        vtext=$(local_verse "$bible_book" "$chapter" "$v" "$version")
        [[ -n "$vtext" ]] && printf "\n${BOLD}%s${NC} %s\n" "$v" "$(echo "$vtext" | fold -w ${width} -s)"
      done
    else
      local_chapter_text "$bible_book" "$chapter" "$version"
    fi
  else
    listen_text_tmp=$(mktemp)
    tmp_files+=("$listen_text_tmp")
    if curl -s \
      --compressed \
      -H 'Accept: */*' \
      -H "Cookie: version=$num" \
      -H 'Pragma: no-cache' \
      -H 'Cache-Control: no-cache' \
      "https://www.bible.com/bible/$num/$bible_book.$chapter.$version" > "$listen_text_tmp" 2>/dev/null \
      && [[ -n "$(chapter_usfms "$listen_text_tmp" "$bible_book.$chapter")" ]]; then
      if [[ -n "$verse" ]]; then
        vstart="${verse%-*}"
        vend="${verse#*-}"
        for (( v=vstart; v<=vend; v++ )); do
          vtext=$(verse_text "$listen_text_tmp" "$bible_book.$chapter.$v")
          [[ -n "$vtext" ]] && printf "\n${BOLD}%s${NC} %s\n" "$v" "$(echo "$vtext" | fold -w ${width} -s)"
        done
      else
        chapter_text "$listen_text_tmp" "$bible_book.$chapter"
      fi
    else
      echo "$listen_mp3_transcript" | fold -w ${width} -s
    fi
  fi
  printf "\n"
  printf "\n"
  echo "$listen_mp3_link"
  printf "\n"
}

votd() {
  if [[ "${2:-}" =~ ^[[:digit:]]+$ ]]
  then
    doy=$2
  else
    # Source - https://stackoverflow.com/a/10112611
    # Posted by Peter.O, modified by community. See post 'Timeline' for change history
    # Retrieved 2026-08-23, License - CC BY-SA 3.0
    doy=$(date +%j)
    doy=$(($doy + 1))
  fi
  version=${1:-}
  lang=en
  # Set default version to KJV (1) before resolving the version id
  if [ -z "$version" ]; then
    version="KJV"
  fi
  votd_tmp=$(mktemp)
  tmp_files+=("$votd_tmp")
  version_case
  # Set votd url
  votd_json_url="https://www.bible.com/api/bible/verse-of-the-day?day=$doy&locale=$lang&versionId=$num"
  # Send request
  curl -s "$votd_json_url" > "$votd_tmp" 2>/dev/null
  if [[ ! $(command -v 'jq') ]]; then
    echo "jq not installed..."
    exit 0
  fi
  # Parse the VOTD response (bible.com sends it in .response.data.arrayOfVerses)
  votd_content=$(jq -r '.response.data.arrayOfVerses[0].verses[0].content // empty' "$votd_tmp" | tr '\n' ' ')
  votd_title=$(jq -r '.response.data.arrayOfVerses[0].verses[0].reference.human // empty' "$votd_tmp")
  votd_version=$(jq -r '.response.data.arrayOfVerses[0].local_abbreviation // empty' "$votd_tmp")
  votd_url=$(jq -r '.response.data.arrayOfVerses[0].canonicalUrl // empty' "$votd_tmp")
  votd_img=$(jq -r '.response.data.arrayOfVerses[0].images.images[0].renditions | max_by(.width) | .url // empty' "$votd_tmp" | grep -oP 'https:.*')
  if [[ -z "$votd_content" || -z "$votd_title" ]]; then
    echo "No verse of the day available."
    exit 0
  fi
  # Set image tmp file
  votd_img_tmp=$(mktemp)
  tmp_files+=("$votd_img_tmp")

  # VOTD_TEXT=1 (used by the bible frontend home screen): text only,
  # skip the image download entirely.
  if [[ -z "${VOTD_TEXT:-}" && -n "$votd_img" ]]; then
    if [[ $(command -v 'curl') ]]; then
      curl -fsSLk "$votd_img" > "$votd_img_tmp"
    elif [[ $(command -v 'wget') ]]; then
      wget -q "$votd_img" -O "$votd_img_tmp"
    else
      echo -e "${RED}${ERROR} This script requires curl or wget.\nProcess aborted${NC}"
      exit 0
    fi
  fi
  # Display output
  if [ $lang = "en" ]; then
    echo -e "${BLUE}${BOLD}Verse of the Day${NC} ${CROSS}"
    echo -e "${DIM}A daily word of exultation.${NC}"
  elif [ $lang = "no" ]; then
    echo -e "${BLUE}${BOLD}Dagens vers${NC} ${CROSS}"
    echo -e "${DIM}Et daglig ord med storlig glede.${NC}"
  fi
  echo
  if [[ -z "${VOTD_TEXT:-}" && -n "$votd_img" ]]
  then
    if [[ $(command -v 'convert') ]]
    then
      convert "$votd_img_tmp" -scale 320 six:-
    else
      echo -e "${GREEN}"
      echo '  _    ______  __________  '
      echo ' | |  / / __ \/_  __/ __ \ '
      echo ' | | / / / / / / / / / / / '
      echo ' | |/ / /_/ / / / / /_/ /  '
      echo ' |___/\____/ /_/ /_____/   '
      echo -e "${NC}"
    fi
    echo
  fi
  book=$(echo "$votd_title" | grep -Po '.* [0-9]+' | sed 's| [0-9].*||g')
  chapter_verse=$(echo "$votd_title" | grep -Po ' [0-9].*' | sed 's| ||g')
  description=$votd_content
  version=$votd_version
  link=https://www.bible.com$votd_url
  # Display output
  output_correction
  output "$description" "$book" "$chapter_verse" "$version" "$link"
  # Send desktop notification (skipped for text-only home use)
  if [[ -z "${VOTD_TEXT:-}" ]] && [[ $(command -v 'notify-send') ]]
  then
    message=$(
      # Disable colors
      GREEN=''
      YELLOW=''
      BLUE=''
      BOLD=""
      DIM=""
      NC=''
      output_correction
    output "$description" "$book" "$chapter_verse" "$votd_version" "$link")
    # Send notification to desktop
    notify-send \
      --hint=string:sound-name:dialog-information \
      --app-name="Verse of the Day" \
      --app-icon="dialog-information-symbolic" \
      --icon="$votd_img_tmp" \
      "Verse of the Day" \
      "$message"
    rm "$votd_img_tmp"
  fi
}

search() {
  num=
  query=${1:-}
  version=${2:-}

  # Default to KJV when no version was given (mirrors args()).
  if [[ -z "$version" ]]; then
    version="KJV"
  fi
  version_case

  if [ -z "$version" ]; then
    num=1
  fi

  # Offline-first: search the local database when the requested
  # version is installed locally.
  if [[ "$version" == "KJV" ]] && _offline_is_installed "KJV"; then
    if local_search "$query" "$version"; then
      return 0
    fi
  fi

  # API-first search: when an app key is set and the requested
  # version is licensed to it, search the official Platform API and
  # render each matched reference. Falls back to the bible.com
  # scraping search below on any failure.
  local api_id api_ref api_desc api_book api_cv api_link
  if api_id=$(_yvp_bible_id "$num" "$lang" 2>/dev/null) && [[ -n "$api_id" ]]; then
    echo ""
    echo "Search results from YouVersion Platform API"
    echo ""
    divider_line
    while IFS= read -r api_ref; do
      [[ -z "$api_ref" ]] && continue
      api_desc=$(_yvp_passage_text "$api_id" "$api_ref" 2>/dev/null)
      [[ -n "$api_desc" ]] || continue
      api_book=$(_yvp_book_name "${api_ref%%.*}")
      api_cv="${api_ref#*.}"
      api_cv="${api_cv%%.*}:${api_cv##*.}"
      api_link="https://www.bible.com/bible/$num/$api_ref.$version"
      description="$api_desc"
      book="$api_book"
      chapter_verse="$api_cv"
      version="$version"
      link="$api_link"
      if [[ $description =~ $BQUOTE ]] || [[ $description =~ $EQUOTE ]]; then
        BQUOTE=''
        EQUOTE=''
      fi
      output_correction
      output "$description" "$book" "$chapter_verse" "$version" "$link"
      divider_line
      sleep 0.1
    done < <(_yvp_search "$api_id" "$query" 3)
    return 0
  fi

  get_url_id=$(
    curl -s "https://www.bible.com/search/bible?query=test" |
    grep -Po "<script src=\"/_next/static/chunks/.*?(?>\")" |
    tail -n 1 |
    sed "s|<script src=\"/_next/static/chunks/||g" |
    sed "s|/*.js\"||g"
  )
  # Source: https://linuxopsys.com/read-json-file-in-shell-script
  bible_search_tmp=$(mktemp)
  tmp_files+=("$bible_search_tmp")
  bible_search_tmp2=$(mktemp)
  tmp_files+=("$bible_search_tmp2")
  # URL-encode the search query by replacing spaces with + signs
  if [[ "$query" == *" "* ]]; then
    query=${query// /+}
  fi

  curl -s \
    --compressed \
    -H 'Accept: */*' \
    -H "Cookie: version=$num" \
    -H 'Pragma: no-cache' \
    -H 'Cache-Control: no-cache' \
    "https://www.bible.com/search/bible?query=$query&_rsc=$get_url_id" > "$bible_search_tmp"
  echo ""
  echo "Search results from bible.com"
  echo ""
  divider_line
  # echo "-----------------------------------------------------------------------------"
  # json verses content human version_local_abbreviation "$bible_search_tmp" |
  grep -Po "<div class=\"flex rounded-0.5 border-small border-gray-10 p-2 dark:border-gray-40\">\K(.*?)</div>" "$bible_search_tmp" > "$bible_search_tmp2"
  while IFS= read -r search_results; do
    description=$(
      echo "$search_results" \
        | grep -Po "mbe-1\">\K(.*?)</p>" | sed "s|</p>||g" \
        | fold -w ${width} -s
    )
    chapter_verse=$(
      echo "$search_results" \
        | grep -Po "\">\K(.*?)<\!--" | grep -Po "\">\K(.*?)<\!--" | grep -Po "\">\K(.*?)<\!--" | sed "s|<\!--||g"
    )
    version=$(
      echo "$search_results" \
        | grep -Po "\(<\!-- -->\K(.*?)<\!-- -->\)" | sed "s|<\!-- -->)||g"
    )
    link=$(
      echo "$search_results" \
        | grep -Po "href=\"\K(.*?)\">" | sed "s|\">||g"
    )
    book=$(
      echo "$chapter_verse" | grep -Po '.* [0-9]+' | sed 's| [0-9].*||g'
    )
    chapter_verse=$(
      echo "$chapter_verse" | grep -Po ' [0-9].*' | sed 's| ||g'
    )
    link="https://www.bible.com$link"
    # Display output
    output_correction
    output "$description" "$book" "$chapter_verse" "$version" "$link"
    divider_line
    # Delete tmp file
    rm "$bible_search_tmp" 2>/dev/null
    sleep 0.1
  done < "$bible_search_tmp2"
  rm "$bible_search_tmp2" 2>/dev/null
}

compare() {
  args "$@"
  local ref="$chapter"
  if [[ -n "$verse" ]]; then
    ref+=":$verse"
  fi
  for i in "${compare_versions[@]}"
  do
    printf '\n'
    bible "$book" "$ref" "$i"
    printf '\n'
    divider_line
    sleep 0.3
  done
}

translate() {
  # Usage: translate REF... SRC TGT [ENGINE] [brief|full]
  # ENGINE is google (default) or bing; also via TRANS_ENGINE env.
  # Brief output is the default; full restores trans' verbose
  # dictionaries (also via TRANS_VERBOSE=1).
  local lang_arg='' target_arg='' engine="${TRANS_ENGINE:-google}" verbose=false
  local ref_display='' trans_out=''
  local -a trans_args=()
  local n=$#
  local target_idx=$n lang_idx=$((n - 1))
  local last=""
  if (( n >= 1 )); then
    last="${*:$n:1}"
  fi
  if [[ "$last" == "brief" || "$last" == "full" ]] && (( n >= 4 )); then
    [[ "$last" == "full" ]] && verbose=true
    ((n--))
    target_idx=$n
    lang_idx=$((n - 1))
    last="${*:$n:1}"
  fi
  if [[ "$last" == "google" || "$last" == "bing" ]] && (( n >= 4 )); then
    engine="$last"
    target_idx=$((n - 1))
    lang_idx=$((n - 2))
  fi
  if [[ -n "${TRANS_VERBOSE:-}" ]]; then
    verbose=true
  fi
  if (( target_idx >= 2 )); then
    target_arg="${*:target_idx:1}"
  fi
  if (( lang_idx >= 3 )); then
    lang_arg="${*:lang_idx:1}"
  fi
  if [[ "$lang_arg" == "auto" || -z "$lang_arg" ]]; then
    # Resolve the source testament from the reference itself:
    # Hebrew (OT) or Greek (NT). Needs book parsing first; bible()
    # re-parses anyway, so no state leaks from here.
    bible_book=""
    if (( target_idx - 2 >= 1 )); then
      args "${@:1:target_idx-2}"
      book_case
    fi
    case "$(testament)" in
      ot) lang_arg=hebrew ;;
      nt) lang_arg=greek ;;
    esac
  fi
  if [[ "$lang_arg" == "hebrew" ]]; then
    version="תנ\"ך"
  elif [[ "$lang_arg" == "greek" ]]; then
    version="TR1624"
  elif [[ -n "$lang_arg" ]]; then
    version="$lang_arg"
  fi
  if [[ $(command -v 'trans') ]]
  then
    ref_display="${*:1:target_idx-2}"
    printf '\nTranslating %s (%s) -> %s [%s]\n' \
      "$ref_display" "$version" "$target_arg" "$engine" >&2
    trans_args=(-no-ansi -e "$engine" :"$target_arg")
    if [[ "$verbose" != true ]]; then
      trans_args=(-no-ansi -b -e "$engine" :"$target_arg")
    fi
    trans_out=$(BIBLE_PLAIN=1 bible "${@:1:target_idx-2}" "$version" | trans "${trans_args[@]}") || true
    if grep -qiE '\[ERROR\]|Something went wrong|Potential Security Risk|Translator not found' <<<"$trans_out"; then
      # Transient engine failure (TLS/rate-limit): try the other one.
      if [[ "$engine" == "google" ]]; then
        engine="bing"
      else
        engine="google"
      fi
      printf 'Engine failed, retrying with %s...\n\n' "$engine" >&2
      trans_args=(-no-ansi -b -e "$engine" :"$target_arg")
      if [[ "$verbose" == true ]]; then
        trans_args=(-no-ansi -e "$engine" :"$target_arg")
      fi
      trans_out=$(BIBLE_PLAIN=1 bible "${@:1:target_idx-2}" "$version" | trans "${trans_args[@]}") || true
    fi
    if [[ -n "$trans_out" ]]; then
      # Original above, translation below: two fetches, zero
      # refactoring risk. Colors follow the terminal; the
      # translation itself stays color-free (-no-ansi).
      bible "${@:1:target_idx-2}" "$version"
      printf '%s\n' "$trans_out"
    fi
  else
    echo "translate-shell is not installed..."
    echo "install with apt install translate-shell"
  fi
}

usage() {
  cat <<EOF
bible.sh — the whole Bible in one shell file.

  Run with no arguments for the interactive app: Read (Continue,
  proverb-a-day, reading plans, the Lord's prayer), Listen (its audio
  mirror), Search, Compare, Verse of the Day, Translate, Version,
  Offline and Help. Arrow keys →/← work like [n]ext/[p]rev in every
  chapter loop; Enter resumes Continue; update hints show in the header.

  Arguments            Example usage
  --help      | -h     Show this help.
  --bible     | -b     bible -b Isaiah 54:17 KJV
  --search    | -s     bible -s "keyword" KJV
  --votd      | -v     bible -v
  proverb              bible proverb
                       Read today's chapter of Proverbs (31 chapters,
                       one per day; menu: Read → "A proverb a day").
  --listen    | -l     bible -l Isaiah 54 KJV
  --compare   | -c     bible -c Isaiah 54:17 KJV NIV NLT NKJV ESV
                       or bible -c Isaiah 54:17 [en|no]
  --saved     | -a     bible saved
                       Interactive "Are You Saved?" gospel walkthrough —
                       self-directed, following the questioning method
                       of Ray Comfort (Living Waters, Way of the Master).
  --translate | -t     bible -t Matthew 17:21 greek en [google|bing] [brief|full]
                       or bible -t Isaiah 54:17 hebrew en
                       or bible -t John 3:16 auto no
                       auto source = hebrew (OT) / greek (NT; TR1624,
                       NT only); engine default google, else bing
                       (TRANS_ENGINE works too); brief clean color-free
                       output by default, full restores dictionaries.
  install              bible install [VERSION] [--all]
                       Download a version for offline use (KJV is the
                       only offline version).
  update               bible update [VERSION] [--all]
                       Refresh a locally installed version.
  status               bible status
                       Show locally installed versions.
  hl | highlights      bible hl list | add ... | delete ... | login
                       Manage YouVersion highlights (OAuth).
  self-update | -u     bible self-update
                       Update this script from the GitHub repo: compares
                       the VERSION header, syntax-checks the download,
                       then swaps it in atomically. SELF_UPDATE_YES=1
                       skips the prompt; launch checks are cached for
                       SELF_UPDATE_TTL seconds (default 6h).
  --no-update-check    Launch without checking for updates
                       (BIBLE_NO_UPDATE_CHECK=1 does the same).
EOF
}


# -- Self-update (portable: copy this block into any bash script) -----------------
# Overridable via env: SELF_UPDATE_URL (raw URL of the file to pull), SELF_UPDATE_YES=1
# Launch-time check: BIBLE_NO_UPDATE_CHECK=1 (or --no-update-check) disables it.
_SELF_UPDATE_URL="${SELF_UPDATE_URL:-https://raw.githubusercontent.com/tmiland/bible.sh/main/bible.sh}"
_SU_AVAILABLE=""
_SU_LOCAL=""

_su_download() { # $1=url  $2=outfile
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --connect-timeout 10 "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -T 10 "$1" -O "$2"
  else
    printf 'self-update: need curl or wget\n' >&2
    return 1
  fi
}

_su_version() { # $1=file  -> prints x.y.z from a VERSION='x.y.z' / VERSION="x.y.z" line
  grep -oE "VERSION=['\"][0-9]+\.[0-9]+[0-9.]*['\"]" "$1" | head -1 | tr -dc '0-9.'
}

self_update() {
  local self url tmp rver lver ans
  self="$(readlink -f "${BASH_SOURCE[0]}")"
  if [[ ! -f "$self" ]]; then
    printf "self-update: cannot resolve this script's own path\n" >&2
    return 1
  fi
  if [[ ! -w "$self" ]]; then
    printf "self-update: '%s' is not writable. Run:\n  curl -fsSL '%s' -o '%s' && chmod +x '%s'\n" "$self" "$_SELF_UPDATE_URL" "$self" "$self" >&2
    return 1
  fi
  url="${SELF_UPDATE_URL:-$_SELF_UPDATE_URL}"
  tmp="$(mktemp "${TMPDIR:-/tmp}/self-update.XXXXXX")"
  if ! _su_download "$url" "$tmp"; then
    printf 'self-update: download failed (%s)\n' "$url" >&2
    rm -f "$tmp"; return 1
  fi
  if command -v bash >/dev/null 2>&1 && ! bash -n "$tmp" 2>/dev/null; then
    printf 'self-update: downloaded file fails bash syntax check — not applying\n' >&2
    rm -f "$tmp"; return 1
  fi
  rver="$(_su_version "$tmp")"
  lver="$(_su_version "$self")"
  if [[ -z "$rver" ]]; then
    printf 'self-update: no VERSION header in downloaded file\n' >&2
    rm -f "$tmp"; return 1
  fi
  if [[ -z "$lver" ]]; then
    printf 'self-update: no VERSION header in %s\n' "$self" >&2
    rm -f "$tmp"; return 1
  fi
  if [[ "$(printf '%s\n%s\n' "$lver" "$rver" | sort -V | tail -1)" == "$lver" ]]; then
    if [[ "$lver" == "$rver" ]]; then
      printf 'Already up to date (%s).\n' "$lver"
    else
      printf 'Local version (%s) is newer than remote (%s).\n' "$lver" "$rver"
    fi
    rm -f "$tmp"; return 0
  fi
  if [[ "${SELF_UPDATE_YES:-}" != "1" ]]; then
    printf 'Update %s (%s → %s)? [y/N] ' "${BASH_SOURCE[0]}" "$lver" "$rver"
    read -r ans
    if [[ "${ans:-}" != "y" && "${ans:-}" != "Y" && "${ans:-}" != "yes" ]]; then
      printf 'Aborted.\n'; rm -f "$tmp"; return 0
    fi
  fi
  chmod +x "$tmp"
  if ! mv -f "$tmp" "$self"; then
    printf 'self-update: could not replace %s\n' "$self" >&2
    rm -f "$tmp"; return 1
  fi
  printf 'Updated %s → %s (%s).\n' "$lver" "$rver" "$self"
}

self_update_check() {
  # Launch-time update check with a TTL cache: the remote version is
  # re-fetched at most every $SELF_UPDATE_TTL seconds (default 6h), so a
  # fresh cache avoids downloading the whole script on every launch.
  # Non-destructive: only sets _SU_LOCAL and _SU_AVAILABLE (remote
  # version when it is newer). Skips itself when BIBLE_NO_UPDATE_CHECK=1.
  # Bounded timeouts so an offline box never stalls the app for long.
  local url tmp rver cache age ttl
  _SU_AVAILABLE=""
  _SU_LOCAL=""
  [[ "${BIBLE_NO_UPDATE_CHECK:-0}" == "1" ]] && return 0
  _SU_LOCAL="$(_su_version "${BASH_SOURCE[0]}")"
  url="${SELF_UPDATE_URL:-$_SELF_UPDATE_URL}"
  ttl="${SELF_UPDATE_TTL:-21600}"
  cache="$BIBLE_CACHE/self-version"
  rver=""
  if [[ -f "$cache" ]]; then
    read -r rver < "$cache"
    age=$(( $(date +%s) - $(stat -c %Y "$cache" 2>/dev/null || echo 0) ))
    (( age >= 0 && age < ttl )) || rver=""
  fi
  if [[ -z "$rver" ]]; then
    mkdir -p "$BIBLE_CACHE"
    tmp="$(mktemp "${TMPDIR:-/tmp}/self-check.XXXXXX")"
    if command -v curl >/dev/null 2>&1; then
      curl -fsSL --connect-timeout 3 --max-time 6 "$url" -o "$tmp" 2>/dev/null
    elif command -v wget >/dev/null 2>&1; then
      wget -q -T 3 "$url" -O "$tmp" 2>/dev/null
    fi
    rver="$(_su_version "$tmp" 2>/dev/null)"
    rm -f "$tmp"
    [[ -n "$rver" ]] && printf '%s\n' "$rver" > "$cache"
  fi
  [[ -n "$_SU_LOCAL" && -n "$rver" ]] || return 0
  [[ "$_SU_LOCAL" != "$rver" ]] || return 0
  [[ "$(printf '%s\n%s\n' "$_SU_LOCAL" "$rver" | sort -V | tail -1)" == "$rver" ]] \
    && _SU_AVAILABLE="$rver"
}

self_update_notice() {
  # Header banner printed by the home screen when a newer version exists.
  [[ -n "${_SU_AVAILABLE:-}" ]] || return 0
  printf "\n${YELLOW}Update available: v%s → v%s${NC}  ${DIM}run: bible self-update (or -u)${NC}\n" \
    "${_SU_LOCAL:-}" "${_SU_AVAILABLE}"
}


# --- Metadata: OSIS|Name|Chapters (+ bolls number for Apocrypha) ------
_OT=(
  "GEN|Genesis|50" "EXO|Exodus|40" "LEV|Leviticus|27" "NUM|Numbers|36"
  "DEU|Deuteronomy|34" "JOS|Joshua|24" "JDG|Judges|21" "RUT|Ruth|4"
  "1SA|1 Samuel|31" "2SA|2 Samuel|24" "1KI|1 Kings|22" "2KI|2 Kings|25"
  "1CH|1 Chronicles|29" "2CH|2 Chronicles|36" "EZR|Ezra|10" "NEH|Nehemiah|13"
  "EST|Esther|10" "JOB|Job|42" "PSA|Psalm|150" "PRO|Proverbs|31"
  "ECC|Ecclesiastes|12" "SNG|Song of Solomon|8" "ISA|Isaiah|66" "JER|Jeremiah|52"
  "LAM|Lamentations|5" "EZK|Ezekiel|48" "DAN|Daniel|12" "HOS|Hosea|14"
  "JOL|Joel|3" "AMO|Amos|9" "OBA|Obadiah|1" "JON|Jonah|4" "MIC|Micah|7"
  "NAM|Nahum|3" "HAB|Habakkuk|3" "ZEP|Zephaniah|3" "HAG|Haggai|2"
  "ZEC|Zechariah|14" "MAL|Malachi|4"
)
_NT=(
  "MAT|Matthew|28" "MRK|Mark|16" "LUK|Luke|24" "JHN|John|21" "ACT|Acts|28"
  "ROM|Romans|16" "1CO|1 Corinthians|16" "2CO|2 Corinthians|13" "GAL|Galatians|6"
  "EPH|Ephesians|6" "PHP|Philippians|4" "COL|Colossians|4" "1TH|1 Thessalonians|5"
  "2TH|2 Thessalonians|3" "1TI|1 Timothy|6" "2TI|2 Timothy|4" "TIT|Titus|3"
  "PHM|Philemon|1" "HEB|Hebrews|13" "JAS|James|5" "1PE|1 Peter|5" "2PE|2 Peter|3"
  "1JN|1 John|5" "2JN|2 John|1" "3JN|3 John|1" "JUD|Jude|1" "REV|Revelation|22"
)
# Apocrypha (bible.com KJVAAE only — KJV has none; Sirach, 1/2 Esdras,
# Susanna and Prayer of Manasseh are absent from KJVAAE too).
_APO=(
  "TOB|Tobit|14" "JDT|Judith|16" "WIS|Wisdom of Solomon|19" "BAR|Baruch|6"
  "1MA|1 Maccabees|16" "2MA|2 Maccabees|15" "BEL|Bel and the Dragon|1"
)
_VERSIONS_NO=("B2024BM" "NORSK" "NB" "N78BM" "N11BM" "ELB" "BGO_HVER" "BGO")
_VERSIONS_EN=("KJV" "NKJV" "NIV" "NLT" "ESV" "AMP" "GNV" "WBMS" "KJVAAE" "KJVAE")
_VERSIONS_ORIG=("TR1624" "תנ\"ך")

DEF_VERSION="KJV"
TRANS_ENGINE="google"

# --- Home: greeting, daily verse, continue reading --------------------
BIBLE_CACHE="${BIBLE_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/bible}"
BIBLE_LAST="$BIBLE_CACHE/last"

greeting() {
  local h
  h=$(date +%H)
  if (( 10#$h >= 5 && 10#$h < 11 )); then
    echo "Good morning"
  elif (( 10#$h >= 11 && 10#$h < 18 )); then
    echo "Good day"
  elif (( 10#$h >= 18 && 10#$h < 23 )); then
    echo "Good evening"
  else
    echo "Peaceful night"
  fi
}

home_verse() {
  # Daily verse, text only, refreshed once per day.
  local today cache stale
  today=$(date +%F)
  cache="$BIBLE_CACHE/votd-$today"
  mkdir -p "$BIBLE_CACHE"
  if [[ ! -f "$cache" ]]; then
    if VOTD_TEXT=1 votd "$DEF_VERSION" > "$cache.tmp" 2>/dev/null \
       && grep -q 'https://' "$cache.tmp"; then
      mv "$cache.tmp" "$cache"
    else
      rm -f "$cache.tmp"
    fi
  fi
  if [[ -f "$cache" ]]; then
    cat "$cache"
    return
  fi
  stale=$(ls -t "$BIBLE_CACHE"/votd-* 2>/dev/null | head -n 1 || true)
  if [[ -n "$stale" ]]; then
    echo "${DIM}(from an earlier day)${NC}"
    cat "$stale"
  fi
}

home_header() {
  local streak
  printf "\n${BOLD}✝ %s${NC}  ${DIM}%s${NC}" "$(greeting)" "$(date +"%A %-d %B")"
  streak=$(day_streak)
  if [[ -n "$streak" ]]; then
    printf "  ${DIM}· %s-day streak${NC}" "$streak"
  fi
  printf "\n\n"
  self_update_notice
  home_verse
  printf "\n"
}

save_place() {
  # $1 = "osis|name|chapter|version". Also records the day for streaks.
  mkdir -p "$BIBLE_CACHE"
  echo "$1" > "$BIBLE_LAST"
  grep -qxF "$(date +%F)" "$BIBLE_CACHE/days" 2>/dev/null \
    || echo "$(date +%F)" >> "$BIBLE_CACHE/days"
}

day_streak() {
  # Consecutive reading days ending today (or yesterday if today
  # hasn't been read yet). Echoes the count or nothing.
  local f="$BIBLE_CACHE/days" d n=0
  [[ -f "$f" ]] || return
  d=$(date +%F)
  grep -qxF "$d" "$f" || d=$(date -d yesterday +%F)
  while grep -qxF "$d" "$f"; do
    ((n++)) || true
    d=$(date -d "$d -1 day" +%F)
  done
  (( n >= 2 )) && echo "$n"
}

book_chapters() {
  # $1 = OSIS → chapter count, empty if unknown.
  local e
  for e in "${_OT[@]}" "${_NT[@]}" "${_APO[@]}"; do
    if [[ "$(cut -d'|' -f1 <<<"$e")" == "$1" ]]; then
      cut -d'|' -f3 <<<"$e"
      return
    fi
  done
}

osis_name() {
  # $1 = OSIS → display name (e.g. PSA → Psalm), empty if unknown.
  local e
  for e in "${_OT[@]}" "${_NT[@]}" "${_APO[@]}"; do
    if [[ "$(cut -d'|' -f1 <<<"$e")" == "$1" ]]; then
      cut -d'|' -f2 <<<"$e"
      return
    fi
  done
}

continue_label() {
  local osis name ch ver
  [[ -f "$BIBLE_LAST" ]] || return
  IFS='|' read -r osis name ch ver < "$BIBLE_LAST"
  if [[ -n "$name" && -n "$ch" ]]; then
    echo "Continue: $name $ch"
  fi
}

continue_place() {
  local osis name ch ver maxch nav
  IFS='|' read -r osis name ch ver < "$BIBLE_LAST"
  [[ -z "$osis" || -z "$ch" ]] && return
  ver="${ver:-$DEF_VERSION}"
  maxch=$(book_chapters "$osis")
  while true; do
    show_chapter "$osis" "$ch" "$ver" "$name"
    save_place "$osis|$name|$ch|$ver"
    plan_sync "$osis" "$ch" "$ver"
    nav=$(read_key "[n]ext [p]rev [f]av [q]uit: ")
    case "$nav" in
      n|N) if [[ -n "$maxch" ]] && ((ch < maxch)); then ((ch++)); else echo "Last chapter."; fi ;;
      p|P) ((ch > 1)) && ((ch--)) || echo "First chapter." ;;
      f|F) toggle_fav "$osis|$name|$ch|$ver" ;;
      *) return ;;
    esac
  done
}

# Common translate-shell target codes; Custom… prompts for any code.
_LANGS=(
  "Norsk|no" "English|en" "Español|es" "Français|fr" "Deutsch|de"
  "Svenska|sv" "Dansk|da" "Italiano|it" "Português|pt" "Nederlands|nl"
)

# fzf for list picking when available (fallback: numbered menu).
# Opt out with NO_FZF=1.
_HAVE_FZF=false
if [[ -z "${NO_FZF:-}" && -n $(command -v 'fzf') ]]; then
  _HAVE_FZF=true
fi

# --- Helpers ---------------------------------------------------------
# One-keypress navigation: letters as-is (lowercased); Right arrow → n,
# Left arrow → p. $1 = optional prompt (printed to stderr, like read -p).
read_key() {
  local k c d
  [[ -n "$1" ]] && printf '%s' "$1" >&2
  IFS= read -rsn1 k </dev/tty
  if [[ "$k" == $'\x1b' ]]; then
    if IFS= read -rsn1 -t 0.2 c </dev/tty && [[ "$c" == "[" ]]; then
      if IFS= read -rsn1 -t 0.2 d </dev/tty; then
        case "$d" in
          C) k=n ;;  # Right → next
          D) k=p ;;  # Left → prev
          A|B) k="" ;;
        esac
      fi
    fi
  fi
  printf '%s' "${k,,}"
}

pause() {
  read -rp "Press Enter to continue..." _ </dev/tty
}

pick_from_list() {
  # $1 = prompt; rest = items. Echoes the chosen item (empty on abort).
  local prompt="$1"
  shift
  local items=("$@")
  local i choice picked
  if [[ "$_HAVE_FZF" == true ]]; then
    # fzf reads items from stdin and drives its UI on /dev/tty itself.
    picked=$(printf '%s\n' "← Back" "$@" \
      | fzf --prompt="$prompt › " --pointer="›" --border=rounded \
        --color="prompt:bold,pointer:green" --height=40% --reverse \
        --cycle || true)
    if [[ -z "$picked" || "$picked" == "← Back" ]]; then
      echo ""
    else
      echo "$picked"
    fi
    return
  fi
  # Menu goes to stderr: stdout carries only the result, which the
  # caller captures via $().
  printf "${BOLD}%s${NC}\n" "$prompt" >&2
  for i in "${!items[@]}"; do
    printf "  ${DIM}%2d)${NC} %s\n" "$((i + 1))" "${items[$i]}" >&2
  done
  printf "  ${DIM} 0)${NC} Back\n" >&2
  read -rp "› " choice </dev/tty
  if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#items[@]})); then
    echo "${items[$((choice - 1))]}"
  else
    echo ""
  fi
}

# --- Reading (bible.com, via the library) ---------------------------
browse_books() {
  # $1 = array name holding OSIS|Name|Chapters entries, $2 = version.
  local -n _books=$1
  local ver="$2" entry osis name maxch ch ref nav
  local -a names
  names=()
  for entry in "${_books[@]}"; do
    names+=("$(cut -d'|' -f2 <<<"$entry")")
  done
  entry=$(pick_from_list "Books:" "${names[@]}")
  [[ -z "$entry" ]] && return
  for e in "${_books[@]}"; do
    if [[ "$(cut -d'|' -f2 <<<"$e")" == "$entry" ]]; then
      entry="$e"
      break
    fi
  done
  osis="$(cut -d'|' -f1 <<<"$entry")"
  name="$(cut -d'|' -f2 <<<"$entry")"
  maxch="$(cut -d'|' -f3 <<<"$entry")"
  ch=""
  while true; do
    if [[ -z "$ch" ]]; then
      read -rp "$name has $maxch chapters. Chapter (1-$maxch, 0=back): " ch </dev/tty
      [[ "$ch" == "0" ]] && return
      if ! [[ "$ch" =~ ^[0-9]+$ ]] || ((ch < 1 || ch > maxch)); then
        echo "Enter a chapter between 1 and $maxch."
        ch=""
        continue
      fi
      read -rp "Verse (empty = whole chapter): " ref </dev/tty
    fi
    if [[ -z "$ref" ]]; then
      show_chapter "$osis" "$ch" "$ver" "$name"
    else
      bible "$name" "$ch:$ref" "$ver"
    fi
    save_place "$osis|$name|$ch|$ver"
    nav=$(read_key "[n]ext [p]rev [v]erse [c]hapter [f]av [q]uit: ")
    case "$nav" in
      n|N) ((ch < maxch)) && ((ch++)) || echo "Last chapter."; ref="" ;;
      p|P) ((ch > 1)) && ((ch--)) || echo "First chapter."; ref="" ;;
      v|V) read -rp "Verse (empty = whole chapter): " ref </dev/tty ;;
      c|C) ch="" ;;
      f|F) toggle_fav "$osis|$name|$ch|$ver" ;;
      *) return ;;
    esac
  done
}
# Audio-browse a Testament: pick book → chapter (optional verse), play
# the audio, then [n]ext / [p]rev / [c]hapter. Wherever you stop becomes
# the reading spot too (Continue + plans pick up the same place).
listen_browse() {
  # $1 = array name holding OSIS|Name|Chapters entries, $2 = version.
  local -n _books=$1
  local ver="$2" entry osis name maxch ch ref nav
  local -a names
  names=()
  for entry in "${_books[@]}"; do
    names+=("$(cut -d'|' -f2 <<<"$entry")")
  done
  entry=$(pick_from_list "Books:" "${names[@]}")
  [[ -z "$entry" ]] && return
  for e in "${_books[@]}"; do
    if [[ "$(cut -d'|' -f2 <<<"$e")" == "$entry" ]]; then
      entry="$e"
      break
    fi
  done
  osis="$(cut -d'|' -f1 <<<"$entry")"
  name="$(cut -d'|' -f2 <<<"$entry")"
  maxch="$(cut -d'|' -f3 <<<"$entry")"
  ch=""
  while true; do
    if [[ -z "$ch" ]]; then
      read -rp "$name has $maxch chapters. Chapter (1-$maxch, 0=back): " ch </dev/tty
      [[ "$ch" == "0" ]] && return
      if ! [[ "$ch" =~ ^[0-9]+$ ]] || ((ch < 1 || ch > maxch)); then
        echo "Enter a chapter between 1 and $maxch."
        ch=""
        continue
      fi
      read -rp "Verse (empty = whole chapter): " ref </dev/tty
    fi
    if [[ -z "$ref" ]]; then
      listen "$name" "$ch" "$ver"
    else
      listen "$name" "$ch:$ref" "$ver"
    fi
    save_place "$osis|$name|$ch|$ver"
    nav=$(read_key "[n]ext [p]rev [v]erse [c]hapter [q]uit: ")
    case "$nav" in
      n|N) ((ch < maxch)) && ((ch++)) || echo "Last chapter."; ref="" ;;
      p|P) ((ch > 1)) && ((ch--)) || echo "First chapter."; ref="" ;;
      v|V) read -rp "Verse (empty = whole chapter): " ref </dev/tty ;;
      c|C) ch="" ;;
      *) return ;;
    esac
  done
}

show_chapter() {
  # $1=OSIS $2=chapter $3=version $4=display name (optional)
  local osis="$1" ch="$2" ver="$3" dname="${4:-$1}"
  version="$ver"
  version_case
  # Offline-first: render from the local database when installed.
  if [[ "$ver" == "KJV" ]] && _offline_is_installed "KJV"; then
    local usfms
    usfms=$(local_chapter_verses "$osis" "$ch" "$ver")
    if [[ -n "$usfms" ]]; then
      local_chapter_text "$osis" "$ch" "$ver"
      printf "\n${GREEN}%s %s${NC} - ${YELLOW}(%s)${NC}\n" "$dname" "$ch" "$ver"
      printf "${BLUE}https://www.bible.com/bible/%s/%s.%s.%s${NC}\n\n" "$num" "$osis" "$ch" "$ver"
      return
    fi
  fi
  get_bible_chapter "$osis" "$ch" "$ver"
  chapter_text "$tmp" "$osis.$ch"
  printf "\n${GREEN}%s %s${NC} - ${YELLOW}(%s)${NC}\n" "$dname" "$ch" "$ver"
  printf "${BLUE}https://www.bible.com/bible/%s/%s.%s.%s${NC}\n\n" "$num" "$osis" "$ch" "$ver"
}

# --- Menus -----------------------------------------------------------
toggle_fav() {
  # $1 = "osis|name|chapter|version" — toggles the favorites shelf.
  local fav="$BIBLE_CACHE/favorites"
  mkdir -p "$BIBLE_CACHE"
  touch "$fav"
  if grep -qxF "$1" "$fav"; then
    grep -vxF "$1" "$fav" > "$fav.tmp" && mv "$fav.tmp" "$fav"
    echo "Removed from favorites."
  else
    echo "$1" >> "$fav"
    echo "Saved to favorites."
  fi
}

menu_favorites() {
  local entry label line
  local -a labels
  [[ -f "$BIBLE_CACHE/favorites" ]] || { echo "No favorites yet."; pause; return; }
  labels=()
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    label="$(cut -d'|' -f2 <<<"$line") $(cut -d'|' -f3 <<<"$line") ($(cut -d'|' -f4 <<<"$line"))"
    labels+=("$label")
  done < "$BIBLE_CACHE/favorites"
  if (( ${#labels[@]} == 0 )); then
    echo "No favorites yet."
    pause
    return
  fi
  entry=$(pick_from_list "Favorites:" "${labels[@]}")
  [[ -z "$entry" ]] && return
  while IFS= read -r line; do
    label="$(cut -d'|' -f2 <<<"$line") $(cut -d'|' -f3 <<<"$line") ($(cut -d'|' -f4 <<<"$line"))"
    if [[ "$label" == "$entry" ]]; then
      echo "$line" > "$BIBLE_LAST"
      continue_place
      return
    fi
  done < "$BIBLE_CACHE/favorites"
}

# --- Reading plans ----------------------------------------------------
# A plan is a line in $BIBLE_CACHE/plans:  name|osis|chapter|version
# (one per book; adding again with the same book moves its position).
# Progress follows wherever you stop: quit/leave/back in the plan loop,
# and cross-reading from the Continue spot on the index keeps in sync.

plan_file="$BIBLE_CACHE/plans"

plan_sync() {
  # $1=osis $2=chapter $3=version — fold the given position into the
  # plan file if a plan exists for that book (no-op otherwise).
  local osis="$1" ch="$2" ver="$3" p name
  p="$plan_file"
  [[ -f "$p" ]] || return 0
  if grep -q "^[^|]*|$osis|" "$p"; then
    name=$(osis_name "$osis")
    grep -v "^[^|]*|$osis|" "$p" > "$p.tmp"
    printf '%s|%s|%s|%s\n' "$name" "$osis" "$ch" "$ver" >> "$p.tmp"
    mv "$p.tmp" "$p"
  fi
}

plan_save_chapter() {
  # $1=osis $2=chapter $3=version — create or move a book's plan.
  local osis="$1" ch="$2" ver="$3" p name
  p="$plan_file"
  mkdir -p "$BIBLE_CACHE"
  name=$(osis_name "$osis")
  if grep -q "^[^|]*|$osis|" "$p" 2>/dev/null; then
    grep -v "^[^|]*|$osis|" "$p" > "$p.tmp"
    printf '%s|%s|%s|%s\n' "$name" "$osis" "$ch" "$ver" >> "$p.tmp"
    mv "$p.tmp" "$p"
  else
    printf '%s|%s|%s|%s\n' "$name" "$osis" "$ch" "$ver" >> "$p"
  fi
}

plan_read() {
  # $1 = "name|osis|chapter|version" (as stored). Read from that chapter;
  # wherever you quit becomes both the plan's position and the index
  # Continue spot.
  local line name osis ch ver maxch nav
  line="$1"
  IFS='|' read -r name osis ch ver <<< "$line"
  ver="${ver:-$DEF_VERSION}"
  maxch=$(book_chapters "$osis")
  while true; do
    show_chapter "$osis" "$ch" "$ver" "$name"
    save_place "$osis|$name|$ch|$ver"
    plan_sync "$osis" "$ch" "$ver"
    nav=$(read_key "[n]ext [p]rev [f]av [q]uit: ")
    case "$nav" in
      n|N) if [[ -n "$maxch" ]] && ((ch < maxch)); then ((ch++)); else echo "Last chapter."; fi ;;
      p|P) ((ch > 1)) && ((ch--)) || echo "First chapter." ;;
      f|F) toggle_fav "$osis|$name|$ch|$ver" ;;
      *) return ;;
    esac
  done
}

plan_add() {
  local ref ch maxch ver
  read -rp "Reading plan start (e.g. Psalm 65, or 2 Timothy 3): " ref </dev/tty
  [[ -z "$ref" ]] && return 1
  # Reuse the app's reference parser: sets book/chapter/verse/version.
  # shellcheck disable=SC2086
  args $ref
  book_case
  [[ -n "${bible_book:-}" ]] || { echo "Could not resolve book '$book'."; pause; return 1; }
  ch="${chapter:-1}"
  maxch=$(book_chapters "$bible_book")
  if [[ -z "$maxch" ]] || ! [[ "$ch" =~ ^[0-9]+$ ]] || ((ch < 1 || ch > maxch)); then
    echo "${bible_book_name:-$bible_book} has chapters 1-$maxch."
    return 1
  fi
  ver="${version:-$DEF_VERSION}"
  plan_save_chapter "$bible_book" "$ch" "$ver"
  printf 'Reading plan: %s %s (%s).\n' "$(osis_name "$bible_book")" "$ch" "$ver"
  plan_read "$(osis_name "$bible_book")|$bible_book|$ch|$ver"
}

plan_listen() {
  # Listen through the plan: plays the current chapter's audio, then
  # [n]ext / [p]rev / [q]uit. Wherever you stop becomes the plan's
  # position and the index Continue spot.
  local line name osis ch ver maxch nav
  line="$1"
  IFS='|' read -r name osis ch ver <<< "$line"
  ver="${ver:-$DEF_VERSION}"
  maxch=$(book_chapters "$osis")
  while true; do
    listen "$name" "$ch" "$ver"
    save_place "$osis|$name|$ch|$ver"
    plan_sync "$osis" "$ch" "$ver"
    nav=$(read_key "[n]ext [p]rev [q]uit: ")
    case "$nav" in
      n|N) if [[ -n "$maxch" ]] && ((ch < maxch)); then ((ch++)); else echo "Last chapter."; fi ;;
      p|P) ((ch > 1)) && ((ch--)) || echo "First chapter." ;;
      *) return ;;
    esac
  done
}

plan_remove() {
  local -a labels lines
  local line i pick p
  labels=(); lines=()
  if [[ -f "$plan_file" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      labels+=("$(cut -d'|' -f1 <<<"$line") $(cut -d'|' -f3 <<<"$line")")
      lines+=("$line")
    done < "$plan_file"
  fi
  if [[ ${#lines[@]} -eq 0 ]]; then
    echo "No reading plans yet."
    pause
    return
  fi
  pick=$(pick_from_list "Remove reading plan:" "${labels[@]}")
  [[ -z "$pick" ]] && return
  for i in "${!labels[@]}"; do
    if [[ "${labels[$i]}" == "$pick" ]]; then
      p="$plan_file"
      grep -vxF "${lines[$i]}" "$p" > "$p.tmp" || true
      mv -f "$p.tmp" "$p"
      echo "Removed reading plan: $pick"
      return
    fi
  done
}

menu_read() {
  local choice day pl pn po pc pv
  local -a labels lines picks
  local line i name osis ch ver
  day=$(date +%-d 2>/dev/null || date +%e); day=${day// /}
  labels=(); lines=(); picks=()
  if [[ -f "$plan_file" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      IFS='|' read -r name osis ch ver <<< "$line"
      labels+=("$name $ch")
      lines+=("$line")
    done < "$plan_file"
  fi
  # The reading plan starts where you last read: a "Continue reading
  # plan" shortcut for the most recently active plan (last line).
  pl=""
  if [[ -s "$plan_file" ]]; then
    pl="$(tail -1 "$plan_file")"
    [[ -n "$pl" ]] && IFS='|' read -r pn po pc pv <<< "$pl"
  fi
  if [[ -n "$pl" ]]; then
    picks+=("Continue reading plan: $pn $pc")
  fi
  picks+=("A proverb a day (Proverbs $day)" \
    "The Lord's prayer (Matthew 6:9-13)" \
    "${labels[@]}" \
    "Add a reading plan" "Remove a reading plan" \
    "Old Testament" "New Testament" "Apocrypha (KJVAAE)")
  choice=$(pick_from_list "Read:" "${picks[@]}")
  case "$choice" in
    "Continue reading plan: $pn $pc") plan_read "$pl" ;;
    "A proverb a day (Proverbs $day)") menu_proverb ;;
    "The Lord's prayer (Matthew 6:9-13)")
      bible "Matthew" "6:9-13" "$DEF_VERSION"
      pause
      ;;
    "Add a reading plan") plan_add ;;
    "Remove a reading plan") plan_remove ;;
    "Old Testament") browse_books _OT "$DEF_VERSION" ;;
    "New Testament") browse_books _NT "$DEF_VERSION" ;;
    "Apocrypha (KJVAAE)") browse_books _APO KJVAAE ;;
    *)
      for i in "${!labels[@]}"; do
        if [[ "${labels[$i]}" == "$choice" ]]; then
          plan_read "${lines[$i]}"
          return
        fi
      done
      ;;
  esac
}

menu_proverb() {
  # "A proverb a day": read the chapter of Proverbs matching today's
  # date — Proverbs has exactly 31 chapters, one per day of the month.
  # Audio lives in the Listen section ("A proverb a day" there).
  local day osis="PRO"
  day=$(date +%-d 2>/dev/null || date +%e); day=${day// /}
  if ! [[ "$day" =~ ^[0-9]+$ ]] || ((day < 1 || day > 31)); then
    echo "Could not match today's date to a chapter of Proverbs."
    pause
    return
  fi
  show_chapter "$osis" "$day" "$DEF_VERSION" "Proverbs"
  save_place "$osis|Proverbs|$day|$DEF_VERSION"
}

menu_offline() {
  local choice
  offline_status
  echo ""
  if _offline_is_installed "KJV"; then
    choice=$(pick_from_list "Offline Bible:" "Update KJV" "Reinstall KJV")
    case "$choice" in
      "Update KJV") update_version "KJV"; pause ;;
      "Reinstall KJV") _fetch_and_build "KJV"; pause ;;
    esac
  else
    choice=$(pick_from_list "Offline Bible:" "Install KJV (offline read/search)")
    case "$choice" in
      "Install KJV (offline read/search)") install_version "KJV"; pause ;;
    esac
  fi
}

menu_version() {
  local choice
  choice=$(pick_from_list "Default version (now: $DEF_VERSION):" \
    "${_VERSIONS_EN[@]}" "${_VERSIONS_NO[@]}" "${_VERSIONS_ORIG[@]}")
  if [[ -n "$choice" ]]; then
    DEF_VERSION="$choice"
    echo "Default version: $DEF_VERSION"
    sleep 0.5
  fi
}

menu_search() {
  local q v
  read -rp "Keywords: " q </dev/tty
  [[ -z "$q" ]] && return
  read -rp "Version [$DEF_VERSION]: " v </dev/tty
  search "$q" "${v:-$DEF_VERSION}"
  pause
}

menu_compare() {
  local ref vers
  read -rp "Reference (e.g. John 3:16): " ref </dev/tty
  [[ -z "$ref" ]] && return
  read -rp "Versions (space-separated, en/no, [$DEF_VERSION]): " vers </dev/tty
  # shellcheck disable=SC2086
  compare $ref ${vers:-$DEF_VERSION}
  pause
}

menu_listen() {
  # The audio mirror of the Read section: proverb, reading plans, and
  # the whole Bible browsed by book. Wherever you stop becomes the
  # reading spot too, so Read and Listen pick up the same place.
  local choice day pl pn po pc pv
  local -a labels lines picks
  local line i name osis ch ver
  day=$(date +%-d 2>/dev/null || date +%e); day=${day// /}
  labels=(); lines=(); picks=()
  if [[ -f "$plan_file" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      IFS='|' read -r name osis ch ver <<< "$line"
      labels+=("$name $ch")
      lines+=("$line")
    done < "$plan_file"
  fi
  # The reading plan starts where you last listened: a "Continue
  # reading plan" shortcut for the most recently active plan.
  pl=""
  if [[ -s "$plan_file" ]]; then
    pl="$(tail -1 "$plan_file")"
    [[ -n "$pl" ]] && IFS='|' read -r pn po pc pv <<< "$pl"
  fi
  if [[ -n "$pl" ]]; then
    picks+=("Continue reading plan: $pn $pc")
  fi
  picks+=("A proverb a day (Proverbs $day)" \
    "The Lord's prayer (Matthew 6:9-13)" \
    "${labels[@]}" \
    "Old Testament" "New Testament" "Apocrypha (KJVAAE)")
  choice=$(pick_from_list "Listen:" "${picks[@]}")
  case "$choice" in
    "Continue reading plan: $pn $pc") plan_listen "$pl" ;;
    "A proverb a day (Proverbs $day)")
      listen "Proverbs" "$day" "$DEF_VERSION"
      save_place "PRO|Proverbs|$day|$DEF_VERSION"
      pause
      ;;
    "The Lord's prayer (Matthew 6:9-13)")
      listen "Matthew" "6:9-13" "$DEF_VERSION"
      pause
      ;;
    "Old Testament") listen_browse _OT "$DEF_VERSION" ;;
    "New Testament") listen_browse _NT "$DEF_VERSION" ;;
    "Apocrypha (KJVAAE)") listen_browse _APO KJVAAE ;;
    *)
      for i in "${!labels[@]}"; do
        if [[ "${labels[$i]}" == "$choice" ]]; then
          plan_listen "${lines[$i]}"
          return
        fi
      done
      ;;
  esac
}

pick_target() {
  # Sets tgt or returns 1 on abort.
  local choice e
  choice=$(pick_from_list "Target language:" \
    "Norsk" "English" "Español" "Français" "Deutsch" \
    "Svenska" "Dansk" "Italiano" "Português" "Nederlands" "Custom…")
  case "$choice" in
    "") return 1 ;;
    "Custom…")
      read -rp "Target code (e.g. no, fi, is): " tgt </dev/tty
      [[ -z "$tgt" ]] && return 1
      ;;
    *)
      for e in "${_LANGS[@]}"; do
        if [[ "$(cut -d'|' -f1 <<<"$e")" == "$choice" ]]; then
          tgt="$(cut -d'|' -f2 <<<"$e")"
          break
        fi
      done
      ;;
  esac
}

pick_engine() {
  local choice
  choice=$(pick_from_list "Engine (now: $TRANS_ENGINE):" "google" "bing")
  if [[ -n "$choice" ]]; then
    TRANS_ENGINE="$choice"
  fi
}

pick_output() {
  local choice
  choice=$(pick_from_list "Output (now: ${TRANS_VERBOSE:-brief}):" "brief" "full")
  case "$choice" in
    full) TRANS_VERBOSE=1; out="full" ;;
    brief) TRANS_VERBOSE=""; out="brief" ;;
  esac
}

menu_translate() {
  local ref src tgt out nav
  read -rp "Reference (e.g. Matthew 17:21): " ref </dev/tty
  [[ -z "$ref" ]] && return
  read -rp "Source (auto/hebrew/greek/version) [auto]: " src </dev/tty
  pick_target || return
  pick_engine
  pick_output
  while true; do
    # shellcheck disable=SC2086
    if [[ -n "$out" ]]; then
      translate $ref ${src:-auto} "$tgt" "$TRANS_ENGINE" "$out"
    else
      translate $ref ${src:-auto} "$tgt" "$TRANS_ENGINE"
    fi
    read -rp "[t]arget [e]ngine [o]utput [r]eference [q]uit: " nav </dev/tty
    case "$nav" in
      t|T) pick_target || true ;;
      e|E) pick_engine ;;
      o|O) pick_output ;;
      r|R)
        read -rp "Reference (e.g. Matthew 17:21): " ref </dev/tty
        [[ -z "$ref" ]] && return
        read -rp "Source (auto/hebrew/greek/version) [auto]: " src </dev/tty
        ;;
      *) return ;;
    esac
  done
}

hotkey_label() {
  # $1 = key, $2 = label → label with the key letter highlighted.
  local key="${1,,}" ll tmp pos
  ll="${2,,}"
  tmp="${ll%%"$key"*}"
  if [[ "$tmp" == "$ll" ]]; then
    printf '%s (%s)' "$2" "$1"
    return
  fi
  pos=${#tmp}
  printf '%s%s%s%s%s' "${2:0:pos}" "${BOLD}${GREEN}" "${2:pos:1}" "${NC}" "${2:pos+1}"
}

menu_votd() {
  votd "$DEF_VERSION"
  pause
}

menu_saved() {
  witness_saved "$DEF_VERSION"
}

main_menu() {
  mkdir -p "$BIBLE_CACHE"
  self_update_check
  home_header
  local key i item found
  local -a keys actions labels
  while true; do
    # One compact bar: single keypress, no scrolling. Sub-pickers
    # (books, versions, languages) still use fzf/numbered lists.
    keys=()
    actions=()
    labels=()
    item=$(continue_label)
    if [[ -n "$item" ]]; then
      keys+=(c)
      actions+=(continue_place)
      labels+=("$item")
    fi
    keys+=(a r f s m l v t e o h)
    actions+=(menu_saved menu_read menu_favorites menu_search menu_compare menu_listen menu_votd menu_translate menu_version menu_offline menu_help)
    labels+=("Are you saved?" "Read" "Favorites" "Search" "Compare" "Listen" "Verse of the Day" "Translate" "Version" "Offline" "Help")
    # One compact bar: single keypress, no scrolling. Items wrap at the
    # terminal width (default 80) so long labels never mid-word overflow.
    local w _lab _plain _used
    w="${COLUMNS:-}"
    [[ "$w" =~ ^[0-9]+$ ]] && ((w > 40)) || w="$(tput cols 2>/dev/null || echo 80)"
    [[ "$w" =~ ^[0-9]+$ ]] && ((w > 40)) || w=80
    _used=0
    for i in "${!labels[@]}"; do
      _lab="$(hotkey_label "${keys[$i]}" "${labels[$i]}")"
      _plain="$(printf '%s' "$_lab" | sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g')"
      if (( _used > 0 && _used + ${#_plain} + 2 > w )); then
        printf '\n  ' >&2
        _used=2
      fi
      printf '%s  ' "$_lab" >&2
      _used=$((_used + ${#_plain} + 2))
    done
    _lab="$(hotkey_label q Quit)"
    _plain="$(printf '%s' "$_lab" | sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g')"
    if (( _used > 0 && _used + ${#_plain} + 2 > w )); then
      printf '\n  ' >&2
    fi
    printf '%s\n' "$_lab" >&2
    printf '› ' >&2
    IFS= read -rsn1 key </dev/tty
    printf '\n' >&2
    key="${key,,}"
    if [[ -z "$key" || "$key" == $'\r' || "$key" == $'\n' ]]; then
      key=c # Enter continues reading when there is somewhere to go
    fi
    if [[ "$key" == $'\x1b' || "$key" == q ]]; then
      return
    fi
    found=false
    for i in "${!keys[@]}"; do
      if [[ "${keys[$i]}" == "$key" ]]; then
        "${actions[$i]}"
        found=true
        break
      fi
    done
    [[ "$found" == true ]] || printf "${DIM}Press h for help, q to quit.${NC}\n" >&2
  done
}

menu_help() {
  usage
  pause
}

# --- Entry -----------------------------------------------------------
if [[ $# -gt 0 ]]; then
  # CLI passthrough to the library commands.
  case "$1" in
    --help | -h) usage ;;
    --bible | -b) shift; bible "$@" ;;
    --search | -s) shift; search "$@" ;;
    --votd | -v | votd) shift; votd "$@" ;;
    --listen | -l) shift; listen "$@" ;;
    --compare | -c) shift; compare "$@" ;;
    --saved | -a | saved) shift; witness_saved "$@" ;;
    --translate | -t) shift; translate "$@" ;;
    proverb) menu_proverb ;;
    install) shift; install_version "${1:-KJV}" "${2:-}" ;;
    update) shift; update_version "${1:-KJV}" "${2:-}" ;;
    status) offline_status ;;
    self-update | selfupdate | -u | --update | upgrade) shift; self_update ;;
    --no-update-check) BIBLE_NO_UPDATE_CHECK=1; main_menu ;;
    hl|highlights)
      shift
      case "${1:-status}" in
        login) shift; hl_login ;;
        approve) shift; hl_approve ;;
        list) shift; hl_list "${1:-}" ;;
        add) shift; hl_add "$@" ;;
        delete|rm) shift; hl_delete "${1:-}" ;;
        *) hl_status ;;
      esac
      ;;
    *) usage; exit 1 ;;
  esac
  exit 0
fi

main_menu
