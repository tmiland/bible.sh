#!/usr/bin/env bash
# shellcheck disable=SC2001,SC2317

## YouVersion Highlights — OAuth + Data-Exchange support for bible.sh
## Full scaffolding of the Platform API's highlights (favorites / notes)
## feature: OAuth PKCE authorization, data-exchange approval, and
## /v1/highlights CRUD.  Requires a registered OAuth client
## (YVP_CLIENT_ID + YVP_REDIRECT_URI) and an app key (YVP_APP_KEY
## or ~/.credentials/.bible.com_token).
##
## Without OAuth configured, every command prints clear setup instructions.
## With tokens cached, CRUD calls go through directly.

_YVP_HL_BASE="https://api.youversion.com"
_YVP_HL_TOKEN_CACHE="${BIBLE_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/bible}/youversion-tokens.json"

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

_hl_configured() {
  # 0 when both YVP_CLIENT_ID and YVP_REDIRECT_URI are set.
  [[ -n "${YVP_CLIENT_ID:-}" && -n "${YVP_REDIRECT_URI:-}" ]]
}

# --- Authorization ----------------------------------------------------

hl_authorize_url() {
  # Build + echo the PKCE authorization URL.
  local cid="${YVP_CLIENT_ID:-}" redir="${YVP_REDIRECT_URI:-}"
  if [[ -z "$cid" || -z "$redir" ]]; then
    echo "Set YVP_CLIENT_ID and YVP_REDIRECT_URI first." >&2
    return 1
  fi
  _hl_pkce_verifier
  _hl_pkce_challenge
  _HL_STATE=$(_hl_rand 16)
  local url="${_YVP_HL_BASE}/auth/authorize"
  printf '%s?client_id=%s&response_type=code&redirect_uri=%s&code_challenge=%s&code_challenge_method=S256&state=%s&approval_prompt=force' \
    "$url" "$cid" "$redir" "$_HL_CODE_CHALLENGE" "$_HL_STATE"
}

hl_login() {
  # Interactive PKCE login: print authorize URL, wait for user to paste
  # the authorization code from the redirect, exchange for tokens.
  if ! _hl_configured; then
    cat >&2 <<'EOF'
OAuth not configured. To enable highlights:

1. Register an OAuth client at https://developers.youversion.com
2. Export your credentials:
     export YVP_CLIENT_ID="<your client id>"
     export YVP_REDIRECT_URI="<your redirect uri>"
3. Then run: bible hl login
EOF
    return 1
  fi
  if _hl_read_tokens; then
    echo "Already logged in (tokens cached)."
    return 0
  fi
  local auth_url code
  auth_url=$(hl_authorize_url) || return 1
  echo "Open the following URL in your browser:"
  echo
  echo "  $auth_url"
  echo
  # Try to open automatically
  if command -v xdg-open >/dev/null; then
    xdg-open "$auth_url" 2>/dev/null &
  fi
  echo "Paste the authorization code from the redirect URL and press Enter:"
  read -r code
  code="${code%%#*}"            # strip trailing state fragment
  code="${code##*\?}"          # strip query prefix
  [[ "$code" == *"code="* ]] && code="${code##*code=}"
  code="${code%%&*}"
  # Exchange code for tokens
  local body
  body=$(_yvp_api_get "${_YVP_HL_BASE}/auth/token" \
    --data-urlencode "grant_type=authorization_code" \
    --data-urlencode "code=$code" \
    --data-urlencode "client_id=${YVP_CLIENT_ID}" \
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
  echo "OAuth configured: $(if _hl_configured; then echo yes; else echo no; fi)"
  if _hl_read_tokens 2>/dev/null; then
    echo "Tokens cached:   yes"
  else
    echo "Tokens cached:   no"
  fi
}
