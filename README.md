# Ledger language support in Atom [![Build Status](https://travis-ci.org/4ourbit/language-ledger.svg?branch=master)](https://travis-ci.org/4ourbit/language-ledger)

Adds syntax highlighting and parser error reports to [Ledger](http://ledger-cli.org/)
files in Atom.

Grammar definition inspired by the [Ledger TextMate bundle](https://github.com/lifepillar/Ledger.tmbundle).

Contributions are greatly appreciated. Please fork this repository and open a
pull request to add snippets, make grammar tweaks, etc.

## Parser error reports

The Ledger binary should be set in the package settings pane. It will be used to
silently check the journal file anytime it is saved. If there are parser errors,
a notification is shown.

![Parser](http://fs1.directupload.net/images/150321/vz2phip4.gif)
