#!/usr/bin/env bash
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