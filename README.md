# bible.sh
Script to get bible verse from bible.com 

# WIP


# Install

```shell
wget -q https://github.com/tmiland/bible.sh/raw/main/bible.sh -O ~/.scripts/bible.sh
```
Symlink: 
```shell
ln -sfn ~/.scripts/bible.sh ~/.local/bin/bible
```

## Usage

```shell
bible Isaiah 54 17 KJV
```
Output:
```shell
“No weapon that is formed against thee shall prosper; and every tongue that 
shall rise against thee in judgment thou shalt condemn. This is the heritage 
of the servants of the LORD, and their righteousness is of me, saith the 
LORD.”

Isaiah 54:1 - (KJV)
https://www.bible.com/bible/1/ISA.54.17.KJV
```

### Alias to copy to clipboard

```shell
clip() {
	xclip -selection clipboard
}
```
Usage:
```shell
bible Isaiah 54 17 KJV | clip
```

### Alias to compare versions

```shell
bible_compare() {
  for i in "${@:4}"
  do
    echo -n "---------------------"
    printf '\n'
    bible "$1" "$2" "$3" $i
    printf '\n'
    echo -n "---------------------"
  done
}
```

Usage
```shell
bible_compare Isaiah 54 17 KJV NIV NLT NKJV ESV N78BM
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

## Credits
- Contains code from these sources:
  * [bible_verse-cli](https://github.com/RaynardGerraldo/bible_verse-cli/blob/master/bible_verse)
  * Answer on stackoverflow: [Iterate over arguments](https://stackoverflow.com/a/37056727)

## Donations
<a href="https://coindrop.to/tmiland" target="_blank"><img src="https://coindrop.to/embed-button.png" style="border-radius: 10px; height: 57px !important;width: 229px !important;" alt="Coindrop.to me"></img></a>

#### Disclaimer 

*** ***Use at own risk*** ***

### License

[![MIT License Image](https://upload.wikimedia.org/wikipedia/commons/thumb/0/0c/MIT_logo.svg/220px-MIT_logo.svg.png)](https://github.com/tmiland/bible.sh/blob/master/LICENSE)

[MIT License](https://github.com/tmiland/bible.sh/blob/master/LICENSE)