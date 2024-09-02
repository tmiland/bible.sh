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
# set -o errexit
# set -o pipefail
# set -o nounset
# set -o xtrace
# Symlink: ln -sfn ~/.scripts/bible.sh ~/.local/bin/bible
BQUOTE='“'
EQUOTE='”'
# Use colors, but only if connected to a terminal, and that terminal
# supports them.
if which tput >/dev/null 2>&1; then
  ncolors=$(tput colors)
fi
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
# Maximum column width
width=$((77))
bible_book_name=
bible_book=
book=$1
chapter=$2
verse=$3
version=$4

# Source: https://github.com/RaynardGerraldo/bible_verse-cli/blob/master/bible_verse
chapter_verse=$(echo "$2" | grep -oE "[0-9]+:[0-9]+")
verse_range=$(echo "$3" | grep -oE "[0-9]+-[0-9]+")

if [ -n "$chapter_verse" ]
then
  chapter=$(echo "$chapter_verse" | cut -d':' -f1)
  verse=$(echo "$chapter_verse" | cut -d':' -f2)
fi

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

if [[ ! $1 == "" ]]
then
  book="$1"
else
  echo "Please enter a valid book name"
fi
shopt -s nocasematch
case "$book" in
  GEN|Genesis)
    bible_book_name="Genesis"
    bible_book="GEN"
    ;;
  EXO|Exodus)
    bible_book_name="Exodus"
    bible_book="EXO"
    ;;
  LEV|Leviticus)
    bible_book_name="Leviticus"
    bible_book="LEV"
    ;;
  NUM|Numbers)
    bible_book_name="Numbers"
    bible_book="NUM"
    ;;
  DEU|Deuteronomy)
    bible_book_name="Deuteronomy"
    bible_book="DEU"
    ;;
  JOS|Joshua)
    bible_book_name="Joshua"
    bible_book="JOS"
    ;;
  JDG|Judges)
    bible_book_name="Judges"
    bible_book="JDG"
    ;;
  RUT|Ruth)
    bible_book_name="Ruth"
    bible_book="RUT"
    ;;
  1SA|"1 samuel")
    bible_book_name="1 samuel"
    bible_book="1SA"
    ;;
  2SA|"2 samuel")
    bible_book_name="2 samuel"
    bible_book="2SA"
    ;;
  1KI|"1 Kings")
    bible_book_name="1 Kings"
    bible_book="1KI"
    ;;
  2KI|"2 Kings")
    bible_book_name="2 Kings"
    bible_book="2KI"
    ;;
  1CH|"1 Chronicles")
    bible_book_name="1 Chronicles"
    bible_book="1CH"
    ;;
  2CH|"2 Chronicles")
    bible_book_name="2 Chronicles"
    bible_book="2CH"
    ;;
  EZR|Ezra)
    bible_book_name="Ezra"
    bible_book="EZR"
    ;;
  NEH|Nehemiah)
    bible_book_name="Nehemiah"
    bible_book="NEH"
    ;;
  EST|Esther)
    bible_book_name="Esther"
    bible_book="EST"
    ;;
  JOB|Job)
    bible_book_name="Job"
    bible_book="JOB"
    ;;
  PSA|Psalm|psalms)
    bible_book_name="Psalm"
    bible_book="PSA"
    ;;
  PRO|Proverbs)
    bible_book_name="Proverbs"
    bible_book="PRO"
    ;;
  ECC|Ecclesiastes)
    bible_book_name="Ecclesiastes"
    bible_book="ECC"
    ;;
  SNG|"Song of Solomon")
    bible_book_name="Song of Solomon"
    bible_book="SNG"
    ;;
  ISA|Isaiah)
    bible_book_name="Isaiah"
    bible_book="ISA"
    ;;
  JER|Jeremiah)
    bible_book_name="Jeremiah"
    bible_book="JER"
    ;;
  LAM|Lamentations)
    bible_book_name="Lamentations"
    bible_book="LAM"
    ;;
  EZK|Ezekiel)
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
  OBA|Obadiah)
    bible_book_name="Obadiah"
    bible_book="OBA"
    ;;
  JON|Jonah)
    bible_book_name="Jonah"
    bible_book="JON"
    ;;
  MIC|Micah)
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
  ZEP|Zephaniah)
    bible_book_name="Zephaniah"
    bible_book="ZEP"
    ;;
  HAG|Haggai)
    bible_book_name="Haggai"
    bible_book="HAG"
    ;;
  ZEC|Zechariah)
    bible_book_name="Zechariah"
    bible_book="ZEC"
    ;;
  MAL|Malachi)
    bible_book_name="Malachi"
    bible_book="MAL"
    ;;
  MAT|Matthew)
    bible_book_name="Matthew"
    bible_book="MAT"
    ;;
  MRK|Mark)
    bible_book_name="Mark"
    bible_book="MRK"
    ;;
  LUK|Luke)
    bible_book_name="Luke"
    bible_book="LUK"
    ;;
  JHN|John)
    bible_book_name="John"
    bible_book="JHN"
    ;;
  ACT|Acts)
    bible_book_name="Acts"
    bible_book="ACT"
    ;;
  ROM|Romans)
    bible_book_name="Romans"
    bible_book="ROM"
    ;;
  1CO|"1 Corinthians")
    bible_book_name="1 Corinthians"
    bible_book="1CO"
    ;;
  2CO|"2 Corinthians")
    bible_book_name="2 Corinthians"
    bible_book="2CO"
    ;;
  GAL|Galatians)
    bible_book_name="Galatians"
    bible_book="GAL"
    ;;
  EPH|Ephesians)
    bible_book_name="Ephesians"
    bible_book="EPH"
    ;;
  PHP|Philippians)
    bible_book_name="Philippians"
    bible_book="PHP"
    ;;
  COL|Colossians)
    bible_book_name="Colossians"
    bible_book="COL"
    ;;
  1TH|"1 Thessalonians")
    bible_book_name="1 Thessalonians"
    bible_book="1TH"
    ;;
  2TH|"2 Thessalonians")
    bible_book_name="2 Thessalonians"
    bible_book="2TH"
    ;;
  1TI|"1 Timothy")
    bible_book_name="1 Timothy"
    bible_book="1TI"
    ;;
  2TI|"2 Timothy")
    bible_book_name="2 Timothy"
    bible_book="2TI"
    ;;
  TIT|Titus)
    bible_book_name="Titus"
    bible_book="TIT"
    ;;
  PHM|Philemon)
    bible_book_name="Philemon"
    bible_book="PHM"
    ;;
  HEB|Hebrews)
    bible_book_name="Hebrews"
    bible_book="HEB"
    ;;
  JAS|James)
    bible_book_name="James"
    bible_book="JAS"
    ;;
  1PE|"1 Peter")
    bible_book_name="1 Peter"
    bible_book="1PE"
    ;;
  2PE|"2 Peter")
    bible_book_name="2 Peter"
    bible_book="2PE"
    ;;
  1JN|"1 John")
    bible_book_name="1 John"
    bible_book="1JN"
    ;;
  2JN|"2 John")
    bible_book_name="2 John"
    bible_book="2JN"
    ;;
  3JN|"3 John")
    bible_book_name="3 John"
    bible_book="3JN"
    ;;
  JUD|Jude)
    bible_book_name="Jude"
    bible_book="JUD"
    ;;
  REV|Revelation)
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
esac

if [[ ! "$chapter" =~ ^[[:digit:]]+$ ]]
then
  echo "Please enter chapter number"
  exit 0
fi

if [[ ! "$1" =~ ^[[:alpha:]]+$ ]]
then
  echo "$1 does not contain any characters"
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
  grep -o '.*[[:digit:]]:[[:digit:]]'
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

bible() {
  if [[ "$*" == *"trans"* ]]
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

bible "$@"
