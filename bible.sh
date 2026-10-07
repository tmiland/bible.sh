#!/usr/bin/env bash

## Author: Tommy Miland (@tmiland) - Copyright (c) 2026
##
######################################################################
####                            bible                             ####
####   Single-file interactive Bible app and CLI — browse the      ####
####   Bible like an app: menus for Read, Search, Compare,         ####
####   VOTD, Translate.  Run with args directly:                   ####
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

uninstall_version() {
  # $1 = version code (default KJV); -y/--yes skips the confirmation,
  # --all removes every supported offline version. After this, reading
  # falls back to the keyless YouVersion JSON API and search to the
  # bible.com search page.
  local ver="" assume_yes=false do_all=false arg
  for arg in "$@"; do
    case "$arg" in
      -y | --yes) assume_yes=true ;;
      --all) do_all=true ;;
      -h | --help)
        echo "Usage: bible uninstall [VERSION] [-y|--yes] [--all]"
        return 0
        ;;
      "") ;;
      *) ver="${arg^^}" ;;
    esac
  done

  local -a versions=()
  if [[ "$do_all" == true ]]; then
    versions=("${_OFFLINE_SUPPORTED_VERSIONS[@]}")
  else
    versions=("${ver:-KJV}")
  fi

  local v db json raw
  local -a files=()
  for v in "${versions[@]}"; do
    db="$(_offline_db "$v")"
    json="$(_offline_json "$v")"
    [[ -f "$db" ]] && files+=("$db")
    [[ -f "$json" ]] && files+=("$json")
    # Leftover raw/partial downloads from older builds.
    for raw in "$BIBLE_CACHE/RAW-${v}"*.json "$BIBLE_CACHE/${v}"*.tmp; do
      [[ -f "$raw" ]] && files+=("$raw")
    done
  done

  if (( ${#files[@]} == 0 )); then
    echo "Nothing to uninstall: ${versions[*]} is not installed offline."
    return 1
  fi

  if [[ "$assume_yes" != true ]]; then
    echo "The following offline files will be removed:"
    printf '  %s\n' "${files[@]}"
    printf 'Remove them? [y/N] '
    local answer=""
    read -r answer || answer=""
    [[ "$answer" == [yY]* ]] || { echo "Aborted."; return 1; }
  fi

  rm -f -- "${files[@]}"
  echo "Uninstalled offline: ${versions[*]}."
  echo "Reading now falls back to the online YouVersion JSON API;"
  echo "search falls back to the bible.com search page."
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
          printf "\n${BOLD}%s${NC}%s %s\n" "$vnum" "$(_hl_verse_mark "$vnum")" "$(echo "$vtext" | fold -w "${width}" -s)"
        fi
      done < <(sqlite3 "$db" "SELECT verse, text FROM verses WHERE osis='$osis' AND chapter=$ch ORDER BY verse;" 2>/dev/null)
      return 0
    fi
  fi

  json="$(_offline_json "$ver")"
  if [[ -f "$json" ]]; then
    while IFS='|' read -r vnum vtext; do
      if [[ -n "$vtext" ]]; then
        printf "\n${BOLD}%s${NC}%s %s\n" "$vnum" "$(_hl_verse_mark "$vnum")" "$(echo "$vtext" | fold -w "${width}" -s)"
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
  echo "Manage: bible install | bible update | bible uninstall [VERSION]"
  divider_line
}

# ---------------------------------------------------------------
# module: bible_api.sh - YouVersion Platform API
# ---------------------------------------------------------------
# shellcheck disable=SC2001,SC2317

## YouVersion Platform API support for bible.sh
## Reading and searching through the official Platform API
## (api.youversion.com). Key-gated: nothing changes unless an app key
## is configured ($YVP_APP_KEY or ~/.credentials/.bible.com_token) AND
## the requested version is licensed to that key. Callers fall back to
## the keyless JSON APIs on any failure.

## App key: https://developers.youversion.com — 48 chars, sent as the
## x-yvp-app-key header (not a secret). Rate-limited: 429 + Retry-After.

_YVP_API="${YVP_API_BASE:-https://api.youversion.com}/v1"
_YVP_KEY_FILE="$HOME/.credentials/.bible.com_token"
BIBLE_CACHE="${BIBLE_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/bible}"
# Full Platform API version catalog, cached as TSV rows of
# id<TAB>localized_abbreviation<TAB>language_tag (see _yvp_catalog).
_YVP_CATALOG_CACHE="$BIBLE_CACHE/catalog.tsv"
# How long the catalog stays fresh before being re-checked against the
# API (minutes). 1440 = 1 day, so a newly licensed version becomes
# readable/searchable within a day, no manual remapping needed.
_YVP_CATALOG_TTL_MIN="${_YVP_CATALOG_TTL_MIN:-1440}"
# Last /v1/search-verses response (raw JSON) plus parsed metadata for
# the search pager: _YVP_SEARCH_QUERY (the query it answered),
# _YVP_SEARCH_NEXT (pagination token, empty = no more results),
# _YVP_SEARCH_DYM ("did you mean" suggestions), _YVP_SEARCH_RATHER
# ("search instead for" hint).
_YVP_SEARCH_JSON=""
_YVP_SEARCH_QUERY=""
_YVP_SEARCH_NEXT=""
_YVP_SEARCH_DYM=""
_YVP_SEARCH_RATHER=""
# Verse-text cache keyed by USFM ref: fetched once per reference via
# /passages, reused across page turns and the interactive picker so a
# repeated/navigated page does not refetch.
declare -A _YVP_TEXT_CACHE
# Live typeahead suggestions (populated by _yvp_suggest_live).
_SUG_TERMS=()
_SUG_INFO=""

# --- Key / licensing --------------------------------------------------

_yvp_key() {
  # Echo the configured app key (non-zero when none is set):
  # 1. $YVP_APP_KEY env var
  # 2. ~/.credentials/.bible.com_token
  # 3. The built-in default for this distribution of bible.sh
  local key="${YVP_APP_KEY:-}"
  if [[ -z "$key" && -s "$_YVP_KEY_FILE" ]]; then
    key=$(cat "$_YVP_KEY_FILE")
  fi
  if [[ -z "$key" ]]; then
    key="${_YVP_KEY_DEFAULT:-}"
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

_yvp_catalog() {
  # Echo the full Platform API version catalog as TSV rows of
  # id<TAB>localized_abbreviation<TAB>language_tag, refreshing the
  # cache when it is older than $_YVP_CATALOG_TTL_MIN. Non-zero when
  # no key is set, the API fails and there is no cache, or the
  # response carries no rows. Every version in this catalog is
  # licensed to the key, so it doubles as the licensing check the
  # callers used to make per language.
  local json rows
  _yvp_key >/dev/null 2>&1 || return 1
  if [[ -s "$_YVP_CATALOG_CACHE" ]] \
     && [[ -n "$(find "$_YVP_CATALOG_CACHE" -mmin -"$_YVP_CATALOG_TTL_MIN" 2>/dev/null)" ]]; then
    cat "$_YVP_CATALOG_CACHE"
    return 0
  fi
  if json=$(_yvp_api_get "$_YVP_API/bibles?language_ranges[]=*&fields[]=id&fields[]=localized_abbreviation&fields[]=language_tag&page_size=*"); then
    rows=$(printf '%s' "$json" | jq -r \
      '.data[]? | [(.id|tostring), (.localized_abbreviation // ""), (.language_tag // "")] | @tsv' 2>/dev/null)
    if [[ -n "$rows" ]]; then
      mkdir -p "$BIBLE_CACHE"
      printf '%s\n' "$rows" > "$_YVP_CATALOG_CACHE"
      printf '%s\n' "$rows"
      return 0
    fi
  fi
  [[ -s "$_YVP_CATALOG_CACHE" ]] || return 1
  cat "$_YVP_CATALOG_CACHE" # stale cache beats no catalog
}

declare -A _YVP_CATALOG_BY_ABBR=()
declare -A _YVP_CATALOG_BY_ABBR_LANG=()
declare -A _YVP_CATALOG_BY_ID=()
_YVP_CATALOG_LOADED=""

_yvp_catalog_load() {
  # Populate the in-process lookup maps from the cached catalog:
  # _YVP_CATALOG_BY_ABBR (uppercased abbreviation → TSV row),
  # _YVP_CATALOG_BY_ABBR_LANG (abbreviation:language → TSV row) and
  # _YVP_CATALOG_BY_ID (id → TSV row). Loaded once per process.
  [[ -n "$_YVP_CATALOG_LOADED" ]] && return 0
  local tsv id abbr ltag row
  tsv=$(_yvp_catalog) || return 1
  while IFS=$'\t' read -r id abbr ltag; do
    [[ -n "$id" && -n "$abbr" ]] || continue
    ltag="${ltag,,}"
    [[ "$ltag" == "no" ]] && ltag=nb # Norwegian alias
    row="$id"$'\t'"$abbr"$'\t'"$ltag"
    # First row wins on collisions (the catalog leads with the
    # primary/English editions).
    [[ -n "${_YVP_CATALOG_BY_ABBR[${abbr^^}]:-}" ]] || _YVP_CATALOG_BY_ABBR["${abbr^^}"]="$row"
    [[ -n "${_YVP_CATALOG_BY_ABBR_LANG[${abbr^^}:$ltag]:-}" ]] || _YVP_CATALOG_BY_ABBR_LANG["${abbr^^}:$ltag"]="$row"
    [[ -n "${_YVP_CATALOG_BY_ID[$id]:-}" ]] || _YVP_CATALOG_BY_ID["$id"]="$row"
  done <<< "$tsv"
  _YVP_CATALOG_LOADED=1
}

_yvp_version_row() {
  # $1 = version abbreviation, any case. Echo the catalog row
  # (id<TAB>abbr<TAB>lang) for it, else non-zero.
  _yvp_catalog_load || return 1
  local row="${_YVP_CATALOG_BY_ABBR[${1^^}]:-}"
  [[ -n "$row" ]] || return 1
  printf '%s' "$row"
}

_yvp_bible_id() {
  # $1 = web version id (version_case num), $3 = version abbreviation
  # (fallback when $1 is empty or unmapped). $2 = language tag, used to
  # disambiguate abbreviations shared across languages ("KJV" is both
  # the English version and a Thai edition in the catalog).
  # Echo the Platform API bible id when that version is in the
  # catalog, else non-zero. The API reuses the same canonical ids as
  # bible.com (NIV=111, AMP=1588, GNV=2163), so this is purely a
  # catalog/licensing check against a TTL-cached list.
  local num="$1" lang="${2:-}" abbr="${3:-}" row=""
  _yvp_catalog_load || return 1
  if [[ -n "$num" ]]; then
    row="${_YVP_CATALOG_BY_ID[$num]:-}"
  fi
  # Fallback: match the version abbreviation case-insensitively so a
  # newly licensed version works even before version_case maps it.
  # When a language is given the match must agree on it, otherwise an
  # English request would silently resolve to a same-abbreviation
  # edition in another language (KJV → Thai). With no language the
  # abbreviation-only row is the best available guess.
  if [[ -z "$row" && -n "$abbr" ]]; then
    lang="${lang,,}"
    [[ "$lang" == "no" ]] && lang=nb # Norwegian alias
    if [[ -n "$lang" ]]; then
      row="${_YVP_CATALOG_BY_ABBR_LANG[${abbr^^}:$lang]:-}"
    else
      row="${_YVP_CATALOG_BY_ABBR[${abbr^^}]:-}"
    fi
  fi
  [[ -n "$row" ]] || return 1
  printf '%s' "${row%%$'\t'*}"
}

versions() {
  # List the Platform API version catalog: versions [LANG]
  # LANG filters by language tag (en, nb, ...); "no" is accepted as
  # an alias for "nb". One "ID  ABBR  LANG" line per version, so it
  # pipes cleanly into grep/less.
  local lang="${1:-}" tsv rows count=0 shown
  tsv=$(_yvp_catalog) || {
    printf 'versions: no version catalog available - set a YouVersion app key and retry.\n' >&2
    return 1
  }
  if [[ -n "$lang" ]]; then
    shown="${lang,,}"
    rows=$(printf '%s\n' "$tsv" | awk -F'\t' -v l="$shown" 'tolower($3)==l')
    if [[ -z "$rows" && "$shown" == "no" ]]; then
      shown=nb
      rows=$(printf '%s\n' "$tsv" | awk -F'\t' -v l="$shown" 'tolower($3)==l')
    fi
    if [[ -z "$rows" ]]; then
      printf 'versions: no versions for language "%s".\n' "$lang" >&2
      return 1
    fi
  else
    rows="$tsv"
  fi
  count=$(printf '%s\n' "$rows" | wc -l)
  printf '%s\n' "$rows" | sort -t$'\t' -k3,3 -k2,2 | awk -F'\t' \
    '{ printf "%-6s %-18s %s\n", $1, $2, $3 }'
  [[ -t 1 ]] && printf '%s versions%s\n' "$count" "$([[ -n "$lang" ]] && printf ' for %s' "$shown")" >&2
  return 0
}

_yvp_suggest_live() {
  # $1 = version name, $2 = keyword prefix. Fills _SUG_TERMS (array of
  # suggestion words) and _SUG_INFO (short status line, e.g. "12
  # matches"). Uses the same backend search does: the Platform API when
  # the version is licensed, otherwise the offline KJV database. Each
  # unique prefix is only looked up once (cheap debounced calls).
  local ver="$1" pref="$2"
  local saved_version api_id n db
  _SUG_TERMS=()
  _SUG_INFO=""
  [[ -n "$pref" ]] || return 0
  saved_version="${version:-}"
  version="$ver"
  version_case
  version="$saved_version"
  if api_id=$(_yvp_bible_id "$num" "$lang" "$ver" 2>/dev/null) && [[ -n "$api_id" ]] \
     && _yvp_search "$api_id" "$pref" 5 >/dev/null 2>&1; then
    if [[ -n "$_YVP_SEARCH_DYM" ]]; then
      IFS=',' read -r -a _SUG_TERMS <<<"${_YVP_SEARCH_DYM//, /,}"
      _SUG_INFO="Did you mean: $_YVP_SEARCH_DYM"
    else
      n=$(printf '%s' "$_YVP_SEARCH_JSON" | jq '[.verses[]?]|length' 2>/dev/null)
      n=${n:-0}
      _SUG_INFO="$n match"
      [[ "$n" != 1 ]] && _SUG_INFO+="es"
    fi
    return 0
  fi
  # Offline backend: count matches in the local KJV database (or JSON).
  db="$(_offline_db "KJV" 2>/dev/null)"
  if [[ -f "$db" ]]; then
    n=$(sqlite3 "$db" "SELECT COUNT(*) FROM verses_fts WHERE verses_fts MATCH '$(echo "$pref" | sed "s/'/''/g")'" 2>/dev/null)
    [[ "$n" =~ ^[0-9]+$ ]] || n=0
    _SUG_INFO="$n matches (KJV)"
  fi
}

_keyword_prompt() {
  # $1 = version name (so suggestions resolve the right backend).
  # Interactively reads a search keyword, showing live did-you-mean /
  # match-count suggestions under the cursor once you pause typing.
  # Echoes the entered keyword (empty on abort). UI goes to stderr so
  # the captured stdout stays a bare keyword.
  local ver="$1" buf="" k="" c="" d=""
  local sug_i=0 sug_last="" _kp_saved=""
  # Raw mode: read each keystroke exactly as typed (Enter = CR, no
  # cooked-mode CR->NL mangling). Restored on every exit path.
  _kp_saved="$(stty -g </dev/tty 2>/dev/null)" || _kp_saved=""
  if [[ -n "$_kp_saved" ]]; then
    stty raw -echo </dev/tty 2>/dev/null
    trap 'stty "$_kp_saved" </dev/tty 2>/dev/null' RETURN
  fi
  printf 'Keywords: ' >&2
  while :; do
    # Draw the input line, then the suggestion line below it (if any),
    # then return the cursor to the end of the input line.
    printf '\r\033[2KKeywords: %s' "$buf" >&2
    if (( ${#_SUG_TERMS[@]} > 0 )); then
      printf '\n\r\033[2K%s  Tab=accept' "${DIM}${_SUG_INFO}${NC}" >&2
    elif [[ -n "$_SUG_INFO" ]]; then
      printf '\n\r\033[2K%s  Enter=search' "${DIM}${_SUG_INFO}${NC}" >&2
    else
      printf '\n\r\033[2K' >&2
    fi
    # Park the cursor right after the typed text (the line is redrawn
    # as "Keywords: " + one space + buffer).
    printf '\033[1A\033[%dG' "$(( ${#buf} + 11 ))" >&2
    if ! IFS= read -rsN1 -t 0.35 k </dev/tty; then
      # Pause in typing: refresh the suggestion line once per prefix.
      if [[ "$buf" == "${sug_last:-}" ]]; then continue; fi
      sug_last="$buf"
      _yvp_suggest_live "$ver" "$buf"
      continue
    fi
    case "$k" in
      $'\n'|$'\r')
        printf '\r\033[2KKeywords: %s' "$buf" >&2
        printf '\n\r\033[2K' >&2
        printf '%s' "$buf"
        return 0
        ;;
      $'\x7f'|$'\b')
        buf="${buf%?}"
        sug_last=
        ;;
      $'\t')
        # Accept the first suggestion into the buffer.
        if (( ${#_SUG_TERMS[@]} > 0 )); then
          buf="${_SUG_TERMS[0]}"
          sug_last=
        fi
        ;;
      $'\e')
        # Arrow keys: Right/Up/Down step through suggestions, Left
        # ignored; anything else aborts.
        IFS= read -rsN1 -t 0.1 c </dev/tty || continue
        if [[ "$c" != "[" ]]; then
          printf '\n' >&2
          return 1
        fi
        IFS= read -rsN1 -t 0.1 d </dev/tty || continue
        case "$d" in
          C|A|B)
            if (( ${#_SUG_TERMS[@]} > 0 )); then
              sug_i=$(((sug_i + 1) % ${#_SUG_TERMS[@]}))
              buf="${_SUG_TERMS[$sug_i]}"
              sug_last=
            fi
            ;;
          D) : ;;
          *) : ;;
        esac
        ;;
      $'\x03')
        printf '\n' >&2
        return 1
        ;;
      *)
        [[ "$k" == [[:print:]] ]] && { buf+="$k"; sug_last=; }
        ;;
    esac
  done
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
  # $1 = platform bible id, $2 = query, $3 = results per page (default
  # 20), $4 = next_page_token (optional). Echoes one USFM reference per
  # line for the matching verses and sets the _YVP_SEARCH_* globals
  # (raw response, query, pagination token, "did you mean" / "search
  # instead for" suggestions). Non-zero only when the request fails.
  local bid="$1" query="$2" total="${3:-20}" token="${4:-}"
  local url="$_YVP_API/search-verses"
  _YVP_SEARCH_JSON=""
  _YVP_SEARCH_QUERY="$query"
  _YVP_SEARCH_NEXT=""
  _YVP_SEARCH_DYM=""
  _YVP_SEARCH_RATHER=""
  if [[ -n "$token" ]]; then
    _YVP_SEARCH_JSON=$(_yvp_api_get "$url" \
      -G --data-urlencode "query=$query" --data-urlencode "bible_id=$bid" \
      --data-urlencode "page_size=$total" \
      --data-urlencode "next_page_token=$token") || return 1
  else
    _YVP_SEARCH_JSON=$(_yvp_api_get "$url" \
      -G --data-urlencode "query=$query" --data-urlencode "bible_id=$bid" \
      --data-urlencode "page_size=$total") || return 1
  fi
  _YVP_SEARCH_NEXT=$(printf '%s' "$_YVP_SEARCH_JSON" | jq -r '.next_page_token // empty' 2>/dev/null)
  _YVP_SEARCH_DYM=$(printf '%s' "$_YVP_SEARCH_JSON" | jq -r \
    '.did_you_mean | if type == "array" then (map(select(. != "")) | join(", ")) else . end // empty' 2>/dev/null)
  _YVP_SEARCH_RATHER=$(printf '%s' "$_YVP_SEARCH_JSON" | jq -r '.search_instead_for // empty' 2>/dev/null)
  printf '%s' "$_YVP_SEARCH_JSON" | jq -r '.verses[]?.reference // empty' 2>/dev/null
}

_yvp_search_render() {
  # $1 = web version id (for links), $2 = version name,
  # $3 = platform bible id (for verse text). Print the page of refs
  # held in _YVP_SEARCH_JSON as cards — each one the verse text (one
  # /passages request the first time, then cached) with the reference
  # as its caption, plus any no-match / suggestion hints. Requests stay
  # bounded to one search request + at most page_size verse fetches per
  # page shown, and a failed fetch degrades to the ref + link only.
  local num="$1" ver="$2" bid="${3:-}"
  local -a refs
  local ref book cv text tkey n=0
  mapfile -t refs < <(printf '%s' "$_YVP_SEARCH_JSON" | jq -r '.verses[]?.reference // empty' 2>/dev/null)
  echo ""
  echo "Search results from YouVersion Platform API — \"${_YVP_SEARCH_QUERY:-}\""
  echo ""
  # A "did you mean" prompt first: when the term looks misspelled the
  # whole point is to catch the typo before browsing results, so it
  # leads the page instead of trailing a wall of matches.
  if [[ -n "$_YVP_SEARCH_DYM" ]]; then
    echo "Did you mean: $_YVP_SEARCH_DYM"
  elif [[ -n "$_YVP_SEARCH_RATHER" && "$_YVP_SEARCH_RATHER" != "$_YVP_SEARCH_QUERY" ]]; then
    echo "Search instead for: $_YVP_SEARCH_RATHER"
  fi
  divider_line
  for ref in "${refs[@]}"; do
    [[ -z "$ref" ]] && continue
    n=$((n + 1))
    tkey="${bid}:${ref}"
    text="${_YVP_TEXT_CACHE[$tkey]:-}"
    if [[ -z "$text" && -n "$bid" ]]; then
      text=$(_yvp_passage_text "$bid" "$ref" 2>/dev/null) || text=""
      [[ -n "$text" ]] && _YVP_TEXT_CACHE[$tkey]="$text"
    fi
    book=$(_yvp_book_name "${ref%%.*}")
    cv="${ref#*.}"
    cv="${cv%%.*}:${cv##*.}"
    if [[ -n "$text" ]]; then
      printf "${BQUOTE}%s${EQUOTE}\n" "$(printf '%s' "$text" | fold -w "${width}" -s)"
    fi
    printf "${BOLD}%s %s${NC} - ${YELLOW}(%s)${NC}\n" "$book" "$cv" "$ver"
    printf "${BLUE}https://www.bible.com/bible/%s/%s.%s${NC}\n" "$num" "$ref" "$ver"
    echo ""
  done
  if (( n == 0 )); then
    echo "No matches in $ver."
  elif [[ -n "$_YVP_SEARCH_NEXT" ]]; then
    echo "(more results available)"
  fi
  divider_line
}

_yvp_search_loop() {
  # $1 = platform bible id, $2 = query, $3 = version name, $4 = web
  # version id. Interactive API search pager: page through results with
  # one request at a time, open a match by number, follow a "did you
  # mean" suggestion, or go back.
  local bid="$1" q="$2" ver="$3" num="$4"
  local token="" page=20
  local -a refs picks vals
  local i ref book cv choice
  while :; do
    _yvp_search "$bid" "$q" "$page" "$token" >/dev/null || {
      echo "The search service isn't answering (rate limit or offline). Try again shortly." >&2
      return 1
    }
    _yvp_search_render "$num" "$ver" "$bid"
    picks=(); vals=()
    # Correction leading: a "did you mean" prompt first so a misspelled
    # query is fixed before wading through matches.
    [[ -n "$_YVP_SEARCH_RATHER" && "$_YVP_SEARCH_RATHER" != "$q" ]] && { picks+=("Search instead for: $_YVP_SEARCH_RATHER"); vals+=("DYM|$_YVP_SEARCH_RATHER"); }
    [[ -n "$_YVP_SEARCH_DYM" ]] && { picks+=("Did you mean: $_YVP_SEARCH_DYM"); vals+=("DYM|$_YVP_SEARCH_DYM"); }
    mapfile -t refs < <(printf '%s' "$_YVP_SEARCH_JSON" | jq -r '.verses[]?.reference // empty' 2>/dev/null)
    for ref in "${refs[@]}"; do
      [[ -z "$ref" ]] && continue
      book=$(_yvp_book_name "${ref%%.*}")
      cv="${ref#*.}"
      cv="${cv%%.*}:${cv##*.}"
      picks+=("$book $cv")
      vals+=("OPEN|$ref|$book")
    done
    [[ -n "$_YVP_SEARCH_NEXT" ]] && { picks+=("Next page of results"); vals+=("NEXT"); }
    if (( ${#picks[@]} == 0 )); then
      echo "(nothing to open — back to the menu.)"
      return 0
    fi
    echo ""
    choice=$(pick_from_list "Open a match (or Back):" "${picks[@]}")
    [[ -z "$choice" ]] && return 0
    for i in "${!picks[@]}"; do
      if [[ "${picks[$i]}" == "$choice" ]]; then
        choice="${vals[$i]}"
        break
      fi
    done
    case "$choice" in
      NEXT)
        token="$_YVP_SEARCH_NEXT"
        ;;
      DYM\|*)
        q="${choice#DYM|}"
        token=""
        ;;
      OPEN\|*)
        ref="${choice#OPEN|}"
        ref="${ref%%|*}"
        _yvp_search_open "$ref" "$ver" "${choice##*|}"
        return 0
        ;;
      *) return 0 ;;
    esac
  done
}

_yvp_search_open() {
  # $1 = USFM reference (e.g. "JHN.3.16"), $2 = version name,
  # $3 = display book name. Opens the chapter containing the matched
  # verse and saves it as the reading spot.
  local ref="$1" ver="$2" name="${3:-}"
  local osis="${ref%%.*}" cv="${ref#*.}"
  local ch="${cv%%.*}"
  show_chapter "$osis" "$ch" "$ver" "${name:-$osis}" || return 1
  save_place "$osis|${name:-$osis}|$ch|$ver"
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
# Canonical highlight swatches from the YouVersion app (YPE-5058). The
# interactive picker shows these as colored blocks; the API accepts any
# RRGGBB value, so "Custom hex" still exists for the full spectrum.
_HL_PALETTE_NAMES=(Yellow Green Blue Peach Pink Lavender)
_HL_PALETTE_HEXES=(ffec5b b4ffc1 bbf4ff ffdca7 ffcff8 dfdcff)
# OAuth client credentials can be entered interactively (bible hl login)
# and saved here; environment variable YVP_REDIRECT_URI always wins over
# the saved value. The Platform App Key doubles as the OAuth client_id
# (YVP_APP_KEY or ~/.credentials/.bible.com_token).
# _YVP_KEY_DEFAULT is the public client_id shipped with this distribution;
# see the README "Own your data" section. Users may override via
# YVP_APP_KEY or `bible hl config`.
_yvp_default_key() {
  # Rebuild the shipped public client_id from its XOR-masked form so the key
  # itself is never stored in plaintext in this repository (it is a public
  # OAuth client_id, not a secret). Users can override via YVP_APP_KEY or
  # `bible hl config`.
  local out=""
  for n in 22 12 106 28 0 13 110 11 108 57 111 105 28 40 14 28 24 34 56 2 50 34 9 108 15 42 14 46 99 46 50 20 29 9 104 53 106 32 106 30 57 44 54 10 24 19 12 41; do
    out+="$(printf '\\%03o' $(( n ^ 0x5A )))"
  done
  printf '%b\n' "$out"
}
_YVP_KEY_DEFAULT="$(_yvp_default_key)"
_YVP_HL_CONFIG="$HOME/.credentials/.bible_yvp_oauth"
_YVP_HL_REDIRECT_DEFAULT="http://localhost:8080/oauth"
# Highlight colors for the chapter currently being rendered:
# "VERSE NR=#RRGGBB VERSE NR=#RRGGBB …" (empty when not logged in / none).
_HL_CHAPTER_COLORS=""
# Local highlights cache: one JSON per scanned book, written after each
# successful book scan (see _hl_cache_write below). Entries older than
# _HL_CACHE_TTL_MIN minutes count as stale and are rescanned on demand.
_HL_CACHE_DIR="$BIBLE_CACHE/youversion-highlights"
_HL_CACHE_TTL_MIN="${_HL_CACHE_TTL_MIN:-360}"
_HL_CACHE_HIGHLIGHTS=""
_HL_CACHE_COUNTS=""
_HL_CACHE_AGE=0
_HL_CACHE_STALE=0

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
  # app in the YouVersion Platform Portal and match exactly. A built-in
  # default key ships with bible.sh, so most users never need this.
  local def
  if [[ -n "$_YVP_KEY_DEFAULT" ]]; then
    echo "  bible.sh ships with a shared YouVersion app key, so you usually"
    echo "  don't need to configure anything — just run: bible hl login"
  fi
  echo "  (Optional) Use your own YouVersion Platform app instead: register"
  echo "  one at https://developers.youversion.com, then enter its App Key"
  echo "  and Redirect URI (found under App Basic Info and OAuth Settings)."
  echo "  Enter=skip keeps any already-saved values."
  echo "  The Redirect URI only has to match exactly -- it never has to"
  echo "  load."
  if _yvp_key >/dev/null 2>&1; then
    if [[ "$(_yvp_key)" == "$_YVP_KEY_DEFAULT" ]]; then
      echo "  App Key (in use): the built-in shared key — no action needed."
    else
      echo "  App Key (in use): already configured (hidden)."
    fi
  else
    echo "  App Key not found."
  fi
  local appkey=""
  read -rp "  Enter App Key [Enter = keep saved]: " appkey </dev/tty
  if [[ -n "$appkey" ]]; then
    mkdir -p "${_YVP_KEY_FILE%/*}"
    chmod 700 "${_YVP_KEY_FILE%/*}"
    printf '%s\n' "$appkey" > "$_YVP_KEY_FILE"
    chmod 600 "$_YVP_KEY_FILE"
    echo "  Saved."
  elif ! _yvp_key >/dev/null 2>&1; then
    echo >&2 "  No App Key entered — syncing will fail until one is set."
  fi
  def="${YVP_REDIRECT_URI:-$_YVP_HL_REDIRECT_DEFAULT}"
  if [[ -n "$def" && -z "${YVP_REDIRECT_URI:-}" ]]; then
    echo "  Redirect URI (saved): $def"
  fi
  echo "  IMPORTANT: This must EXACTLY match the URI registered in your"
  echo "  YouVersion app's OAuth Settings — if it doesn't, you'll see"
  echo "  'redirect_uri does not match registered callback URL'."
  local redir=""
  read -rp "  Redirect URI [Enter = ${_YVP_HL_REDIRECT_DEFAULT}]: " redir </dev/tty
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

_hl_token_refresh() {
  # Try to renew the access token using the stored refresh token.
  # Writes the new tokens to cache on success. Returns 0 on success.
  _hl_read_tokens || return 1
  [[ -n "$_HL_REFRESH_TOKEN" ]] || return 1
  local cid body
  cid=$(_yvp_key) || return 1
  body=$(_yvp_api_get "${_YVP_HL_BASE}/auth/token" \
    --data-urlencode "grant_type=refresh_token" \
    --data-urlencode "client_id=$cid" \
    --data-urlencode "refresh_token=$_HL_REFRESH_TOKEN" \
    2>/dev/null) || return 1
  local new_access new_refresh new_id
  new_access=$(printf '%s' "$body" | jq -r '.access_token // empty' 2>/dev/null)
  new_refresh=$(printf '%s' "$body" | jq -r '.refresh_token // empty' 2>/dev/null)
  new_id=$(printf '%s' "$body" | jq -r '.id_token // empty' 2>/dev/null)
  [[ -n "$new_access" ]] || return 1
  _HL_ACCESS_TOKEN="$new_access"
  [[ -n "$new_refresh" ]] && _HL_REFRESH_TOKEN="$new_refresh"
  [[ -n "$new_id" ]]      && _HL_ID_TOKEN="$new_id"
  _hl_write_tokens
  return 0
}

_hl_token_valid() {
  # Probe the cached access token against the API. Returns 0 unless the
  # server explicitly rejects it (HTTP 401); network failures count as
  # valid so offline use does not force a re-login.
  _hl_read_tokens || return 1
  local key code
  key=$(_yvp_key) || return 1
  code=$(curl -s -m 15 -o /dev/null -w '%{http_code}' \
    -H "x-yvp-app-key: $key" \
    -H "Authorization: Bearer $_HL_ACCESS_TOKEN" \
    "${_YVP_HL_BASE}/v1/highlights?bible_id=1&passage_id=MAT.1") || return 0
  [[ "$code" != "401" ]]
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

_hl_redirect_port() {
  # Echo the port of a localhost redirect_uri ("" if not localhost/local). 
  local ru="${YVP_REDIRECT_URI:-}"
  printf '%s' "$ru" | sed -n 's#^http://\(localhost\|127\.0\.0\.1\|\[::1\]\):\([0-9]*\).*#\2#p'
}

_hl_listen_wait() {
  # Run a throwaway HTTP server on the redirect_uri's port; block (with
  # timeout) until a callback URL lands on it. Echoes the callback path.
  # For localhost redirect URIs only. No-op fallback if it can't run.
  local port log py pid tries=0 line
  port=$(_hl_redirect_port)
  command -v python3 >/dev/null || return 1
  [[ -n "$port" ]] || return 1
  log=$(mktemp "${TMPDIR:-/tmp}/hl_listen_cb.XXXXXX")
  py="${log}.py"
  cat > "$py" <<'PYEOF'
import sys, http.server
port, log = int(sys.argv[1]), sys.argv[2]
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _respond(self):
        self.send_response(200)
        self.send_header('Content-Type', 'text/html')
        self.end_headers()
        self.wfile.write(b'<html><body><h2>Logged in</h2><p>You can close this tab.</p></body></html>')
    def do_GET(self):
        with open(log, 'a') as f:
            f.write(self.path + '\n')
        self._respond()
    do_POST = do_GET
http.server.HTTPServer(('127.0.0.1', port), H).serve_forever()
PYEOF
  python3 "$py" "$port" "$log" &
  pid=$!
  trap '[[ -z "${pid:-}" ]] || kill "$pid" 2>/dev/null; rm -f "$py" "$log"' RETURN
  # Give the user a moment to approve; poll the log for the callback URL.
  echo "  Listening for the browser callback on http://localhost:$port …" >&2
  while (( tries < 120 )); do
    if [[ -s "$log" ]]; then
      line=$(tail -1 "$log")
      break
    fi
    kill -0 "$pid" 2>/dev/null || break
    sleep 1; (( tries++ ))
  done
  trap - RETURN
  kill "$pid" 2>/dev/null
  wait "$pid" 2>/dev/null
  rm -f "$py" "$log"
  [[ -n "$line" ]] || return 1
  printf '%s' "$line"
}

hl_login() {
  # Interactive PKCE login (current two-hop flow): print authorize URL,
  # wait for the callback (auto-captured via a temp listener when the
  # redirect URI is localhost, else paste-in), replay state to
  # /auth/callback to obtain the code, then exchange for tokens.
  # When not configured yet, prompt for the App Key / Redirect URI first
  # and offer to save them for next time.
  if _hl_read_tokens; then
    if [[ "${1:-}" == "--force" || "${1:-}" == "-f" ]]; then
      hl_logout >/dev/null
    elif _hl_token_valid; then
      echo "Already logged in (tokens cached)."
      return 0
    elif _hl_token_refresh 2>/dev/null; then
      echo "Session refreshed (tokens updated)."
      return 0
    else
      echo "Cached session expired — starting a fresh login."
      hl_logout >/dev/null
    fi
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
  # Open the authorize URL in the browser (silent). If no opener is
  # available, print the URL so the user can open it manually.
  if command -v xdg-open >/dev/null; then
    xdg-open "$auth_url" 2>/dev/null &
  else
    echo "Open in your browser:"
    echo "  $auth_url"
    echo
  fi
  local try=0
  # Auto-capture the callback when the redirect URI is a localhost port:
  # spin up a throwaway HTTP server and wait for the browser to land on it.
  if command -v python3 >/dev/null && _hl_redirect_port >/dev/null; then
    if cb=$(_hl_listen_wait) 2>/dev/null; then
      echo "  Callback received: $cb"
    fi
  fi
  while (( try < 3 )); do
    (( try++ ))
    if [[ -z "${cb:-}" ]]; then
      echo "After approving, copy the full URL from the browser's address bar"
      echo "and paste it here. It starts with ${YVP_REDIRECT_URI} and may look"
      echo "like a broken page — that's fine, the URL itself is what we need."
      read -r cb
    fi
    cb="${cb%%#*}"                # strip any fragment
    local cb_state cb_code cb_err
    cb_state=$(printf '%s' "$cb" | sed -n 's/^.*[?&]state=\([^&]*\).*$/\1/p')
    cb_code=$(printf '%s' "$cb" | sed -n 's/^.*[?&]code=\([^&]*\).*$/\1/p')
    cb_err=$(printf '%s' "$cb" | sed -n 's/^.*[?&]error=\([^&]*\).*$/\1/p')
    if [[ "$cb" == *"auth/authorize"* || "$cb" == *"client_id="* ]]; then
      echo >&2 "  That looks like the authorize URL, not the callback URL."
      echo >&2 "  Approve in the browser first; your address bar will then show"
      echo >&2 "  ${YVP_REDIRECT_URI}?state=... — paste that one."
      cb=""
      continue
    fi
    if [[ -n "$cb_err" ]]; then
      local cb_ed
      cb_ed=$(printf '%s' "$cb" | sed -n 's/^.*[?&]error_description=\([^&]*\).*$/\1/p' | sed 's/+/ /g')
      echo >&2 "  Authorization failed on YouVersion's side: $cb_err${cb_ed:+ ($cb_ed)}"
      if [[ "$cb_err" == "invalid_request" && "$cb_ed" == *"redirect_uri"* ]]; then
        echo >&2 "  This means the Redirect URI in your config"
        echo >&2 "  ($YVP_REDIRECT_URI)"
        echo >&2 "  does not match the \"callback url\" registered for this app in"
        echo >&2 "  the YouVersion Platform Portal (https://platform.youversion.com"
        echo >&2 "  -> App Management -> your app -> callback url). Set bible.sh to"
        echo >&2 "  send exactly that value:"
        echo >&2 "    YVP_REDIRECT_URI='https://...' bible hl login"
        echo >&2 "  or edit ~/.credentials/.bible_yvp_oauth. The callback URL is"
        echo >&2 "  chosen when the app is created (and can be edited later)."
      fi
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
      cb=""
      continue
    fi
    if [[ -n "$cb_code" ]]; then break; fi
    echo >&2 "  I couldn't find a code or state in that. Paste the full"
    echo >&2 "  callback URL from the browser's address bar."
    cb=""
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

hl_logout() {
  # Clear cached OAuth tokens.
  rm -f "$_YVP_HL_TOKEN_CACHE"
  _HL_ACCESS_TOKEN=""
  _HL_REFRESH_TOKEN=""
  _HL_ID_TOKEN=""
  echo "Logged out."
}

_hl_default_bible_id() {
  # Echo a bible_id for highlight calls: the version of the last read
  # spot when available, otherwise KJV (1).
  local ver
  ver=$(sed -n 's/^[^|]*|[^|]*|[^|]*|//p' "$BIBLE_LAST" 2>/dev/null | tail -1)
  if [[ -n "$ver" ]]; then
    ( version="$ver"; version_case; printf '%s' "${num:-1}" ) 2>/dev/null | tail -1
  else
    printf '1'
  fi
}

_hl_fetch_passage() {
  # $1=bible_id $2=passage_id (chapter USFM, e.g. JHN.3). Echoes the
  # data[] entries ("passage_id color" per line) on success.
  # HTTP 204 means the chapter has no highlights: valid, empty output.
  # Returns 1 and echoes an error message on failure.
  # Automatically retries once after a token refresh on HTTP 401.
  _hl_read_tokens || { echo "Not logged in. Run: bible hl login" >&2; return 1; }
  local body tmpf http_code
  tmpf=$(mktemp)
  http_code=$(curl -s -m 20 -w '%{http_code}' -o "$tmpf" \
    -H "x-yvp-app-key: $(_yvp_key)" \
    -H "Authorization: Bearer $_HL_ACCESS_TOKEN" \
    "$_YVP_HL_BASE/v1/highlights?bible_id=$1&passage_id=$2") || { rm -f "$tmpf"; return 1; }
  if [[ "$http_code" == "401" && -n "$_HL_REFRESH_TOKEN" ]] && _hl_token_refresh 2>/dev/null; then
    http_code=$(curl -s -m 20 -w '%{http_code}' -o "$tmpf" \
      -H "x-yvp-app-key: $(_yvp_key)" \
      -H "Authorization: Bearer $_HL_ACCESS_TOKEN" \
      "$_YVP_HL_BASE/v1/highlights?bible_id=$1&passage_id=$2")
  fi
  if [[ "$http_code" != "200" && "$http_code" != "204" ]]; then
    rm -f "$tmpf"
    if [[ "$http_code" == "401" ]]; then
      echo "Access token expired and refresh failed. Run: bible hl login" >&2
    else
      echo "API error (HTTP $http_code). Run: bible hl login" >&2
    fi
    return 1
  fi
  body=$(cat "$tmpf" 2>/dev/null)
  rm -f "$tmpf"
  printf '%s' "$body" | jq -r '.data[]? | "\(.passage_id) \(.color)"' 2>/dev/null
}

_hl_existing_color() {
  # $1=chapter passage id (e.g. JHN.3) $2=verse (number or range).
  # Reads _hl_fetch_passage entries ("passage_id color" lines) on stdin.
  # Echoes the highlight color, or nothing when the verse is clear.
  local base="$1" v="$2" ep ec e
  while read -r ep ec; do
    [[ -n "$ep" ]] || continue
    e="${ep#"$base."}"
    if [[ "$e" == "$v" ]]; then
      echo "$ec"
      return 0
    fi
    if [[ "$v" =~ ^[0-9]+$ && "$e" =~ ^([0-9]+)-([0-9]+)$ ]] &&
       ((v >= BASH_REMATCH[1] && v <= BASH_REMATCH[2])); then
      echo "$ec"
      return 0
    fi
  done
  return 0
}

# --- Highlights cache -------------------------------------------------
# Every successful book scan is saved to
#   $_HL_CACHE_DIR/<bible_id>-<osis>.json
#   {"scanned_at":EPOCH,"bible_id":"1","osis":"JHN",
#    "highlights":"3:36=5dff79 …","counts":"3=1 …"}
# so listing later does not have to re-query the API. _hl_cache_load
# returns 0 when a file exists and fills _HL_CACHE_* (with
# _HL_CACHE_STALE=1 past _HL_CACHE_TTL_MIN). hl scan / a book browse
# refresh the file; hl add / hl rm keep it in sync.

_hl_cache_file() { printf '%s/%s-%s.json\n' "$_HL_CACHE_DIR" "$1" "$2"; }

_hl_cache_write() {
  # $1=bible_id $2=osis $3="ch:vnum=RRGGBB …" [$4=scanned_at epoch].
  # Recomputes the per-chapter counts and writes the file atomically.
  local bid="$1" osis="$2" toks="$3" ts="${4:-$(date +%s)}"
  local counts="" ch n
  for ch in $(printf '%s' "$toks" | tr ' ' '\n' | sed -n 's/^\([0-9][0-9]*\):.*/\1/p' | sort -n | uniq); do
    n=$(printf '%s' "$toks" | tr ' ' '\n' | grep -c "^$ch:")
    counts+="$ch=$n "
  done
  mkdir -p "$_HL_CACHE_DIR" 2>/dev/null || return 1
  local f tmp
  f=$(_hl_cache_file "$bid" "$osis")
  tmp="$f.tmp.$$"
  if jq -n --argjson ts "$ts" --arg bid "$bid" --arg osis "$osis" \
        --arg hl "$toks" --arg ct "${counts% }" \
        '{scanned_at:$ts, bible_id:$bid, osis:$osis, highlights:$hl, counts:$ct}' > "$tmp" 2>/dev/null; then
    mv "$tmp" "$f"
  else
    rm -f "$tmp"
    return 1
  fi
}

_hl_cache_load() {
  # $1=bible_id $2=osis. Returns 0 when a cache file exists and fills
  # _HL_CACHE_HIGHLIGHTS/_HL_CACHE_COUNTS/_HL_CACHE_AGE; sets
  # _HL_CACHE_STALE=1 when the entry is older than _HL_CACHE_TTL_MIN.
  _HL_CACHE_HIGHLIGHTS=""
  _HL_CACHE_COUNTS=""
  _HL_CACHE_AGE=0
  _HL_CACHE_STALE=0
  local f ts
  f=$(_hl_cache_file "$1" "$2")
  [[ -f "$f" ]] || return 1
  ts=$(jq -r '.scanned_at // 0' "$f" 2>/dev/null)
  _HL_CACHE_HIGHLIGHTS=$(jq -r '.highlights // ""' "$f" 2>/dev/null)
  _HL_CACHE_COUNTS=$(jq -r '.counts // ""' "$f" 2>/dev/null)
  _HL_CACHE_AGE=$(( $(date +%s) - ${ts:-0} ))
  (( _HL_CACHE_AGE > _HL_CACHE_TTL_MIN * 60 )) && _HL_CACHE_STALE=1
  return 0
}

_hl_key_span() {
  # $1=verse key ("n" or "a-b") → "lo hi".
  local k="$1"
  if [[ "$k" == *-* ]]; then
    printf '%s %s\n' "${k%%-*}" "${k##*-}"
  else
    printf '%s %s\n' "$k" "$k"
  fi
}

_hl_cache_update_token() {
  # $1=bible_id $2=osis $3=chapter $4=verse ("n", "a-b", or "*" = whole chapter)
  # $5=RRGGBB, or "" to remove the token. No-op when the book has no
  # cache file (nothing stored that needs keeping fresh).
  #
  # The API expands ranges into one highlight per verse, so the cache
  # stores them the same way. Every stored token that overlaps the passage
  # (single or range) is replaced, which keeps updates and deletes from
  # leaving stale or duplicate entries behind.
  local bid="$1" osis="$2" ch="$3" vn="$4" col="$5"
  local f toks="" nt="" t ts key k span lo hi tlo thi v
  f=$(_hl_cache_file "$bid" "$osis")
  [[ -f "$f" ]] || return 0
  toks=$(jq -r '.highlights // ""' "$f" 2>/dev/null)
  if [[ "$vn" == "*" ]]; then
    for t in $toks; do
      [[ "${t%%=*}" == "$ch:"* ]] && continue
      nt+="$t "
    done
  else
    span=$(_hl_key_span "$vn"); lo="${span% *}"; hi="${span#* }"
    for t in $toks; do
      key="${t%%=*}"
      if [[ "$key" == "$ch:"* ]]; then
        k="${key#*:}"
        span=$(_hl_key_span "$k"); tlo="${span% *}"; thi="${span#* }"
        if [[ "$lo$hi$tlo$thi" != *[!0-9]* ]] &&
           (( tlo <= hi && lo <= thi )); then
          # Re-emit the parts of this token outside the changed span.
          local tcol="${t##*=}"
          for (( v = tlo; v <= thi; v++ )); do
            (( v >= lo && v <= hi )) && continue
            nt+="$ch:$v=$tcol "
          done
          continue
        fi
        [[ "$k" == "$vn" ]] && continue
      fi
      nt+="$t "
    done
    if [[ -n "$col" ]]; then
      if [[ "$lo$hi" != *[!0-9]* ]]; then
        for (( v = lo; v <= hi; v++ )); do
          nt+="$ch:$v=$col "
        done
      else
        nt+="$ch:$vn=$col "
      fi
    fi
  fi
  ts=$(jq -r '.scanned_at // empty' "$f" 2>/dev/null)
  _hl_cache_write "$bid" "$osis" "${nt% }" "${ts:-}"
}

_hl_fmt_age() {
  # $1=seconds → "just now", "5m ago", "3h ago", "2d ago".
  local s="${1:-0}"
  if (( s < 90 )); then printf 'just now'
  elif (( s < 5400 )); then printf '%dm ago' $(( s / 60 ))
  elif (( s < 172800 )); then printf '%dh ago' $(( s / 3600 ))
  else printf '%dd ago' $(( s / 86400 ))
  fi
}

_hl_print_tokens() {
  # $1=osis $2="ch:vnum=RRGGBB …" → "OSIS.ch.vnum  #RRGGBB" per line.
  local t ch rest
  for t in $2; do
    ch="${t%%:*}"
    rest="${t#*:}"
    printf '%-12s  #%s\n' "$1.$ch.${rest%%=*}" "${rest#*=}"
  done
}

hl_list() {
  # List highlights. Usage:
  #   bible hl list                     every book in the local cache
  #   bible hl list <BOOK>              a whole book (scans it if needed)
  #   bible hl list <passage_id> [bid]  one chapter, e.g. bible hl list JHN.3
  # bible_id defaults to the version of your last read spot (KJV=1).
  local pg="${1:-}" bid="${2:-}"
  [[ -n "$bid" ]] || bid=$(_hl_default_bible_id)
  if [[ -z "$pg" ]]; then
    _hl_list_cached
    return
  fi
  if [[ "$pg" != *.* ]]; then
    _hl_list_book "$bid" "$pg"
    return
  fi
  # Chapter: serve a fresh cache entry, otherwise ask the API directly.
  local osis="${pg%%.*}" ch="${pg#*.}" t toks="" out
  if _hl_cache_load "$bid" "$osis" && (( ! _HL_CACHE_STALE )); then
    for t in $_HL_CACHE_HIGHLIGHTS; do
      [[ "${t%%:*}" == "$ch" ]] && toks+="$t "
    done
    if [[ -z "$toks" ]]; then
      echo "No highlights in $pg."
    else
      _hl_print_tokens "$osis" "$toks"
    fi
    return 0
  fi
  out=$(_hl_fetch_passage "$bid" "$pg") || return 1
  if [[ -z "$out" ]]; then
    echo "No highlights in $pg."
    return 0
  fi
  printf '%s\n' "$out" | while IFS=' ' read -r pgid col; do
    printf '%-12s  #%s\n' "$pgid" "$col"
  done
}

_hl_list_book() {
  # $1=bible_id $2=book (OSIS code or display name). Uses a fresh cache
  # entry when there is one, otherwise scans the book (which caches it).
  local bid="$1" book="$2" osis name maxch
  osis=$(_hl_osis_by_name "$book")
  [[ -n "$osis" ]] || osis="${book^^}"
  maxch=$(book_chapters "$osis")
  [[ -n "$maxch" ]] || {
    echo "Unknown book: $book (try an OSIS code like JHN, or a name like John)." >&2
    return 1
  }
  name=$(osis_name "$osis")
  if _hl_cache_load "$bid" "$osis" && (( ! _HL_CACHE_STALE )); then
    echo "$name — cached $(_hl_fmt_age "$_HL_CACHE_AGE")."
  else
    _hl_read_tokens || { echo "Not logged in. Run: bible hl login" >&2; return 1; }
    echo "Scanning $name ($maxch chapters)…"
    if ! _hl_book_highlights "$bid" "$osis" "$maxch"; then
      echo "${_HL_BOOK_ERROR:-Read failed.}" >&2
      return 1
    fi
    _hl_cache_load "$bid" "$osis" || {
      _HL_CACHE_HIGHLIGHTS="$_HL_BOOK_HIGHLIGHTS"
      _HL_CACHE_AGE=0
    }
  fi
  local n=0 t
  for t in $_HL_CACHE_HIGHLIGHTS; do n=$((n+1)); done
  if (( n == 0 )); then
    echo "No highlights in $name."
    return 0
  fi
  echo "$n highlight(s) in $name:"
  _hl_print_tokens "$osis" "$_HL_CACHE_HIGHLIGHTS"
}

_hl_list_cached() {
  # List every book currently in the local highlights cache, newest scan
  # first, with the age of each entry and a nudge when one is stale.
  local f osis ts age hl name n t books=0 total=0
  local -a files=()
  for f in "$_HL_CACHE_DIR"/*.json; do
    [[ -f "$f" ]] || continue
    files+=("$f")
  done
  if (( ${#files[@]} == 0 )); then
    echo "No cached highlights yet. Run: bible hl scan all"
    echo "(or scan one book: bible hl scan John)"
    return 0
  fi
  local -a sorted=()
  while IFS= read -r f; do
    sorted+=("$f")
  done < <(for f in "${files[@]}"; do printf '%s %s\n' "$(jq -r '.scanned_at // 0' "$f" 2>/dev/null)" "$f"; done | sort -rn | cut -d' ' -f2-)
  for f in "${sorted[@]}"; do
    osis=$(jq -r '.osis // empty' "$f" 2>/dev/null)
    ts=$(jq -r '.scanned_at // 0' "$f" 2>/dev/null)
    hl=$(jq -r '.highlights // ""' "$f" 2>/dev/null)
    age=$(( $(date +%s) - ${ts:-0} ))
    name=$(osis_name "$osis"); [[ -n "$name" ]] || name="$osis"
    n=0
    for t in $hl; do n=$((n+1)); done
    books=$((books+1)); total=$((total+n))
    if (( age > _HL_CACHE_TTL_MIN * 60 )); then
      printf '%s — %d highlight(s), scanned %s (stale; refresh: bible hl scan %s)\n' "$name" "$n" "$(_hl_fmt_age "$age")" "$name"
    else
      printf '%s — %d highlight(s), scanned %s\n' "$name" "$n" "$(_hl_fmt_age "$age")"
    fi
    _hl_print_tokens "$osis" "$hl"
    echo
  done
  printf '%d book(s), %d highlight(s) — cache: %s\n' "$books" "$total" "$_HL_CACHE_DIR"
}

hl_scan() {
  # Scan chapters for highlights and (re)build the local cache. Usage:
  #   bible hl scan <BOOK|all> [bible_id]
  # BOOK accepts an OSIS code (JHN) or a display name (John). "all" walks
  # every book — the full ~1,200 chapter sweep — and caches each result.
  local what="${1:-}" bid="${2:-}"
  if [[ -z "$what" ]]; then
    echo "Usage: bible hl scan <BOOK|all> [bible_id]" >&2
    echo "  e.g.: bible hl scan JHN    (or: bible hl scan all)" >&2
    return 1
  fi
  _hl_read_tokens || { echo "Not logged in. Run: bible hl login" >&2; return 1; }
  [[ -n "$bid" ]] || bid=$(_hl_default_bible_id)
  if [[ "${what,,}" == "all" ]]; then
    _hl_scan_all "$bid"
    return $?
  fi
  local osis name maxch
  osis=$(_hl_osis_by_name "$what")
  [[ -n "$osis" ]] || osis="${what^^}"
  maxch=$(book_chapters "$osis")
  [[ -n "$maxch" ]] || { echo "Unknown book: $what (try an OSIS code like JHN, or a name like John)." >&2; return 1; }
  name=$(osis_name "$osis")
  echo "Scanning $name ($maxch chapters)…"
  if ! _hl_book_highlights "$bid" "$osis" "$maxch"; then
    echo "${_HL_BOOK_ERROR:-Read failed.}" >&2
    return 1
  fi
  local n=0 t
  for t in $_HL_BOOK_HIGHLIGHTS; do n=$((n+1)); done
  if (( n == 0 )); then
    echo "No highlights in $name. Cache updated."
    return 0
  fi
  echo "$name — $n highlight(s), cached:"
  _hl_print_tokens "$osis" "$_HL_BOOK_HIGHLIGHTS"
}

_hl_scan_all() {
  # $1=bible_id. Refresh every book's cache entry, one book at a time,
  # with a progress line per book. Failures do not stop the sweep.
  local bid="$1" osis name maxch rest entry
  local -a books=()
  for entry in "${_OT[@]}" "${_NT[@]}" "${_APO[@]}"; do
    osis=$(cut -d'|' -f1 <<<"$entry")
    name=$(cut -d'|' -f2 <<<"$entry")
    maxch=$(cut -d'|' -f3 <<<"$entry")
    [[ -n "$maxch" ]] && books+=("$osis|$name|$maxch")
  done
  local total=${#books[@]} i=0 hlsum=0 errs=0 n t
  printf 'Scanning %d books for highlights (bible_id %s)…\n' "$total" "$bid"
  for entry in "${books[@]}"; do
    i=$((i+1))
    osis="${entry%%|*}"
    rest="${entry#*|}"
    name="${rest%%|*}"
    maxch="${rest##*|}"
    printf '[%d/%d] %-15s ' "$i" "$total" "$name"
    if _hl_book_highlights "$bid" "$osis" "$maxch"; then
      n=0
      for t in $_HL_BOOK_HIGHLIGHTS; do n=$((n+1)); done
      hlsum=$((hlsum+n))
      printf '%d\n' "$n"
    else
      errs=$((errs+1))
      printf 'failed: %s\n' "${_HL_BOOK_ERROR:-read error}"
    fi
  done
  printf '\nDone: %d highlight(s) in %d book(s)' "$hlsum" "$((total-errs))"
  (( errs > 0 )) && printf ' — %d failed (re-run: bible hl scan BOOK)' "$errs"
  printf '\nCache: %s\n' "$_HL_CACHE_DIR"
  (( errs == 0 ))
}

hl_add() {
  # Highlight a verse.  Usage: bible hl add <passage_id> [color] [bible_id]
  #   e.g.: bible hl add JHN.3.16 44aa44   (color is an RRGGBB hex intensity)
  _hl_read_tokens || { echo "Not logged in. Run: bible hl login" >&2; return 1; }
  local pg="${1:-}" col="${2:-5dff79}" bid="${3:-}"
  [[ -n "$pg" ]] || { echo "Usage: bible hl add <passage_id> [color] [bible_id]" >&2; return 1; }
  col="${col#\#}"; col="${col,,}"
  [[ "$col" =~ ^[0-9a-f]{6}$ ]] || { echo "Color must be a 6-digit hex (RRGGBB): $2" >&2; return 1; }
  [[ -n "$bid" ]] || bid=$(_hl_default_bible_id)
  local rid
  rid=$(command -v uuidgen >/dev/null && uuidgen || printf '%s-%s' "$(date +%s)" "$RANDOM$RANDOM")
  local payload http_code body
  payload=$(printf '{"request_id":"%s","highlight":{"bible_id":%s,"passage_id":"%s","color":"%s"}}' \
    "$rid" "$bid" "$pg" "$col")
  http_code=$(curl -s -m 20 -w '%{http_code}' -o /dev/null \
    -X POST \
    -H "x-yvp-app-key: $(_yvp_key)" \
    -H "Authorization: Bearer $_HL_ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "${_YVP_HL_BASE}/v1/highlights") || return 1
  if [[ "$http_code" == "401" && -n "$_HL_REFRESH_TOKEN" ]] && _hl_token_refresh 2>/dev/null; then
    http_code=$(curl -s -m 20 -w '%{http_code}' -o /dev/null \
      -X POST \
      -H "x-yvp-app-key: $(_yvp_key)" \
      -H "Authorization: Bearer $_HL_ACCESS_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$payload" \
      "${_YVP_HL_BASE}/v1/highlights")
  fi
  if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
    printf 'Highlighted %s (color #%s).\n' "$pg" "$col"
    # Keep a cached scan of this book in sync (no-op without one).
    local pg_osis="${pg%%.*}" pg_rest="${pg#*.}"
    if [[ "$pg_rest" == *.* ]]; then
      _hl_cache_update_token "$bid" "$pg_osis" "${pg_rest%%.*}" "${pg_rest##*.}" "$col"
    fi
  else
    # Show the API error detail when available
    body=$(curl -s -m 20 \
      -X POST \
      -H "x-yvp-app-key: $(_yvp_key)" \
      -H "Authorization: Bearer $_HL_ACCESS_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$payload" \
      "${_YVP_HL_BASE}/v1/highlights")
    echo "Highlight failed (HTTP $http_code)." >&2
    printf '%s' "$body" | jq -r '.detail // .error // empty' 2>/dev/null >&2
    return 1
  fi
}

hl_delete() {
  # Remove highlights for a passage.  Usage: bible hl rm <passage_id> [bible_id]
  # e.g.: bible hl rm JHN.3.16   (clears that highlighted verse)
  _hl_read_tokens || { echo "Not logged in. Run: bible hl login" >&2; return 1; }
  local pg="${1:-}" bid="${2:-}"
  [[ -n "$pg" ]] || { echo "Usage: bible hl rm <passage_id> [bible_id]" >&2; return 1; }
  [[ -n "$bid" ]] || bid=$(_hl_default_bible_id)
  local http_code body
  http_code=$(curl -s -m 20 -w '%{http_code}' -o /dev/null \
    -X DELETE \
    -H "x-yvp-app-key: $(_yvp_key)" \
    -H "Authorization: Bearer $_HL_ACCESS_TOKEN" \
    "${_YVP_HL_BASE}/v1/highlights/$pg?bible_id=$bid") || return 1
  if [[ "$http_code" == "401" && -n "$_HL_REFRESH_TOKEN" ]] && _hl_token_refresh 2>/dev/null; then
    http_code=$(curl -s -m 20 -w '%{http_code}' -o /dev/null \
      -X DELETE \
      -H "x-yvp-app-key: $(_yvp_key)" \
      -H "Authorization: Bearer $_HL_ACCESS_TOKEN" \
      "${_YVP_HL_BASE}/v1/highlights/$pg?bible_id=$bid")
  fi
  if [[ "$http_code" == "200" || "$http_code" == "204" ]]; then
    echo "Cleared highlight(s) on $pg."
  elif [[ "$http_code" == "404" ]]; then
    echo "No highlight on $pg (already clear)."
  else
    body=$(curl -s -m 20 \
      -X DELETE \
      -H "x-yvp-app-key: $(_yvp_key)" \
      -H "Authorization: Bearer $_HL_ACCESS_TOKEN" \
      "${_YVP_HL_BASE}/v1/highlights/$pg?bible_id=$bid")
    echo "Delete failed (HTTP $http_code)." >&2
    printf '%s' "$body" | jq -r '.detail // .error // empty' 2>/dev/null >&2
    return 1
  fi
  # Keep a cached scan of this book in sync (no-op without one).
  local pg_osis="${pg%%.*}" pg_rest="${pg#*.}" pg_ch pg_vn="*"
  if [[ "$pg_rest" == *.* ]]; then
    pg_ch="${pg_rest%%.*}"; pg_vn="${pg_rest##*.}"
  else
    pg_ch="$pg_rest"
  fi
  _hl_cache_update_token "$bid" "$pg_osis" "$pg_ch" "$pg_vn" ""
}

_hl_chapter_colors() {
  # $1=bible_id $2=passage_id (chapter USFM, e.g. JHN.3). Fills
  # _HL_CHAPTER_COLORS with "vnum=RRGGBB " pairs for highlighted verses
  # in that chapter. Silently no-ops when not logged in or on API errors.
  _HL_CHAPTER_COLORS=""
  _hl_read_tokens || return 0
  local body tmpf
  tmpf=$(mktemp)
  local http_code
  http_code=$(curl -s -m 10 -w '%{http_code}' -o "$tmpf" \
    -H "x-yvp-app-key: $(_yvp_key)" \
    -H "Authorization: Bearer $_HL_ACCESS_TOKEN" \
    "$_YVP_HL_BASE/v1/highlights?bible_id=$1&passage_id=$2" 2>/dev/null) || { rm -f "$tmpf"; return 0; }
  if [[ "$http_code" == "401" && -n "$_HL_REFRESH_TOKEN" ]] && _hl_token_refresh 2>/dev/null; then
    http_code=$(curl -s -m 10 -w '%{http_code}' -o "$tmpf" \
      -H "x-yvp-app-key: $(_yvp_key)" \
      -H "Authorization: Bearer $_HL_ACCESS_TOKEN" \
      "$_YVP_HL_BASE/v1/highlights?bible_id=$1&passage_id=$2" 2>/dev/null)
  fi
  # 200 = highlights listed, 204 = none in this chapter; anything else is an error.
  [[ "$http_code" == "200" || "$http_code" == "204" ]] || { rm -f "$tmpf"; return 0; }
  body=$(cat "$tmpf" 2>/dev/null)
  rm -f "$tmpf"
  local pgid col
  while read -r pgid col; do
    [[ -n "$pgid" && -n "$col" ]] || continue
    _HL_CHAPTER_COLORS+="${pgid##*.}=$col "
  done < <(printf '%s' "$body" | jq -r '.data[]? | "\(.passage_id) \(.color)"' 2>/dev/null)
}

_hl_verse_mark() {
  # $1=verse number. Prints a colored ● for highlighted verses, else ''.
  # Truecolor swatch, falls back to an uncolored dot on older terminals.
  local v="$1" tok col
  [[ -n "$_HL_CHAPTER_COLORS" ]] || return 0
  for tok in $_HL_CHAPTER_COLORS; do
    if [[ "${tok%%=*}" == "$v" ]]; then
      col="${tok#*=}"
      printf ' \033[38;2;%d;%d;%dm●\033[0m' "0x${col:0:2}" "0x${col:2:2}" "0x${col:4:2}"
      return 0
    fi
  done
  return 0
}

_hl_book_scan() {
  # $1=bible_id $2=osis $3=chapter count $4=access token. Fetches one
  # highlights request per chapter (parallel when curl supports it).
  # Returns 0 on success; 1 on failure with _HL_BOOK_ERROR set.
  # Reset accumulators: on a retry after token refresh, a partial first
  # attempt must not be counted twice (duplicate highlight tokens).
  _HL_BOOK_HIGHLIGHTS=""
  _HL_BOOK_HLCOUNT=""
  local bid="$1" osis="$2" maxch="$3" tok="$4" key ch
  key=$(_yvp_key) || { _HL_BOOK_ERROR="No App Key configured."; return 1; }
  local tmpd args
  tmpd=$(mktemp -d)
  args=( -s -m 20 -H "x-yvp-app-key: $key" -H "Authorization: Bearer $tok" )
  local -A hcode=()
  if curl --version 2>/dev/null | grep -qi parallel; then
    local -a urls=()
    for ch in $(seq 1 "$maxch"); do
      urls+=(-o "$tmpd/$ch" -w '%{http_code} %{url_effective}\n' \
        "$_YVP_HL_BASE/v1/highlights?bible_id=$bid&passage_id=$osis.$ch")
    done
    curl "${args[@]}" "${urls[@]}" --parallel --parallel-max 10 >"$tmpd/codes" 2>/dev/null || true
    while read -r c u; do
      [[ -n "$c" && -n "$u" ]] && hcode[${u##*.}]="$c"
    done <"$tmpd/codes"
  else
    for ch in $(seq 1 "$maxch"); do
      hcode[$ch]=$(curl "${args[@]}" -w '%{http_code}' -o "$tmpd/$ch" \
        "$_YVP_HL_BASE/v1/highlights?bible_id=$bid&passage_id=$osis.$ch" 2>/dev/null) || true
    done
  fi
  local body pgid col cnt
  local fail_ch="" fail_code=""
  for ch in $(seq 1 "$maxch"); do
    local code="${hcode[$ch]:-000}"
    if [[ "$code" == "000" ]]; then
      # No HTTP code: curl failed. Missing file = network error; a file
      # (empty or not) means the transfer happened, so classify by size.
      if [[ ! -f "$tmpd/$ch" ]]; then
        [[ -n "$fail_ch" ]] || { fail_ch="$ch"; fail_code="000"; }
        continue
      elif [[ ! -s "$tmpd/$ch" ]]; then
        code=204
      else
        code=200
      fi
    fi
    case "$code" in
      200)
        if ! jq -e 'has("data")' "$tmpd/$ch" >/dev/null 2>&1; then
          [[ -n "$fail_ch" ]] || { fail_ch="$ch"; fail_code="$code"; }
          continue
        fi
        body=$(cat "$tmpd/$ch" 2>/dev/null)
        cnt=0
        while read -r pgid col; do
          [[ -n "$pgid" && -n "$col" ]] || continue
          _HL_BOOK_HIGHLIGHTS+="${ch}:${pgid##*.}=$col "
          cnt=$((cnt + 1))
        done < <(printf '%s' "$body" | jq -r '.data[]? | "\(.passage_id) \(.color)"' 2>/dev/null)
        if (( cnt > 0 )); then
          _HL_BOOK_HLCOUNT+="${ch}=${cnt} "
        fi
        ;;
      204)
        : # valid: no highlights in this chapter
        ;;
      *)
        [[ -n "$fail_ch" ]] || { fail_ch="$ch"; fail_code="$code"; }
        ;;
    esac
  done
  if [[ -n "$fail_ch" ]]; then
    local apierr
    apierr=$(jq -r '.error_description // .error // .fault.faultstring // empty' "$tmpd/$fail_ch" 2>/dev/null)
    rm -rf "$tmpd"
    if [[ "$fail_code" == "000" ]]; then
      _HL_BOOK_ERROR="Read failed (network error, chapter $fail_ch). Check your connection and try again."
    elif [[ -n "$apierr" ]]; then
      _HL_BOOK_ERROR="Read failed: $apierr (HTTP $fail_code, chapter $fail_ch). Run: bible hl login"
    else
      _HL_BOOK_ERROR="Read failed (HTTP $fail_code, chapter $fail_ch). Run: bible hl login"
    fi
    return 1
  fi
  rm -rf "$tmpd"
  return 0
}

_hl_book_highlights() {
  # Scans every chapter of a book for highlights. $1=bible_id $2=osis
  # $3=chapter count. Fills _HL_BOOK_HIGHLIGHTS ("ch:vnum=RRGGBB "
  # tokens) and _HL_BOOK_HLCOUNT ("ch=count " pairs). Retries once after
  # a token refresh on a stale token. Returns non-zero on failure with
  # _HL_BOOK_ERROR set.
  _HL_BOOK_HIGHLIGHTS=""
  _HL_BOOK_HLCOUNT=""
  _HL_BOOK_ERROR=""
  _hl_read_tokens || { _HL_BOOK_ERROR="Not logged in. Run: bible hl login"; return 1; }
  local bid="$1" osis="$2" maxch="$3"
  if _hl_book_scan "$bid" "$osis" "$maxch" "$_HL_ACCESS_TOKEN"; then
    _hl_cache_write "$bid" "$osis" "$_HL_BOOK_HIGHLIGHTS"
    return 0
  fi
  if _hl_token_refresh 2>/dev/null; then
    _HL_BOOK_ERROR=""
    if _hl_book_scan "$bid" "$osis" "$maxch" "$_HL_ACCESS_TOKEN"; then
      _hl_cache_write "$bid" "$osis" "$_HL_BOOK_HIGHLIGHTS"
      return 0
    fi
  fi
  [[ -n "$_HL_BOOK_ERROR" ]] || _HL_BOOK_ERROR="Could not read highlights. Run: bible hl login"
  return 1
}

hl_status() {
  _hl_config_load
  if _yvp_key >/dev/null 2>&1; then
    if [[ -z "$_YVP_KEY_DEFAULT" || "$(_yvp_key)" != "$_YVP_KEY_DEFAULT" ]]; then
      echo "App Key:          set (also the OAuth client_id)"
    else
      echo "App Key:          default (shipped with bible.sh; override in hl config)"
    fi
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
    if _yvp_key >/dev/null 2>&1; then
      if _hl_token_valid; then
        echo "Token status:     valid"
      else
        echo "Token status:     expired (run: bible hl login)"
      fi
    fi
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
  # Local highlights cache summary.
  local f nb=0 nhl=0 hl t
  for f in "$_HL_CACHE_DIR"/*.json; do
    [[ -f "$f" ]] || continue
    nb=$((nb+1))
    hl=$(jq -r '.highlights // ""' "$f" 2>/dev/null)
    for t in $hl; do nhl=$((nhl+1)); done
  done
  if (( nb > 0 )); then
    echo "Highlights cache: $nb book(s), $nhl highlight(s) — $_HL_CACHE_DIR"
  else
    echo "Highlights cache: empty (run: bible hl scan all)"
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
  # num/lang are outputs; clear them so an unmapped version cannot
  # silently reuse a mapping left over from an earlier call.
  num=""
  lang=""
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
    ASV)
      num=12
      lang=en
      ;;
    CPDV)
      num=42
      lang=en
      ;;
    NASB1995)
      num=100
      lang=en
      ;;
    NIrV)
      num=110
      lang=en
      ;;
    NIV11)
      num=111
      lang=en
      ;;
    NIVUK11)
      num=113
      lang=en
      ;;
    TOJB2011)
      num=130
      lang=en
      ;;
    engWEBUS)
      num=206
      lang=en
      ;;
    WMBBE)
      num=1207
      lang=en
      ;;
    WMB)
      num=1209
      lang=en
      ;;
    TPT)
      num=1849
      lang=en
      ;;
    FBV)
      num=1932
      lang=en
      ;;
    EASY)
      num=2079
      lang=en
      ;;
    PEV)
      num=2530
      lang=en
      ;;
    LSV)
      num=2660
      lang=en
      ;;
    NASB2020)
      num=2692
      lang=en
      ;;
    BSB)
      num=3034
      lang=en
      ;;
    TCENT)
      num=3427
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

  # Everything else in the Platform API catalog (1,400+ versions)
  # resolves dynamically: the cached catalog supplies the id and
  # language tag, and its canonical abbreviation replaces the user's
  # token for display and cache keys. Runs only when the case block
  # above did not match, so the curated mappings stay authoritative.
  if [[ -z "$num" && -n "$version" ]]; then
    local row cid cabbr clang
    row=$(_yvp_version_row "$version" 2>/dev/null) || row=""
    if [[ -n "$row" ]]; then
      IFS=$'\t' read -r cid cabbr clang <<< "$row"
      num="$cid"
      lang="$clang"
      version="$cabbr"
    fi
  fi
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

_yv_chapter_html() {
  # $1 = version id, $2 = USFM reference (e.g. JHN.3).
  # Keyless fallback for versions not licensed to the Platform API.
  # Echo the chapter markup from the YouVersion chapter JSON API
  # (no key required) and set $page_h1 to the localized heading
  # ("Johannes 3"). The JSON spans use different class names than
  # the site, so normalize them to the __verse/__content names the
  # parsers below expect; numeric entities (&#248;) are decoded so
  # accented text comes out as plain UTF-8.
  local json
  json=$(curl -s \
    --compressed \
    -H 'Accept: application/json' \
    "https://bible.youversionapi.com/3.1/chapter.json?id=$1&reference=$2") || true
  page_h1=$(printf '%s' "$json" | jq -r '.response.data.reference.human // empty' 2>/dev/null)
  printf '%s' "$json" | jq -r '
    .response.data.content // empty
    | gsub("class=\"verse v[0-9]+\""; "class=\"verse__verse\"")
    | gsub("class=\"content\""; "class=\"verse__content\"")
    | gsub("&#(?<d>[0-9]+);"; "\(.d|tonumber|[.]|implode)")
  ' 2>/dev/null
}

get_bible_chapter() {
  # tmpfile — the chapter JSON carries every verse as
  # <span data-usfm="BOOK.CH.VERSE">, so one fetch serves single
  # verses, ranges and whole chapters. $3 is kept for call
  # compatibility but the version is already in $num.
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq not installed..."
    return 1
  fi
  tmp=$(mktemp)
  tmp_files+=("$tmp")
  _yv_chapter_html "$num" "$1.$2" > "$tmp"
  if [[ ! -s "$tmp" ]]; then
    echo "No result."
    echo
    return 1
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
      printf "\n${BOLD}%s${NC}%s %s\n" "$vnum" "$(_hl_verse_mark "$vnum")" "$(echo "$vtext" | fold -w ${width} -s)"
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
    return 1
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
  # licensed to it, read via the official Platform API (clean text).
  # Falls back to the keyless chapter JSON path below on any failure.
  if [[ -z "${BIBLE_ONLINE_ONLY:-}" ]]; then
    local api_id api_usfm api_desc
    if api_id=$(_yvp_bible_id "$num" "$lang" "$version" 2>/dev/null) && [[ -n "$api_id" ]]; then
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
        # Mirrors the keyless path: drop the quote wrappers when the
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

  get_bible_chapter "$bible_book" "$chapter" "$version" || return 1

  # Chapter content marks every verse as <span data-usfm>.
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

  # Localized book name from the chapter JSON heading ("Jesaja 54",
  # set by _yv_chapter_html). Fall back to the canonical English
  # name; the requested version is already canonical.
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

# --- VOTD schedule and Telegram notifications ------------------------
# Daily VOTD cronjob plus Telegram delivery. Settings live in
# ~/.credentials/.bible_votd (0600); telegram.bot is the same sender
# used by ~/.github/Space-Weather-Alerts.
_VOTD_CONFIG="$HOME/.credentials/.bible_votd"
_VOTD_CRON_TAG="# bible.sh-votd"

votd_config_load() {
  VOTD_CRON_TIME="${VOTD_CRON_TIME:-}"
  VOTD_CRON_VERSION="${VOTD_CRON_VERSION:-}"
  VOTD_TELEGRAM="${VOTD_TELEGRAM:-off}"
  TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
  TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
  if [[ -r "$_VOTD_CONFIG" ]]; then
    # shellcheck disable=SC1090
    source "$_VOTD_CONFIG"
  fi
}

votd_config_save() {
  mkdir -p "$(dirname "$_VOTD_CONFIG")"
  chmod 700 "$(dirname "$_VOTD_CONFIG")" 2>/dev/null || true
  {
    printf 'VOTD_CRON_TIME=%q\n' "${VOTD_CRON_TIME:-}"
    printf 'VOTD_CRON_VERSION=%q\n' "${VOTD_CRON_VERSION:-}"
    printf 'VOTD_TELEGRAM=%q\n' "${VOTD_TELEGRAM:-off}"
    printf 'TELEGRAM_BOT_TOKEN=%q\n' "${TELEGRAM_BOT_TOKEN:-}"
    printf 'TELEGRAM_CHAT_ID=%q\n' "${TELEGRAM_CHAT_ID:-}"
  } > "$_VOTD_CONFIG.tmp" \
    && chmod 600 "$_VOTD_CONFIG.tmp" \
    && mv "$_VOTD_CONFIG.tmp" "$_VOTD_CONFIG"
}

votd_telegram_enabled() {
  [[ "${VOTD_TELEGRAM:-off}" == "on" ]] \
    && [[ -n "${TELEGRAM_BOT_TOKEN:-}" ]] \
    && [[ -n "${TELEGRAM_CHAT_ID:-}" ]]
}

votd_telegram_send() {
  # $1 = title, $2 = text. Returns non-zero when sending fails.
  votd_telegram_enabled || return 1
  command -v telegram.bot >/dev/null 2>&1 || return 1
  telegram.bot --bottoken "$TELEGRAM_BOT_TOKEN" --chatid "$TELEGRAM_CHAT_ID" \
    --silent --title "$1" --text "$2" >/dev/null 2>&1
}

votd_telegram_install() {
  local dir url
  dir=$(mktemp -d)
  url="https://github.com/beep-projects/telegram.bot/releases/latest/download/telegram.bot"
  echo "Downloading telegram.bot..."
  if wget -q "$url" -O "$dir/telegram.bot" || curl -fsSL "$url" -o "$dir/telegram.bot"; then
    chmod 755 "$dir/telegram.bot"
    ( cd "$dir" && sudo ./telegram.bot --install )
  else
    echo "Download failed — see https://github.com/beep-projects/telegram.bot" >&2
    rm -rf "$dir"
    return 1
  fi
  rm -rf "$dir"
  command -v telegram.bot >/dev/null 2>&1
}

votd_telegram_setup() {
  votd_config_load
  local token chat answer
  if ! command -v telegram.bot >/dev/null 2>&1; then
    echo "telegram.bot is not installed (the sender Space-Weather-Alerts uses)."
    read -rp "Install it now? [y/N]: " answer </dev/tty
    if [[ "${answer,,}" == "y" ]]; then
      votd_telegram_install || { echo "telegram.bot is still missing." >&2; return 1; }
    else
      return 1
    fi
  fi
  echo "Create a bot with @BotFather, then send it a message (e.g. /start)."
  read -rp "Bot token [${TELEGRAM_BOT_TOKEN:+keep current}]: " token </dev/tty
  token="${token:-$TELEGRAM_BOT_TOKEN}"
  if [[ -z "$token" ]]; then
    echo "No bot token given." >&2
    return 1
  fi
  read -rp "Chat id (see 'telegram.bot --get_chatid --bottoken <token>') [${TELEGRAM_CHAT_ID:-}]: " chat </dev/tty
  chat="${chat:-$TELEGRAM_CHAT_ID}"
  if [[ -z "$chat" ]]; then
    echo "No chat id given." >&2
    return 1
  fi
  TELEGRAM_BOT_TOKEN="$token"
  TELEGRAM_CHAT_ID="$chat"
  VOTD_TELEGRAM=on
  votd_config_save
  echo "Saved to ~/.credentials/.bible_votd"
  echo "Sending a test message..."
  if votd_telegram_send "Verse of the Day" "Telegram notifications are set up."; then
    echo "Test message sent."
  else
    echo "Test message failed — check the token and chat id." >&2
  fi
}

votd_telegram_test() {
  votd_config_load
  if ! votd_telegram_enabled; then
    echo "Telegram is not enabled — run: bible votd telegram setup" >&2
    return 1
  fi
  if votd_telegram_send "Verse of the Day" "Test notification from bible.sh."; then
    echo "Test message sent."
  else
    echo "Test message failed — check the token and chat id." >&2
    return 1
  fi
}

votd_telegram_cli() {
  votd_config_load
  case "${1:-status}" in
    setup) votd_telegram_setup ;;
    test) votd_telegram_test ;;
    on)
      if [[ -z "$TELEGRAM_BOT_TOKEN" || -z "$TELEGRAM_CHAT_ID" ]]; then
        echo "Set up credentials first: bible votd telegram setup" >&2
        return 1
      fi
      VOTD_TELEGRAM=on
      votd_config_save
      echo "Telegram notifications enabled."
      ;;
    off)
      VOTD_TELEGRAM=off
      votd_config_save
      echo "Telegram notifications disabled."
      ;;
    *) votd_cron_status ;;
  esac
}

votd_cron_line() {
  crontab -l 2>/dev/null | grep -F "$_VOTD_CRON_TAG" | tail -n 1
}

votd_cron_installed() {
  [[ -n "$(votd_cron_line)" ]]
}

votd_cron_install() {
  local time="${1:-}" ver="${2:-}" min hour self resolved tmp
  votd_config_load
  if [[ -z "$time" ]]; then
    read -rp "Time of day (HH:MM) [${VOTD_CRON_TIME:-07:00}]: " time </dev/tty
    time="${time:-${VOTD_CRON_TIME:-07:00}}"
  fi
  if [[ ! "$time" =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]]; then
    echo "Invalid time '$time' — use HH:MM (24h), e.g. 07:00." >&2
    return 1
  fi
  if [[ -z "$ver" ]]; then
    read -rp "Version [${VOTD_CRON_VERSION:-$DEF_VERSION}]: " ver </dev/tty
    ver="${ver:-${VOTD_CRON_VERSION:-$DEF_VERSION}}"
  fi
  resolved=$( version="$ver"; version_case; [[ -n "$num" ]] && echo "$version" )
  if [[ -z "$resolved" ]]; then
    echo "Unknown version '$ver'." >&2
    return 1
  fi
  ver="$resolved"
  hour="$((10#${time%%:*}))"
  min="$((10#${time#*:}))"
  self=$(readlink -f "${BASH_SOURCE[0]}")
  mkdir -p "$BIBLE_CACHE"
  VOTD_CRON_TIME="$time"
  VOTD_CRON_VERSION="$ver"
  votd_config_save
  tmp=$(mktemp)
  crontab -l 2>/dev/null | grep -vF "$_VOTD_CRON_TAG" > "$tmp" || true
  printf '%d %d * * * "%s" --votd %s >> "%s/votd-cron.log" 2>&1 %s\n' \
    "$min" "$hour" "$self" "$ver" "$BIBLE_CACHE" "$_VOTD_CRON_TAG" >> "$tmp"
  if crontab "$tmp"; then
    rm -f "$tmp"
    echo "Installed daily VOTD at $time ($ver)."
    echo "Log: $BIBLE_CACHE/votd-cron.log"
  else
    rm -f "$tmp"
    echo "Could not install the crontab entry." >&2
    return 1
  fi
}

votd_cron_remove() {
  local tmp
  tmp=$(mktemp)
  crontab -l 2>/dev/null | grep -vF "$_VOTD_CRON_TAG" > "$tmp" || true
  if crontab "$tmp"; then
    rm -f "$tmp"
    echo "Removed the daily VOTD cronjob."
  else
    rm -f "$tmp"
    echo "Could not update the crontab." >&2
    return 1
  fi
}

votd_cron_status() {
  votd_config_load
  if votd_cron_installed; then
    echo "Daily VOTD: ${VOTD_CRON_TIME:-?} ${VOTD_CRON_VERSION:-?}"
    echo "  $(votd_cron_line)"
  else
    echo "Daily VOTD: not installed (bible votd install 07:00 KJV)."
  fi
  if votd_telegram_enabled; then
    echo "Telegram:   enabled (chat $TELEGRAM_CHAT_ID)"
  else
    echo "Telegram:   disabled (bible votd telegram setup)."
  fi
}

votd_image() {
  # $1 = verse text, $2 = reference, $3 = version abbreviation,
  # $4 = output PNG path. The Verse of the Day API returns no artwork,
  # so render our own shareable card with ImageMagick. Non-zero when
  # ImageMagick (or a usable font) is unavailable or the render fails.
  if [[ ! $(command -v 'convert') ]]; then
    return 1
  fi
  local text="$1" ref="$2" ver="$3" out="$4" serif bold
  serif=$(command -v 'fc-match' >/dev/null 2>&1 && fc-match -f '%{file}' serif 2>/dev/null) || serif=""
  [[ -f "$serif" ]] || serif=/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf
  [[ -f "$serif" ]] || serif=""
  bold=$(command -v 'fc-match' >/dev/null 2>&1 && fc-match -f '%{file}' 'serif:bold' 2>/dev/null) || bold=""
  [[ -f "$bold" ]] || bold=/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf
  [[ -f "$bold" ]] || bold="$serif"
  local -a serif_font=() bold_font=()
  [[ -n "$serif" ]] && serif_font=(-font "$serif")
  [[ -n "$bold" ]] && bold_font=(-font "$bold")
  # 1080x1080 card: dark gradient, centred verse, gold reference line.
  convert -size 1080x1080 gradient:'#12233b-#1c1c2e' \
    \( -background none -fill white "${serif_font[@]}" -pointsize 54 \
       -interline-spacing 18 -size 880x620 caption:"$text" \) \
    -gravity center -geometry +0-60 -composite \
    \( -background none -fill '#f2c14e' "${bold_font[@]}" -pointsize 42 \
       -size 880x60 caption:"$ref  ·  $ver" \) \
    -gravity center -geometry +0+360 -composite \
    "PNG:$out" 2>/dev/null
  [[ -s "$out" ]]
}

votd() {
  if [[ "${2:-}" =~ ^[[:digit:]]+$ ]]
  then
    doy=$2
  else
    # The Platform API indexes the verse of the day by day of the year
    # (1-366), matching `date +%j` exactly (no +1 offset).
    doy=$(date +%j)
  fi
  version=${1:-}
  lang=en
  # Set default version to KJV (1) before resolving the version id
  if [ -z "$version" ]; then
    version="KJV"
  fi
  version_case
  # Official Verse of the Day API: one passage reference per day of the
  # year, with no version and no image attached.
  if [[ ! $(command -v 'jq') ]]; then
    echo "jq not installed..."
    return 1
  fi
  local votd_usfm votd_api_id votd_json votd_chap_tmp
  votd_usfm=$(_yvp_api_get "$_YVP_API/verse_of_the_days/$doy" \
    | jq -r '.passage_id // empty' 2>/dev/null)
  if [[ -z "$votd_usfm" ]]; then
    echo "No verse of the day available."
    # return, not exit: home_verse() calls this while drawing the home
    # screen, and exiting there killed the whole script before the menu.
    return 1
  fi
  # The passage carries no version, so fetch it separately in the
  # selected one: licensed versions through the Platform API passages
  # endpoint, everything else through the keyless chapter API.
  votd_content=""
  votd_title=""
  votd_api_id=$(_yvp_bible_id "$num" "$lang" "$version" 2>/dev/null) || votd_api_id=""
  if [[ -n "$votd_api_id" ]]; then
    votd_json=$(_yvp_api_get "$_YVP_API/bibles/$votd_api_id/passages/$votd_usfm?format=text" 2>/dev/null) || votd_json=""
    if [[ -n "$votd_json" ]]; then
      votd_content=$(printf '%s' "$votd_json" | jq -r '.content // empty' \
        | tr '\n' ' ' | sed -e 's/[[:space:]]\{1,\}$//')
      votd_title=$(printf '%s' "$votd_json" | jq -r '.reference // empty')
    fi
  fi
  if [[ -z "$votd_content" ]]; then
    # Keyless fallback (KJV and other freely readable versions): pull
    # the passage out of the chapter markup. A passage is either a
    # single verse (ISA.43.18) or a range (ISA.43.18-19); the chapter
    # markup carries one span per verse, so ranges are stitched from
    # their members.
    votd_chap_tmp=$(mktemp)
    tmp_files+=("$votd_chap_tmp")
    votd_chap_ref="${votd_usfm%.*}"
    votd_verse_spec="${votd_usfm##*.}"
    _yv_chapter_html "$num" "$votd_chap_ref" > "$votd_chap_tmp"
    votd_content=""
    for ((votd_v = ${votd_verse_spec%-*}; votd_v <= ${votd_verse_spec#*-}; votd_v++)); do
      votd_v_text=$(verse_text "$votd_chap_tmp" "$votd_chap_ref.$votd_v")
      votd_content="${votd_content:+$votd_content }$votd_v_text"
    done
    votd_title="${page_h1}:${votd_verse_spec}"
  fi
  votd_version="${version}"
  votd_url="/bible/$num/$votd_usfm.$votd_version"
  if [[ -z "$votd_content" || -z "$votd_title" ]]; then
    echo "No verse of the day available."
    return 1
  fi
  # Set image tmp file
  votd_img_tmp=$(mktemp)
  tmp_files+=("$votd_img_tmp")

  # VOTD_TEXT=1 (used by the bible frontend home screen): text only,
  # skip image generation entirely. Otherwise render the share card.
  if [[ -z "${VOTD_TEXT:-}" ]]; then
    votd_image "$votd_content" "$votd_title" "$votd_version" "$votd_img_tmp" || true
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
  if [[ -z "${VOTD_TEXT:-}" && -s "$votd_img_tmp" ]]
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
  # Strip quotes from description if any (the passage markup may already
  # carry its own curly quotes; wrapping those again doubled them up)
  if [[ $description =~ $BQUOTE ]] ||
  [[ $description =~ $EQUOTE ]]
  then
    BQUOTE=''
    EQUOTE=''
  fi
  # Display output
  output_correction || return 1
  output "$description" "$book" "$chapter_verse" "$version" "$link"
  # Notifications (skipped for text-only home use)
  if [[ -z "${VOTD_TEXT:-}" ]]
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
    if [[ $(command -v 'notify-send') ]]
    then
      local notify_icon=()
      [[ -s "$votd_img_tmp" ]] && notify_icon=(--icon="$votd_img_tmp")
      notify-send \
        --hint=string:sound-name:dialog-information \
        --app-name="Verse of the Day" \
        --app-icon="dialog-information-symbolic" \
        "${notify_icon[@]}" \
        "Verse of the Day" \
        "$message"
      rm "$votd_img_tmp"
    fi
    # Send Telegram notification (if configured)
    votd_config_load
    votd_telegram_send "Verse of the Day" "$message" || true
  fi
}

search() {
  num=
  query=${1:-}
  version=${2:-}
  # $3 optional: "menu" forces the interactive picker loop even when
  # stdin is not a tty (the menu reads keys from /dev/tty, not fd 0).
  local force_loop="${3:-}"

  # Default to KJV when no version was given (mirrors args()).
  if [[ -z "$version" ]]; then
    version="KJV"
  fi
  version_case

  if [ -z "$version" ]; then
    num=1
  fi

  # API-first search: when an app key is set and the requested version
  # is licensed to it, search the official Platform API (one request per
  # page of references). Interactive contexts let you pick a match to
  # open its chapter or page through the rest; non-interactive ones
  # print the page. The API answer is final even when it has no matches
  # (its "did you mean" hints are part of the feature set). Only when
  # the API cannot run (no key / not licensed / request failed) do we
  # fall back, first to the local database, then to the bible.com
  # search.
  local api_id rc api_notice=""
  if api_id=$(_yvp_bible_id "$num" "$lang" "$version" 2>/dev/null) && [[ -n "$api_id" ]]; then
    if [[ -t 0 || -n "$force_loop" ]]; then
      _yvp_search_loop "$api_id" "$query" "$version" "$num"
      rc=$?
      # 0 = user picked/backed out (finished); anything else = the API
      # request failed → fall through to local.
      (( rc == 0 )) && return 0
    elif _yvp_search "$api_id" "$query" >/dev/null 2>&1; then
      _yvp_search_render "$num" "$version" "$api_id"
      return 0
    fi
    api_notice="YouVersion API search didn't answer (offline now, or rate-limited). Showing local/online results instead:"
  elif [[ -z "$(_yvp_key 2>/dev/null)" ]]; then
    # No app key configured: the API leg never runs, so skip the
    # error noise and let the regular fallbacks take over.
    api_notice=""
  else
    api_notice="YouVersion API search isn't licensed for \"$version\" (or no cached license). Showing local/online results instead:"
  fi

  [[ -n "$api_notice" ]] && echo "${DIM}$api_notice${NC}"

  # Offline fallback: search the local database when the requested
  # version is installed locally.
  if [[ "$version" == "KJV" ]] && _offline_is_installed "KJV"; then
    if local_search "$query" "$version"; then
      return 0
    fi
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
    # bible.com streams some result cards as React placeholders
    # (Loading…); they parse with an empty description. Skip them
    # instead of letting output_correction print a false "No result."
    [[ -z "$description" ]] && continue
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
    output_correction || continue
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
  proverb-a-day, reading plans, the Lord's prayer), Search, Compare,
  Verse of the Day, Translate, Version, Offline and Help. Arrow keys
  →/← work like [n]ext/[p]rev in every chapter loop; Enter resumes
  Continue; update hints show in the header.

  Arguments            Example usage
  --help      | -h     Show this help.
  --bible     | -b     bible -b Isaiah 54:17 KJV
  --search    | -s     bible -s "keyword" KJV
                       Search the YouVersion Platform API first
                       (licensed versions): a pickable list of results
                       with the verse text shown, pagination and "did
                       you mean" suggestions. Falls back to the offline
                       KJV database, then the bible.com search page.
  --votd      | -v     bible -v
                       Daily cronjob:  bible votd install 07:00 KJV
                       Remove/status:  bible votd remove | bible votd status
                       Telegram:       bible votd telegram setup|test|on|off
  proverb              bible proverb
                       Read today's chapter of Proverbs (31 chapters,
                       one per day; menu: Read → "A proverb a day").
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
  uninstall            bible uninstall [VERSION] [-y|--yes] [--all]
                       Remove a locally installed version. Reading
                       then falls back to the online JSON API and
                       search to the bible.com search page.
  status               bible status
                       Show locally installed versions.
  versions             bible versions [LANG]
                       List every version in the YouVersion Platform
                       API catalog, one "ID ABBR LANG" line each.
                       LANG filters by language tag (en, nb, ...;
                       "no" works too). Any catalog version can be
                       read/searched by abbreviation, e.g.
                       bible -b John 3:16 KUD
hl | highlights      bible hl login | list | scan | add | rm | status
                         One-time browser sign-in, then highlight verses.
                         "bible hl scan <BOOK>" scans one book's chapters,
                         "bible hl scan all" scans every book; results are
                         cached locally (stale after ${_HL_CACHE_TTL_MIN}m,
                         override with _HL_CACHE_TTL_MIN). "bible hl list
                         [BOOK]" lists the cached highlights; the menu (g)
                         browses per book, lists the cache, and can sweep
                         every book at once.
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
    nav=$(read_key "[n]ext [p]rev [h]ighlight [f]av [q]uit: ")
    case "$nav" in
      n|N) if [[ -n "$maxch" ]] && ((ch < maxch)); then ((ch++)); else echo "Last chapter."; fi ;;
      p|P) ((ch > 1)) && ((ch--)) || echo "First chapter." ;;
      h|H) read_highlight "$osis" "$name" "$ch" "$ver" "" ;;
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
# The prompt line is closed with a newline after the keypress, so callers
# that return to a redrawn menu don't print onto the prompt line.
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
  [[ -n "$1" ]] && printf '\n' >&2
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
      | fzf --ansi --prompt="$prompt › " --pointer="›" --border=rounded \
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
    nav=$(read_key "[n]ext [p]rev [v]erse [c]hapter [h]ighlight [f]av [q]uit: ")
    case "$nav" in
      n|N) ((ch < maxch)) && ((ch++)) || echo "Last chapter."; ref="" ;;
      p|P) ((ch > 1)) && ((ch--)) || echo "First chapter."; ref="" ;;
      v|V) read -rp "Verse (empty = whole chapter): " ref </dev/tty ;;
      c|C) ch="" ;;
      h|H) read_highlight "$osis" "$name" "$ch" "$ver" "$ref" ;;
      f|F) toggle_fav "$osis|$name|$ch|$ver" ;;
      *) return ;;
    esac
  done
}

show_chapter() {
  # $1=OSIS $2=chapter $3=version $4=display name (optional)
  local osis="$1" ch="$2" ver="$3" dname="${4:-$1}"
  version="$ver"
  version_case
  # Fetch the highlight colors for this chapter so highlighted verses
  # get marked inline during the read loop.
  _hl_chapter_colors "$num" "$osis.$ch"
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
  get_bible_chapter "$osis" "$ch" "$ver" || return 1
  chapter_text "$tmp" "$osis.$ch"
  printf "\n${GREEN}%s %s${NC} - ${YELLOW}(%s)${NC}\n" "$dname" "$ch" "$ver"
  printf "${BLUE}https://www.bible.com/bible/%s/%s.%s.%s${NC}\n\n" "$num" "$osis" "$ch" "$ver"
}

_hl_swatch() {
  # $1 = RRGGBB → a truecolor block for menus (two spaces wide).
  local r=$((16#${1:0:2})) g=$((16#${1:2:2})) b=$((16#${1:4:2}))
  printf '\033[48;2;%d;%d;%dm  \033[0m' "$r" "$g" "$b"
}

_hl_pick_color() {
  # Interactive swatch picker, like the app's highlight colors.
  # Echoes an RRGGBB value, or empty on abort. Returns 1 on bad custom hex.
  local -a items=()
  local i picked col
  for i in "${!_HL_PALETTE_HEXES[@]}"; do
    items+=("$(_hl_swatch "${_HL_PALETTE_HEXES[$i]}") ${_HL_PALETTE_NAMES[$i]}  #${_HL_PALETTE_HEXES[$i]}")
  done
  items+=("Custom hex…")
  picked=$(pick_from_list "Highlight color:" "${items[@]}") || true
  if [[ -z "$picked" ]]; then
    echo ""
    return 0
  fi
  if [[ "$picked" == "Custom hex…" ]]; then
    read -rp "Color hex (RRGGBB, empty = cancel): " col </dev/tty
    col="${col#\#}"
    col="${col,,}"
    [[ -z "$col" ]] && { echo ""; return 0; }
    if [[ ! "$col" =~ ^[0-9a-f]{6}$ ]]; then
      echo "Color must be a 6-digit hex (RRGGBB)." >&2
      return 1
    fi
    echo "$col"
    return 0
  fi
  # Map the chosen menu label back to its hex swatch.
  for i in "${!_HL_PALETTE_HEXES[@]}"; do
    if [[ "$picked" == *"#${_HL_PALETTE_HEXES[$i]}" ]]; then
      echo "${_HL_PALETTE_HEXES[$i]}"
      return 0
    fi
  done
  echo ""
}

read_highlight() {
  # Read-flow helper: create, update, or clear a highlight for a verse.
  # $1=OSIS $2=name $3=chapter $4=version $5=current ref (may be empty)
  _hl_read_tokens || { echo "Not logged in. Run: bible hl login"; return 1; }
  local osis="$1" name="$2" ch="$3" ver="$4" cur="$5"
  local bid v pg entries existing action col fetched=0
  version="$ver"
  version_case
  bid="${num:-1}"
  # With a plain current verse, check the chapter up front: when it is
  # already highlighted, go straight to the action menu instead of
  # asking which verse to highlight.
  if [[ "$cur" =~ ^[0-9]+$ ]]; then
    entries=$(_hl_fetch_passage "$bid" "$osis.$ch") || return 1
    fetched=1
    existing=$(_hl_existing_color "$osis.$ch" "$cur" <<< "$entries")
    if [[ -n "$existing" ]]; then
      action=$(pick_from_list "$osis.$ch.$cur is highlighted (#$existing):" \
        "Update color" "Clear highlight" "Other verse…" "Cancel")
      case "$action" in
        "Update color")
          col=$(_hl_pick_color) || return 1
          if [[ -n "$col" ]]; then
            hl_add "$osis.$ch.$cur" "$col" "$bid" || return 1
            _hl_chapter_colors "$bid" "$osis.$ch"
          fi
          return 0
          ;;
        "Clear highlight")
          hl_delete "$osis.$ch.$cur" "$bid" || return 1
          _hl_chapter_colors "$bid" "$osis.$ch"
          return 0
          ;;
        "Other verse…") ;; # fall through to the verse prompt
        *) return 0 ;;
      esac
    fi
  fi
  if [[ -n "$cur" ]]; then
    read -rp "Highlight verse (empty = $cur, 0 = cancel): " v </dev/tty
    [[ "$v" == "0" ]] && return 0
    [[ -z "$v" ]] && v="$cur"
  else
    read -rp "Highlight verse in $name $ch (e.g. 16 or 16-18, empty = cancel): " v </dev/tty
    [[ -z "$v" ]] && return 0
  fi
  v="${v// /}"
  v="${v##*:}"
  if ! [[ "$v" =~ ^[0-9]+([,-][0-9]+)*$ ]]; then
    echo "Enter a verse number, range (16-18) or list (16,18)."
    return 1
  fi
  pg="$osis.$ch.$v"
  if (( ! fetched )); then
    entries=$(_hl_fetch_passage "$bid" "$osis.$ch") || return 1
  fi
  existing=$(_hl_existing_color "$osis.$ch" "$v" <<< "$entries")
  if [[ -n "$existing" ]]; then
    action=$(pick_from_list "$pg is highlighted (#$existing):" \
      "Update color" "Clear highlight" "Cancel")
    case "$action" in
      "Update color")
        col=$(_hl_pick_color) || return 1
        [[ -n "$col" ]] || return 0
        hl_add "$pg" "$col" "$bid" || return 1
        ;;
      "Clear highlight")
        hl_delete "$pg" "$bid" || return 1
        ;;
      *) return 0 ;;
    esac
  else
    action=$(pick_from_list "$pg is not highlighted:" "Create highlight" "Cancel")
    [[ "$action" == "Create highlight" ]] || return 0
    col=$(_hl_pick_color) || return 1
    [[ -n "$col" ]] || return 0
    hl_add "$pg" "$col" "$bid" || return 1
  fi
  # Keep this chapter's inline verse markers current.
  _hl_chapter_colors "$bid" "$osis.$ch"
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

_hl_osis_by_name() {
  # $1 = display name → OSIS code.
  local e
  for e in "${_OT[@]}" "${_NT[@]}" "${_APO[@]}"; do
    if [[ "$(cut -d'|' -f2 <<<"$e")" == "$1" ]]; then
      cut -d'|' -f1 <<<"$e"
      return
    fi
  done
}

_hl_pick_book() {
  # Echo an OSIS code for the book the user picks (empty on abort).
  local -a books=()
  local e
  for e in "${_OT[@]}" "${_NT[@]}" "${_APO[@]}"; do
    books+=("$(cut -d'|' -f2 <<<"$e")")
  done
  local name
  name=$(pick_from_list "Book:" "${books[@]}")
  [[ -z "$name" ]] && return 1
  _hl_osis_by_name "$name"
}

_hl_browse_book() {
  # $1=bible_id $2=osis $3=name $4=version — list the chapters of a book
  # that have highlights, then open one. Uses a fresh local cache entry
  # when available; otherwise scans (which caches the result).
  local bid="$1" osis="$2" name="$3" ver="$4" maxch
  maxch=$(book_chapters "$osis")
  [[ -n "$maxch" ]] || { echo "Don't know the chapter count for $name."; pause; return; }
  if _hl_cache_load "$bid" "$osis" && (( ! _HL_CACHE_STALE )); then
    echo "Using cached highlights for $name (scanned $(_hl_fmt_age "$_HL_CACHE_AGE"))."
  else
    echo "Scanning $name ($maxch chapters)…"
    _hl_book_highlights "$bid" "$osis" "$maxch"
    if _hl_cache_load "$bid" "$osis"; then
      :  # scan succeeded; the fresh entry is already in the cache
    else
      _HL_CACHE_HIGHLIGHTS="$_HL_BOOK_HIGHLIGHTS"
      _HL_CACHE_COUNTS="$_HL_BOOK_HLCOUNT"
    fi
  fi
  if [[ -z "$_HL_CACHE_HIGHLIGHTS" ]]; then
    if [[ -n "$_HL_BOOK_ERROR" ]]; then
      echo "$_HL_BOOK_ERROR"
    else
      echo "No highlights in $name."
    fi
    pause
    return
  fi
  local -a labels=()
  local pair chN cnt
  for pair in $_HL_CACHE_COUNTS; do
    chN="${pair%%=*}"; cnt="${pair#*=}"
    labels+=("$name $chN   ($cnt)")
  done
  local entry
  entry=$(pick_from_list "Highlighted chapters in $name:" "${labels[@]}")
  [[ -z "$entry" ]] && return
  local sel="${entry%%   *}"
  local c="${sel##* }"
  _hl_browse_chapter "$bid" "$osis" "$name" "$c" "$ver"
}

_hl_browse_chapter() {
  # $1=bible_id $2=osis $3=name $4=chapter $5=version. Lists that
  # chapter's highlighted verses; picking one opens the chapter with
  # inline highlight markers.
  local bid="$1" osis="$2" name="$3" ch="$4" ver="$5"
  _hl_chapter_colors "$bid" "$osis.$ch"
  if [[ -z "$_HL_CHAPTER_COLORS" ]]; then
    echo "No highlights in $name $ch."
    pause
    return
  fi
  local -a labels=()
  local tok pgid col
  for tok in $_HL_CHAPTER_COLORS; do
    pgid="${tok%%=*}"; col="${tok#*=}"
    labels+=("$osis.$ch.$pgid  ●#${col}")
  done
  local entry
  entry=$(pick_from_list "Highlights in $name $ch:" "${labels[@]}")
  [[ -z "$entry" ]] && return
  show_chapter "$osis" "$ch" "$ver" "$name"
  save_place "$osis|$name|$ch|$ver"
  pause
}
menu_highlights() {
  # Browse your highlights: pick a book (or the one you're reading) and
  # scan all its chapters for highlighted verses, jump straight to the
  # current chapter's highlights, list the cache, or sweep every book.
  _hl_read_tokens || {
    echo "You're not signed in to YouVersion yet."
    echo "Run: bible hl login   (one-time browser sign-in)"
    pause
    return
  }
  local osis="" name="" ch="" ver="" bid
  if [[ -f "$BIBLE_LAST" ]]; then
    IFS='|' read -r osis name ch ver < "$BIBLE_LAST"
  fi
  ver="${ver:-$DEF_VERSION}"
  version="$ver"; version_case; bid="${num:-1}"
  if [[ -z "$name" && -n "$osis" ]]; then name=$(osis_name "$osis"); fi
  local -a picks=()
  if [[ -n "$osis" ]]; then
    picks+=("Browse ${name:-$osis} by highlights")
  fi
  picks+=("Pick a book…")
  picks+=("List all cached highlights")
  picks+=("Scan all books (full Bible sweep)")
  if [[ -n "$osis" && -n "$ch" ]]; then
    picks+=("Highlights in ${name:-$osis} $ch")
  fi
  local action
  action=$(pick_from_list "Highlights:" "${picks[@]}")
  [[ -z "$action" ]] && return
  case "$action" in
    "Pick a book…")
      local bosis bname
      bosis=$(_hl_pick_book) || return
      bname=$(osis_name "$bosis")
      _hl_browse_book "$bid" "$bosis" "$bname" "$ver"
      ;;
    "List all cached highlights")
      hl_list
      pause
      ;;
    "Scan all books (full Bible sweep)")
      _hl_scan_all "$bid"
      pause
      ;;
    "Highlights in "*)
      _hl_browse_chapter "$bid" "$osis" "$name" "$ch" "$ver"
      ;;
    *)
      _hl_browse_book "$bid" "$osis" "$name" "$ver"
      ;;
  esac
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
    nav=$(read_key "[n]ext [p]rev [h]ighlight [f]av [q]uit: ")
    case "$nav" in
      n|N) if [[ -n "$maxch" ]] && ((ch < maxch)); then ((ch++)); else echo "Last chapter."; fi ;;
      p|P) ((ch > 1)) && ((ch--)) || echo "First chapter." ;;
      h|H) read_highlight "$osis" "$name" "$ch" "$ver" "" ;;
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
  local choice day pl pn pc
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
    [[ -n "$pl" ]] && IFS='|' read -r pn _ pc _ <<< "$pl"
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
    choice=$(pick_from_list "Offline Bible:" "Update KJV" "Reinstall KJV" "Uninstall KJV")
    case "$choice" in
      "Update KJV") update_version "KJV"; pause ;;
      "Reinstall KJV") _fetch_and_build "KJV"; pause ;;
      "Uninstall KJV") uninstall_version "KJV"; pause ;;
    esac
  else
    choice=$(pick_from_list "Offline Bible:" "Install KJV (offline read/search)")
    case "$choice" in
      "Install KJV (offline read/search)") install_version "KJV"; pause ;;
    esac
  fi
}

menu_version() {
  # Pick the default version. With a Platform API catalog available this
  # offers every licensed version (the same "ID ABBR LANG" lines as
  # `bible versions`, grouped by language), with the curated shortlist on
  # top for the usual favourites. Without a catalog (no key, offline) it
  # falls back to just the shortlist.
  local choice tsv lang id abbr ltag i
  local -a labels picks
  labels=("${_VERSIONS_EN[@]}" "${_VERSIONS_NO[@]}" "${_VERSIONS_ORIG[@]}")
  picks=("${labels[@]}")
  if tsv=$(_yvp_catalog); then
    if [[ "$_HAVE_FZF" == true ]]; then
      # fzf searches the whole list, so add everything.
      while IFS=$'\t' read -r id abbr ltag; do
        [[ -n "$id" && -n "$abbr" ]] || continue
        labels+=("$(printf '%-6s %-18s %s' "$id" "$abbr" "$ltag")")
        picks+=("$abbr")
      done < <(printf '%s\n' "$tsv" | sort -t$'\t' -k3,3 -k2,2)
    else
      # A numbered menu cannot handle 1,400+ rows: filter by language.
      read -rp "Language tag (e.g. en, nb, es; empty = common versions): " lang </dev/tty
      lang="${lang,,}"
      [[ "$lang" == "no" ]] && lang=nb
      if [[ -n "$lang" ]]; then
        labels=(); picks=()
        while IFS=$'\t' read -r id abbr ltag; do
          [[ -n "$id" && -n "$abbr" ]] || continue
          labels+=("$(printf '%-6s %-18s %s' "$id" "$abbr" "$ltag")")
          picks+=("$abbr")
        done < <(printf '%s\n' "$tsv" | awk -F'\t' -v l="$lang" 'tolower($3)==l' | sort -t$'\t' -k3,3 -k2,2)
        if ((${#labels[@]} == 0)); then
          printf 'No versions for language "%s".\n' "$lang" >&2
          sleep 1
          return 0
        fi
      fi
    fi
  fi
  choice=$(pick_from_list "Default version (now: $DEF_VERSION):" "${labels[@]}")
  [[ -n "$choice" ]] || return 0
  # Map the chosen label back to its abbreviation (duplicate labels,
  # e.g. the shortlist entry and its catalog row, resolve the same).
  for i in "${!labels[@]}"; do
    if [[ "${labels[$i]}" == "$choice" ]]; then
      choice="${picks[$i]}"
      break
    fi
  done
  DEF_VERSION="$choice"
  echo "Default version: $DEF_VERSION"
  sleep 0.5
}

menu_search() {
  local q v
  # Version first: the keyword prompt shows live suggestions that depend
  # on which backend (API vs offline KJV) the search will use.
  read -rp "Version [$DEF_VERSION]: " v </dev/tty
  v="${v:-$DEF_VERSION}"
  q=$(_keyword_prompt "$v")
  [[ -z "$q" ]] && return
  search "$q" "$v" menu
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
  local key
  votd "$DEF_VERSION"
  while true; do
    votd_config_load
    printf '\n'
    printf '  %s[c]%s Daily cronjob' "${BOLD}${GREEN}" "${NC}"
    if votd_cron_installed; then
      printf ' %s(%s %s)%s' "${DIM}" "${VOTD_CRON_TIME:-?}" "${VOTD_CRON_VERSION:-?}" "${NC}"
    fi
    printf '   %s[t]%s Telegram' "${BOLD}${GREEN}" "${NC}"
    if votd_telegram_enabled; then
      printf ' %s(on)%s' "${DIM}" "${NC}"
    fi
    printf '   %s[Enter]%s Back\n' "${BOLD}${DIM}" "${NC}"
    printf '› '
    IFS= read -rsn1 key </dev/tty
    printf '\n'
    case "${key,,}" in
      c) votd_cron_menu ;;
      t) votd_telegram_menu ;;
      ""|$'\r'|$'\n'|q) break ;;
    esac
  done
}

votd_cron_menu() {
  votd_config_load
  local choice time ver
  if votd_cron_installed; then
    choice=$(pick_from_list "Daily VOTD (${VOTD_CRON_TIME:-?} ${VOTD_CRON_VERSION:-?}):" \
      "Update time / version" "Remove cronjob")
    case "$choice" in
      "Update time / version") ;;
      "Remove cronjob")
        votd_cron_remove
        pause
        return
        ;;
      *) return ;;
    esac
  else
    choice=$(pick_from_list "Daily VOTD:" "Install cronjob")
    [[ "$choice" == "Install cronjob" ]] || return
  fi
  read -rp "Time of day (HH:MM) [${VOTD_CRON_TIME:-07:00}]: " time </dev/tty
  time="${time:-${VOTD_CRON_TIME:-07:00}}"
  read -rp "Version [${VOTD_CRON_VERSION:-$DEF_VERSION}]: " ver </dev/tty
  ver="${ver:-${VOTD_CRON_VERSION:-$DEF_VERSION}}"
  votd_cron_install "$time" "$ver"
  pause
}

votd_telegram_menu() {
  votd_config_load
  local choice
  if votd_telegram_enabled; then
    choice=$(pick_from_list "Telegram VOTD (enabled):" \
      "Send test message" "Change credentials" "Disable")
  else
    choice=$(pick_from_list "Telegram VOTD (disabled):" "Set up / enable")
  fi
  case "$choice" in
    "Send test message")
      votd_telegram_test
      pause
      ;;
    "Change credentials"|"Set up / enable")
      votd_telegram_setup
      pause
      ;;
    "Disable")
      VOTD_TELEGRAM=off
      votd_config_save
      echo "Telegram notifications disabled."
      pause
      ;;
  esac
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
    keys+=(a r f g s m v t e o h)
    actions+=(menu_saved menu_read menu_favorites menu_highlights menu_search menu_compare menu_votd menu_translate menu_version menu_offline menu_help)
    labels+=("Are you saved?" "Read" "Favorites" "Highlights" "Search" "Compare" "Verse of the Day" "Translate" "Version" "Offline" "Help")
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
    --votd | votd)
      shift
      case "${1:-}" in
        install|cron|install-cron) shift; votd_cron_install "$@" ;;
        remove|uncron|remove-cron|uninstall) shift; votd_cron_remove ;;
        cron-status|status) shift; votd_cron_status ;;
        telegram) shift; votd_telegram_cli "$@" ;;
        *) votd "$@" ;;
      esac
      _votd_rc=$?
      exit "$_votd_rc"
      ;;
    -v) shift; votd "$@" ;;
    --compare | -c) shift; compare "$@" ;;
    --saved | -a | saved) shift; witness_saved "$@" ;;
    --translate | -t) shift; translate "$@" ;;
    proverb) menu_proverb ;;
    install) shift; install_version "${1:-KJV}" "${2:-}" ;;
    update) shift; update_version "${1:-KJV}" "${2:-}" ;;
    uninstall | remove) shift; uninstall_version "$@"; exit $? ;;
    status) offline_status ;;
    versions | --versions) shift; versions "${1:-}"; exit $? ;;
    self-update | selfupdate | -u | --update | upgrade) shift; self_update ;;
    --no-update-check) BIBLE_NO_UPDATE_CHECK=1; main_menu ;;
    hl|highlights)
      shift
      _hl_rc=0
      case "${1:-status}" in
        login) shift; hl_login "$@" ;;
        logout) shift; hl_logout ;;
        config) shift; _hl_configure_prompt; _hl_config_save; echo "Saved to ~/.credentials/.bible_yvp_oauth and ~/.credentials/.bible.com_token." ;;
        approve) shift; hl_approve ;;
        list) shift; hl_list "$@" ;;
        scan) shift; hl_scan "$@" ;;
        add) shift; hl_add "$@" ;;
        delete|rm) shift; hl_delete "$@" ;;
        *) hl_status ;;
      esac
      _hl_rc=$?
      exit "$_hl_rc"
      ;;
    *) usage; exit 1 ;;
  esac
  exit 0
fi

main_menu
