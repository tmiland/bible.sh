#!/usr/bin/env bash
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