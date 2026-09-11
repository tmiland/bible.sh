#!/usr/bin/env bash
# shellcheck disable=SC2004,SC2317,SC2053

## Author: Tommy Miland (@tmiland) - Copyright (c) 2024


######################################################################
####                          bible.sh                            ####
####           Script to get bible verse from bible.com           ####
####        Easily get a bible verse for reading or sharing       ####
####                   Maintained by @tmiland                     ####
######################################################################

# VERSION='1.0.2' # Must stay on line 14 for updater to fetch the numbers

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

# When sourced as a library (e.g. by the `bible` frontend), skip the
# CLI-only bits: caller's "$@" must not be rewritten or dispatched on.
_BIBLE_LIB=false
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  _BIBLE_LIB=true
fi

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
if [[ "$_BIBLE_LIB" != true ]]; then
  set -- "${_args[@]}"
fi
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
  # their attributes across newlines.
  # The verse chunk ends at the next verse marker or at the closing
  # chapter divs (never at EOF: flight-data JSON would be swallowed).
  tr '\n' ' ' < "$1" \
    | grep -Po "data-usfm=\"$2\">.*?(?=data-usfm=\"|</div>|<script)" | head -n 1 \
    | sed 's|^[^>]*>||' \
    | sed 's|<span class="[^"]*__label">[^<]*</span>||' \
    | sed 's|<[^>]*>||g' \
    | sed 's|<[^>]*$||' \
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
    echo "No result."
    echo
    exit 0
  fi
}

output() {
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
    printf "\n"
    echo -n "${BQUOTE}$description_folded${EQUOTE}"
    printf "\n"
    printf "\n"
  else
    # Display output
    output_correction
    output "$description" "$book" "$chapter_verse" "$version" "$link"
  fi
}

listen() {
  local num=
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
  # Numbered verses via the chapter text when available; the raw
  # audio transcript has no verse numbers, keep it as fallback.
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
    chapter_text "$listen_text_tmp" "$bible_book.$chapter"
  else
    echo "$listen_mp3_transcript" | fold -w ${width} -s
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

  if [[ -n "$votd_img" ]]; then
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
  if [[ -n "$votd_img" ]]
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
  # Send desktop notification
  if [[ $(command -v 'notify-send') ]]
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
  version_case

  if [ -z "$version" ]; then
    num=1
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
  # Blank palette: translation output is always color-free (dynamic
  # scope carries this into bible(); trans gets -no-ansi below).
  local GREEN='' YELLOW='' BLUE='' BOLD='' DIM='' NC=''
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
  if [[ "$lang_arg" == "hebrew" ]]; then
    version="תנ\"ך"
  elif [[ "$lang_arg" == "greek" ]]; then
    version="TR1624"
  elif [[ -n "$lang_arg" ]]; then
    version="$lang_arg"
  fi
  if [[ $(command -v 'trans') ]]
  then
    if [[ "$verbose" == true ]]; then
      bible "${@:1:target_idx-2}" "$version" trans | trans -no-ansi -e "$engine" :"$target_arg"
    else
      bible "${@:1:target_idx-2}" "$version" trans | trans -no-ansi -b -e "$engine" :"$target_arg"
    fi
  else
    echo "translate-shell is not installed..."
    echo "install with apt install translate-shell"
  fi
}

usage() {
  cat <<EOF
  Arguments            Example usage
  --help      | -h     Show this help text.
  --bible     | -b     bible -b Isaiah 54:17 KJV
  --search    | -s     bible -s "keyword" KJV
  --votd      | -v     bible -v
  --listen    | -l     bible -l Isaiah 54 KJV
  --compare   | -c     bible -c Isaiah 54:17 KJV NIV NLT NKJV ESV
                       or bible -c Isaiah 54:17 [en|no]
  --translate | -t     bible -t Matthew 17:21 greek en [google|bing] [brief|full]
                       or bible -t Isaiah 54:17 hebrew en
                       (greek: TR1624, NT only. hebrew: OT only.
                        engine: google default, bing alternative;
                        TRANS_ENGINE env also works. Brief clean
                        output by default; full restores verbose
                        dictionaries, TRANS_VERBOSE=1 too. Output
                        is always color-free.)
EOF
}

# CLI dispatcher — skipped when sourced as a library.
if [[ "$_BIBLE_LIB" != true ]]; then
while [[ $# -gt 0 ]]
do
  case $1 in
    --help | -h)
      usage
      exit 0
      ;;
    --bible | -b)
      shift
      bible "$@"
      exit 0
      ;;
    --search | -s)
      shift
      search "$@"
      exit 0
      ;;
    --votd | -v | votd)
      shift
      votd "$@"
      exit 0
      ;;
    --listen | -l)
      shift
      listen "$@"
      exit 0
      ;;
    --compare | -c)
      shift
      compare "$@"
      exit 0
      ;;
    --translate | -t)
      shift
      translate "$@"
      exit 0
      ;;
    --* | -*)
      printf "%s\\n\\n" "Unrecognized option: $1"
      usage
      exit 1
      ;;
    *)
      printf "%s\\n\\n" "Unrecognized argument: $1"
      usage
      exit 1
      ;;
  esac
done
fi # _BIBLE_LIB