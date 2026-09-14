#!/usr/bin/env bash
# shellcheck disable=SC2004,SC2001,SC2016

## Offline Bible support for bible.sh
## Provides local SQLite (with JSON fallback) storage for Bible text,
## enabling read/search/compare without an internet connection.

######################################################################
####                       bible_offline.sh                        ####
####     Local Bible database: install, update, query, search      ####
######################################################################

# --- Paths -----------------------------------------------------------
BIBLE_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/bible"
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
