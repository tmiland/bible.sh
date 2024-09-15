#!/usr/bin/env bash
# shellcheck disable=SC2004,SC2317,SC2053

## Author: Tommy Miland (@tmiland) - Copyright (c) 2024


######################################################################
####                          bible.sh                            ####
####           Script to get bible verse from bible.com           ####
####        Easily get a bible verse for reading or sharing       ####
####                   Maintained by @tmiland                     ####
######################################################################

# VERSION='1.0.0' # Must stay on line 14 for updater to fetch the numbers

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
## Uncomment for debugging purpose
if [[ $* =~ "debug" ]]
then
  set -o errexit
  set -o pipefail
  set -o nounset
  set -o xtrace
fi
# Symlink: ln -sfn ~/.scripts/bible.sh ~/.local/bin/bible
CROSS='✝'
BQUOTE='“'
EQUOTE='”'
# Use colors, but only if connected to a terminal, and that terminal
# supports them.
if which tput >/dev/null 2>&1; then
  ncolors=$(tput colors)
fi

if [[ $* =~ "nocolor" ]]
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
    #RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    BOLD="\033[1m"
    DIM="\033[2m"
    NC='\033[0m'
  fi
fi
# Maximum column width
width=$((77))
bible_book_name=
bible_book=
book=
chapter=
verse=
version=
bible() {
  bible_book_name=
  bible_book=
  book=$1
  chapter=$2
  verse=$3
  version=$4
  # Source: https://github.com/RaynardGerraldo/bible_verse-cli/blob/master/bible_verse
  chapter_verse=$(echo "$2" | grep -oE "[0-9]+:[0-9]+")
  verse_range=$(echo "$3" | grep -oE "[0-9]+-[0-9]+")

  number_book=$(echo "$1" | grep -oE "[0-9](.)[A-Za-z].*")
  if [ -n "$number_book" ]
  then
    book=$(echo "$number_book" | sed "s| ||g")
  fi
  # Check for non-ASCII characters
  non_ascii=$(echo "$1" | grep -Po "[^\x00-\x7F]")

  if [ -n "$chapter_verse" ]
  then
    chapter=$(echo "$chapter_verse" | cut -d':' -f1)
    verse=$(echo "$chapter_verse" | cut -d':' -f2)
  fi

  if [ -n "$verse_range" ]
  then
    verse="$verse_range"
  else
    if [[ ! $3 =~ "listen" ]]
    then
      if [[ "$chapter" =~ ^[[:digit:]]+$ ]] && [[ ! "$verse" =~ ^[[:digit:]]+$ ]]
      then
        echo "Please enter verse number"
        exit 0
      fi
    fi
  fi

  if [[ ! $1 == "" ]]
  then
    book="$1"
  else
    echo "Please enter a valid book name"
  fi
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
    1CH|"1 Chronicles"|"1 Krønikebok")
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

  if [[ ! $4 == "" ]]
  then
    version="$4"
  else
    version="KJV"
  fi

  case "$version" in
    NORSK)
      num=121
      ;;
    NB)
      num=102
      ;;
    N78BM)
      num=30
      ;;
    N11BM)
      num=29
      ;;
    ELB)
      num=115
      ;;
    BGO_HVER)
      num=2321
      ;;
    BGO)
      num=2216
      ;;
    KJV)
      num=1
      ;;
    KJVAAE)
      num=546
      ;;
    KJVAE)
      num=547
      ;;
    NKJV)
      num=114
      ;;
    NIV)
      num=111
      ;;
    ESV)
      num=59
      ;;
    NLT)
      num=116
      ;;
    AMP)
      num=1588
      ;;
    GNV)
      num=2163
      ;;
    WBMS)
      num=2407
      ;;
  esac

  if [[ ! $1 == "votd" ]]
  then
    if [[ ! "$chapter" =~ ^[[:digit:]]+$ ]]
    then
      echo "Please enter chapter number"
      exit 0
    fi

    if [[ ! "$1" =~ ^[[:alpha:]]+$ ]] && [[ -z $non_ascii ]] && [ -z "$number_book" ]
    then
      echo "$1 does not contain any characters"
    fi
  fi
  get_bible_verse() {
    # tmpfile
    tmp=/tmp/bible.tmp
    # Grab verse and store in tmp file
    curl --silent https://www.bible.com/bible/"$num"/"$1"."$2"."$3"."$4" > $tmp
  }

  get_bible_verse "$bible_book" "$chapter" "$verse" "$version"

  description=$(
    xmllint --html --xpath '//*[@class="text-text-light dark:text-text-dark text-17 md:text-19 leading-default md:leading-comfy font-aktiv-grotesk font-medium mbe-2"]/text()' $tmp 2>/dev/null |
    # Strip new lines
    tr '\n' ' ' |
    # Strip multiple spaces
    tr -s ' ' |
    # Strip trailing space
    sed 's/.$//'
  )

  title=$(
    cat $tmp |
    xml2 2>/dev/null |
    grep "meta/@name=twitter:title" --no-group-separator -B1 |
    sed 's|/html/head/meta/@name=twitter:title||g' |
    sed 's|/html/head/meta/@content=||g' |
    sed 's/[ \t]*$//' |
    grep -o '.*[[:digit:]]:[[:digit:]]*.[[:digit:]]*'
  )

  ver=$(
    cat $tmp |
    xml2 2>/dev/null |
    grep "meta/@name=twitter:title" --no-group-separator -B1 |
    sed 's|/html/head/meta/@name=twitter:title||g' |
    sed 's|/html/head/meta/@content=||g' |
    sed 's/[ \t]*$//' |
    grep -o -P '(?<=\().*(?=\))'
  )

  link=$(
    cat $tmp |
    xml2 2>/dev/null |
    grep "meta/@name=twitter:url" --no-group-separator -B1 |
    sed 's|/html/head/meta/@name=twitter:url||g' |
    sed 's|/html/head/meta/@content=||g' |
    tr '\n' ' ' |
    tr -s ' ' |
    sed 's/.$//'
  )

  votd=$(
    curl --silent https://www.bible.com/verse-of-the-day > /tmp/votd.html 2>/dev/null
    cat /tmp/votd.html |
    xml2 2>/dev/null |
    grep "meta/@name=twitter:description" --no-group-separator -B1 |
    sed 's|/html/head/meta/@name=twitter:description||g' |
    sed 's|/html/head/meta/@content=||g' |
    sed 's/[ \t]*$//'
  )

  votd_img=$(
    cat /tmp/votd.html |
    xml2 2>/dev/null |
    grep "meta/@name=twitter:image" --no-group-separator -B1 |
    sed 's|/html/head/meta/@name=twitter:image||g' |
    sed 's|/html/head/meta/@content=||g'
  )

  if [[ $3 == "listen" ]]
  then
    listen_mp3_tmp=/tmp/mp3.html

    listen_mp3_url=$(
      curl --silent https://www.bible.com/audio-bible/"$num"/"$bible_book"."$chapter"."$version" > $listen_mp3_tmp
      cat $listen_mp3_tmp |
      grep -Po "https.*?(?=\")" |
      grep -i audio-bible-cdn |
      head -n 1
    )

    listen_mp3_headline=$(
      cat $listen_mp3_tmp |
      grep -Po "headline\":\".*?(?=\")" |
      sed "s|headline\":\"||g" |
      head -n 1
    )

    listen_mp3_transcript=$(
      cat $listen_mp3_tmp |
      grep -Po "transcript\":\".*?(?=\")" |
      sed "s|transcript\":\"||g" |
      xargs |
      sed "s|\.n|. \n\n|g"
    )

    listen_mp3_link=$(
      cat $listen_mp3_tmp |
      grep -Po "\"@type\":\"WebPage\",\"@id\":\".*?(?=\")" |
      sed "s|\"@type\":\"WebPage\",\"@id\":\"||g"
    )
    if [[ ! $(command -v 'mpv') ]]
    then
      echo "mpv player not installed..."
      exit 0
    else
      mpv --player-operation-mode=pseudo-gui "$listen_mp3_url" >/dev/null 2>&1 &
      rm $listen_mp3_tmp
    fi
  fi

  if [[ $1 == "votd" ]]
  then
    votd_img_tmp=/tmp/votd_img.jpg

    if [[ $(command -v 'curl') ]]; then
      curl -fsSLk "$votd_img" > $votd_img_tmp
    elif [[ $(command -v 'wget') ]]; then
      wget -q "$votd_img" -O $votd_img_tmp
    else
      echo -e "${RED}${ERROR} This script requires curl or wget.\nProcess aborted${NC}"
      exit 0
    fi

    echo -e "${BLUE}${BOLD}Verse of the Day${NC} ${CROSS}"
    echo -e "${DIM}A daily word of exultation.${NC}"
    echo -e "${GREEN}"
    if [[ $(command -v 'convert') ]]
    then
      convert "$votd_img" -scale 300 six:-
    else
      echo '  _    ______  __________  '
      echo ' | |  / / __ \/_  __/ __ \ '
      echo ' | | / / / / / / / / / / / '
      echo ' | |/ / /_/ / / / / /_/ /  '
      echo ' |___/\____/ /_/ /_____/   '
    fi
    echo -e "${NC}"
    title=$(echo "$votd" | grep -o '.*[[:digit:]]:[[:digit:]]*')
    description=$(echo "$votd" | sed "s|$title ||g")
    link=https://www.bible.com/verse-of-the-day
    ver=NIV
    if [[ $(command -v 'notify-send') ]]
    then
      notify-send -i $votd_img_tmp "Verse of the Day" "$description\n$title\n$link"
      rm $votd_img_tmp
    fi
  fi

  # Strip unwanted symbol from version
  if [[ $version == "N78BM" ]]
  then
    description=$(
      echo "$description" | sed "s|¬||g"
    )
  fi

  # Strip quotes from description if any
  if [[ $description =~ $BQUOTE ]] ||
  [[ $description =~ $EQUOTE ]]
  then
    BQUOTE=''
    EQUOTE=''
  fi

  if [[ $description == "" ]]
  then
    description=$(
      echo "This verse has been omitted from this Bible version,"
      echo "or a number out of range has been entered."
    )
  fi

  # Fold description to set width
  description_folded=$(echo "$description" | fold -w ${width} -s)

  if [[ $3 == "listen" ]]
  then
    printf "\n"
    echo -n "$listen_mp3_headline"
    printf "\n"
    printf "\n"
    echo "$listen_mp3_transcript" | fold -w ${width} -s
    printf "\n"
    printf "\n"
    echo "$listen_mp3_link"
    printf "\n"
  elif [[ $description =~ "omitted" ]]
  then
    printf "\n"
    echo -n "${BQUOTE}${BLUE}$description_folded${NC}${EQUOTE}"
    printf "\n"
  elif [[ "$*" == *"trans"* ]]
  then
    printf "\n"
    echo -n "$description"
    printf "\n"
    printf "\n"
  else
    printf "\n"
    echo -n "${BQUOTE}${BLUE}$description_folded${NC}${EQUOTE}"
    echo ""
    echo ""
    echo -n "${GREEN}$title${NC} - ${YELLOW}($ver)${NC}"
    echo ""
    echo -n "${DIM}$link${NC}"
    printf "\n"
    printf "\n"
  fi
}

if [[ ! $1 =~ "-s" ]]
then
  bible "$@"
fi

search() {
  version=$3
  case "$version" in
    NORSK)
      num=121
      ;;
    NB)
      num=102
      ;;
    N78BM)
      num=30
      ;;
    N11BM)
      num=29
      ;;
    ELB)
      num=115
      ;;
    BGO_HVER)
      num=2321
      ;;
    BGO)
      num=2216
      ;;
    KJV)
      num=1
      ;;
    KJVAAE)
      num=546
      ;;
    KJVAE)
      num=547
      ;;
    NKJV)
      num=114
      ;;
    NIV)
      num=111
      ;;
    ESV)
      num=59
      ;;
    NLT)
      num=116
      ;;
    AMP)
      num=1588
      ;;
    GNV)
      num=2163
      ;;
    WBMS)
      num=2407
      ;;
  esac
  get_url_id=$(
    curl -s "https://www.bible.com/search/bible?query=test&version_id=1" |
    grep -Po "<script src=\"/_next/static/.*?(?>\")" |
    tail -n 1 |
    sed "s|<script src=\"/_next/static/||g" |
    sed "s|/_ssgManifest.js\"||g"
  )
  # Source: https://linuxopsys.com/read-json-file-in-shell-script
  bible_search_tmp=/tmp/bible_search.json
  query=$(echo "$2" | tr ' ' '+' )

  curl -s "https://www.bible.com/_next/data/$get_url_id/en/search/bible.json?query=$query&version_id=$num&category=bible" |
  jq -r '.[].results' 2>/dev/null > $bible_search_tmp
  json() {
    jq -r '.'"$1"'[] | "\(.'"$2"')- \(.'"$3"')- \(.'"$4"')"' "$5"
  }
  echo ""
  echo "Search results from bible.com"
  echo ""
  echo "---------------------------------------------------------------------------"
  json verses content human version_local_abbreviation "$bible_search_tmp" |
  while IFS= read -r search_results; do
    result1=$(
      echo "$search_results" |
      cut -d '-' -f1 |
      fold -w ${width} -s
    )
    result2=$(
      echo "$search_results" |
      cut -d '-' -f2 |
      sed 's/ //'
    )
    result3=$(
      echo "$search_results" |
      cut -d '-' -f3 |
      sed 's/ //'
    )
    # Strip unwanted symbol from version
    if [[ $version == "N78BM" ]]
    then
      result1=$(
        echo "$result1" | sed "s|¬||g"
      )
    fi
    echo ""
    echo "${BLUE}$result2 ($result3)${NC}"
    echo ""
    echo "$result1"
    echo ""
    echo "---------------------------------------------------------------------------"
    rm "$bible_search_tmp" 2>/dev/null
  done
}

ARGS=()
while [[ $# -gt 0 ]]
do
  case $1 in
    --help | -h)
      usage
      exit 0
      ;;
    --search | -s)
      search "$@"
      exit 0
      ;;
    -*|--*)
      printf "Unrecognized option: $1\\n\\n"
      usage
      exit 1
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

set -- "${ARGS[@]}"