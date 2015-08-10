# Ledger language support in Atom [![Build Status](https://travis-ci.org/4ourbit/language-ledger.svg?branch=master)](https://travis-ci.org/4ourbit/language-ledger)

Adds syntax highlighting, autocompletion and parser error reports to
[Ledger](http://ledger-cli.org/) files in Atom.

Grammar definition inspired by the [Ledger TextMate bundle](https://github.com/lifepillar/Ledger.tmbundle).

Contributions are greatly appreciated. Please fork this repository and open a
pull request to add snippets, make grammar tweaks, etc.

## Autocompletion

Autocompletion uses the [autocomplete-plus](https://atom.io/packages/autocomplete-plus)
package, that is bundled in Atom. In the `autocomplete-plus` settings pane
*Default Provider* should be set to `Symbol`. The *Minimum Word Length* setting
indicates when autocompletion is about to be triggered.

![Autocompletion](http://fs2.directupload.net/images/150521/xhkpxw44.gif)

## Parser error reports

In case it is not accessible from PATH, the *Ledger binary* should be set in the
`ledger-language` package settings pane. It will be used to silently check the
journal file anytime it is saved. If there are parser errors, a notification is
shown.

![Parser](http://fs1.directupload.net/images/150321/vz2phip4.gif)

## Transaction highlighting

Uncleared and pending transactions are highlighted by default. To customize the
highlighting, call the <kbd>Application: Open Your Stylesheet</kbd> command to
open `styles.less` and define the new highlighting styles there.

For example, add this snippet to disable highlighting of uncleared transactions:
```less
atom-text-editor::shadow .ledger-transaction-uncleared .region {
  background-color: transparent;
}
```
