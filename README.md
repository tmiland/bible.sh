# bible.sh
Script to get bible verse from bible.com 

# Install

```shell
wget -q https://github.com/tmiland/bible.sh/raw/main/bible.sh -O ~/.scripts/bible.sh
wget -q https://github.com/tmiland/bible.sh/raw/main/bible -O ~/.scripts/bible
chmod +x ~/.scripts/bible
```
Symlink (the app frontend):
```shell
ln -sfn ~/.scripts/bible ~/.local/bin/bible
```
(`bible.sh` alone keeps working standalone: `bash bible.sh -b John 3:16 KJV`.)

## App frontend

Run `bible` with no arguments for the interactive app: greeting,
daily verse, continue-reading, then menus for Read (Old/New
Testament browse with chapter navigation, plus KJV Apocrypha:
Tobit, Judith, Wisdom, Baruch, 1–2 Maccabees, Bel and the
Dragon), Search, Compare, Listen, Verse of the Day, Translate,
Version picker and Help. With arguments it behaves like
`bible.sh` (`bible -b John 3:16 KJV`).

Reading position, streak days, favorites and the cached verse
live under `~/.cache/bible/`. List picking uses fzf when
installed, otherwise numbered menus (`NO_FZF=1` forces menus).


**Full write-up on the blog:** https://tmiland.com/bible-sh/
## Verse of the day

Usage
```shell
bible votd
```

<a href="https://raw.githubusercontent.com/tmiland/bible.sh/main/assets/votd.png">![votd](https://raw.githubusercontent.com/tmiland/bible.sh/main/assets/votd.png)</a>

Desktop notification

<a href="https://raw.githubusercontent.com/tmiland/bible.sh/main/assets/votd_notify.png">![votd_notify](https://raw.githubusercontent.com/tmiland/bible.sh/main/assets/votd_notify.png)</a>

## Usage

```shell
Arguments            Example usage
--help      | -h     Show this help text.
--bible     | -b     bible -b Isaiah 54:17 KJV
--search    | -s     bible -s "keyword" KJV
--votd      | -v     bible -v
--listen    | -l     bible -l Isaiah 54 KJV
--compare   | -c     bible -c Isaiah 54:17 KJV NIV NLT NKJV ESV
                     or bible -c Isaiah 54:17 [en|no]
--translate | -t     bible -t Matthew 17:21 greek en
                     or bible -t Isaiah 54:17 hebrew en
```

```shell
bible -b Isaiah 54 17 KJV
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

### Flexible reference parsing

The `-b`, `-c`, `-l` and `-t` arguments are parsed flexibly. Chapter and verse
can be given with or without a colon, with or without a space, and a numbered
book name can be written with or without a space:

```shell
bible -b 2 Timoteus 1 2        # with space, no colon
bible -b 2Timoteus 1 2         # no space, no colon
bible -b 2 Timoteus 1:2        # with space, colon
bible -b 2Timoteus 1:2         # no space, colon
bible -b "2 Timoteus 1 2"      # whole reference as one quoted token
bible -b Psalm 23 3            # chapter only
bible -b 1 Corinthians 13 4-6  # verse range, no colon
```

A default version (KJV) is used when no version is given.

Reference parsing and its callers were refactored by [opencode](https://opencode.ai).

### Alias to copy to clipboard

```shell
clip() {
	xclip -selection clipboard
}
```
Usage:
```shell
bible -b Isaiah 54 17 KJV | clip
```

### Compare versions

```shell
bible -c Isaiah 54:17 KJV NIV NLT NKJV ESV
```
or
```shell
bible -c Isaiah 54:17 [en|no]
```
or

```shell
# Store versions in a variable for use as argument
export compare_versions=(KJV NIV NLT NKJV ESV N78BM)
```

Usage
```shell
bible -c Isaiah 54 17 $compare_versions
```

Output:
```shell
---------------------
“No weapon that is formed against thee shall prosper; and every tongue that 
shall rise against thee in judgment thou shalt condemn. This is the heritage 
of the servants of the LORD, and their righteousness is of me, saith the 
LORD.”

Isaiah 54:1 - (KJV)
https://www.bible.com/bible/1/ISA.54.17.KJV
------------------------------------------
no weapon forged against you will prevail, and you will refute every tongue 
that accuses you. This is the heritage of the servants of the LORD, and this 
is their vindication from me,” declares the LORD.

Isaiah 54:1 - (NIV)
https://www.bible.com/bible/111/ISA.54.17.NIV
------------------------------------------
“But in that coming day no weapon turned against you will succeed. You will 
silence every voice raised up to accuse you. These benefits are enjoyed by 
the servants of the LORD; their vindication will come from me. I, the LORD, 
have spoken!”

Isaiah 54:1 - (NLT)
https://www.bible.com/bible/116/ISA.54.17.NLT
------------------------------------------
No weapon formed against you shall prosper, And every tongue which rises 
against you in judgment You shall condemn. This is the heritage of the 
servants of the LORD, And their righteousness is from Me,” Says the LORD.

Isaiah 54:1 - (NKJV)
https://www.bible.com/bible/114/ISA.54.17.NKJV
------------------------------------------
no weapon that is fashioned against you shall succeed, and you shall refute 
every tongue that rises against you in judgment. This is the heritage of the 
servants of the LORD and their vindication from me, declares the LORD.”

Isaiah 54:1 - (ESV)
https://www.bible.com/bible/59/ISA.54.17.ESV
------------------------------------------
“De våpen som blir smidd mot deg, skal mislykkes, alle sammen. Hvert 
klagemål som blir reist mot deg, skal du kunne gjendrive. Det er den lodd 
Herrens tjenere får, den rett jeg gir dem, sier Herren.”

Jesaja 54:1 - (N78BM)
https://www.bible.com/no/bible/30/ISA.54.17.N78BM
---------------------
```

# Translate

Install translate-shell
```shell
apt install translate-shell 
```
Usage:
```shell
bible -t Isaiah 54:17 hebrew en
```
or
```shell
bible -t Matthew 17:21 greek en [google|bing] [brief|full]
```
or (source auto-detected: hebrew for OT, greek for NT)
```shell
bible -t John 3:16 auto no
```
Engines with working free endpoints are google (default) and
bing; output is brief and color-free unless `full` is given.
The original verse prints above its translation for comparison.


Output (brief):
```shell
Translating Filemon 1:6 (TR1624) -> no [google]

“οπως η κοινωνια της πιστεως σου ενεργης
γενηται εν επιγνωσει παντος αγαθου του εν
υμιν εις χριστον ιησουν”

ΠΡΟΣ ΦΙΛΗΜΟΝΑ 1:6 - (TR1624)
https://www.bible.com/bible/182/PHM.1.6.TR1624

likesom troens fellesskap er virksomt i kunnskapen om alt det gode ved Kristus Jesus
```

### Search

```shell
bible -s "<keywords>"
```

### Credits
- Contains code from these sources:
  * [bible_verse-cli](https://github.com/RaynardGerraldo/bible_verse-cli/blob/master/bible_verse)
  * Answer on stackoverflow: [Iterate over arguments](https://stackoverflow.com/a/37056727)
  * [Translate Shell](https://github.com/soimort/translate-shell)
  * Answer on stackexchange: [What is the fastest way to view images from the terminal?](https://unix.stackexchange.com/a/745334)
  * [Bash: Show Notifications from Scripts Using notify-send](https://delightlylinux.wordpress.com/2020/10/25/bash-show-notifications-from-scripts-using-notify-send/)

## Donations
<a href="https://coindrop.to/tmiland" target="_blank"><img src="https://coindrop.to/embed-button.png" style="border-radius: 10px; height: 57px !important;width: 229px !important;" alt="Coindrop.to me"></img></a>

#### Disclaimer 

*** ***Use at own risk*** ***

### License

[![MIT License Image](https://upload.wikimedia.org/wikipedia/commons/thumb/0/0c/MIT_logo.svg/220px-MIT_logo.svg.png)](https://github.com/tmiland/bible.sh/blob/master/LICENSE)

[MIT License](https://github.com/tmiland/bible.sh/blob/master/LICENSE)