'use babel';

import {CompositeDisposable} from 'atom'

export default class TransactionsView {
  constructor(editor) {
    this.editor = editor
    this.subscriptions = new CompositeDisposable()
    this.transactions = []
    this.markers = []

    this.subscriptions.add(this.editor.onDidStopChanging(this.updateTransactions))
    this.subscriptions.add(this.editor.onDidDestroy(() => {
      this.cancelUpdate()
      this.removeHighlightings()
      this.subscriptions.dispose()
    }))

   const editorView = atom.views.getView(editor)
   this.subscriptions.add(atom.commands.add(editorView,
     'ledger:move-to-next-transaction', this.moveToNextTransaction))
   this.subscriptions.add(atom.commands.add(editorView,
     'ledger:move-to-previous-transaction', this.moveToPreviousTransaction))

    this.scheduleUpdate()
  }

  static getTransactions(editor, transactionScopes = [
      'meta.transaction.cleared',
      'meta.transaction.uncleared',
      'meta.transaction.pending']) {
    const transactions = []

    const grammar = atom.grammars.grammarForScopeName('source.ledger')
    atom.assert(grammar !== undefined, "Ledger grammar is defined")

    let current, row = 0
    while (row < editor.getLineCount()) {
      const line = editor.lineTextForBufferRow(row)

      var {ruleStack, tags} = grammar.tokenizeLine(line, ruleStack, row === 0)
      function scopeEnds({scope}) {
        for (tag of tags) {
          if (atom.grammars.scopeForId(tag) === scope) return true
        }
        return false
      }

      if (current !== undefined && scopeEnds(current)) {
        transactions.push(current)
        current = undefined
      }

      for ({scopeName} of ruleStack) {
        if (transactionScopes.indexOf(scopeName) == -1) continue
        if (current !== undefined && current.scope === scopeName) {
          ++ current.rowEnd
        } else {
          current = {
            scope: scopeName,
            rowStart: row,
            rowEnd: row + 1
          }
        }
      }
      ++ row
    }
    return transactions
  }

  moveToNextTransaction = () => {
    let cursorLineNumber = this.editor.getCursorBufferPosition().row + 1
    let nextTransactionLineNumber = Infinity
    let firstTransactionLineNumber = Infinity
    for ({rowStart} of this.transactions) {
      if (rowStart > cursorLineNumber - 1) {
        nextTransactionLineNumber = Math.min(rowStart - 1, nextTransactionLineNumber)
      }
      firstTransactionLineNumber = Math.min(rowStart - 1, firstTransactionLineNumber)
    }

    // Wrap around to the first transaction in the file
    if (nextTransactionLineNumber === Infinity) {
      nextTransactionLineNumber = firstTransactionLineNumber
    }

    this.moveToLineNumber(nextTransactionLineNumber + 1)
  }

  moveToPreviousTransaction = () => {
    let cursorLineNumber = this.editor.getCursorBufferPosition().row + 1
    let previousTransactionLineNumber = -Infinity
    let lastTransactionLineNumber = -Infinity
    for ({rowStart} of this.transactions) {
      if (rowStart + 1 < cursorLineNumber) {
        previousTransactionLineNumber = Math.max(rowStart - 1, previousTransactionLineNumber)
      }
      lastTransactionLineNumber = Math.max(rowStart - 1, lastTransactionLineNumber)
    }

    // Wrap around to the last transaction in the file
    if (previousTransactionLineNumber === -Infinity) {
      previousTransactionLineNumber = lastTransactionLineNumber
    }

    this.moveToLineNumber(previousTransactionLineNumber + 1)
  }

  moveToLineNumber = (lineNumber=-1) => {
    if (lineNumber >= 0) {
      this.editor.setCursorBufferPosition([lineNumber, 0])
      this.editor.moveToFirstCharacterOfLine()
    }
  }

  cancelUpdate = () => {
    clearImmediate(this.immediateId)
  }

  scheduleUpdate = () => {
    this.cancelUpdate()
    this.immediateId = setImmediate(this.updateTransactions)
  }

  updateTransactions = () => {
    if (this.editor.isDestroyed()) return

    this.removeHighlightings()
    this.transactions = this.constructor.getTransactions(this.editor)
    if (this.transactions.length > 0) {
      this.addHighlightings(this.transactions)
    }
  }

  addHighlightings = (region) => {
    for ({rowStart, rowEnd, scope} of region) {
      if (scope === 'meta.transaction.cleared') {
        this.highlightRange(rowStart, rowEnd, 'ledger-transaction-cleared')
      }
      if (scope === 'meta.transaction.uncleared') {
        this.highlightRange(rowStart, rowEnd, 'ledger-transaction-uncleared')
      }
      if (scope === 'meta.transaction.pending') {
        this.highlightRange(rowStart, rowEnd, 'ledger-transaction-pending')
      }
    }
    return
  }

  highlightRange = (rowStart, rowEnd, klass) => {
    marker = this.editor.markBufferRange([[rowStart, 0], [rowEnd, 0]], {invalidate: 'never'})
    this.editor.decorateMarker(marker, {type: 'highlight', class: klass})
    this.markers.push(marker)
  }

  removeHighlightings = () => {
    for (marker of this.markers) {
      marker.destroy()
    }
    this.markers = []
  }
}
