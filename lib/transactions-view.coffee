{CompositeDisposable} = require 'atom'

module.exports =
class TransactionsView
  constructor: (@editor) ->
    @subscriptions = new CompositeDisposable()
    @markers = []

    @subscriptions.add(@editor.onDidStopChanging(@updateTransactions))

    @subscriptions.add @editor.onDidDestroy =>
      @cancelUpdate()
      @removeHighlightings()
      @subscriptions.dispose()

    editorView = atom.views.getView(@editor)

    @subscriptions.add atom.commands.add editorView, 'ledger:move-to-next-transaction', =>
      @moveToNextTransaction()
    @subscriptions.add atom.commands.add editorView, 'ledger:move-to-previous-transaction', =>
      @moveToPreviousTransaction()

    @scheduleUpdate()

  getTransactions: (transactionScopes) ->
    grammar = atom.grammars.grammarForScopeName('source.ledger')
    atom.assert(grammar?, "Ledger grammar should be loaded")

    transactionScopes ?= [
      'meta.transaction.cleared',
      'meta.transaction.uncleared',
      'meta.transaction.pending'
    ]
    transactions = []

    row = 0
    ruleStack = null
    current = null
    while row < @editor.getLineCount()
      line = @editor.lineTextForBufferRow(row)
      {ruleStack, tags} = grammar.tokenizeLine(line, ruleStack, row is 0)

      scopeEnds = ({scope}) =>
        for tag in tags
          if atom.grammars.scopeForId(tag) is scope
            return true
        return false

      if current? and scopeEnds(current)
        transactions.push(current)
        current = null

      for {scopeName} in ruleStack when scopeName in transactionScopes
        if current?.scope is scopeName
          ++ current.rowEnd
        else
          current = {
            scope: scopeName
            rowStart: row
            rowEnd: row + 1
          }
      ++ row
    transactions

  moveToNextTransaction: ->
    cursorLineNumber = @editor.getCursorBufferPosition().row + 1
    nextTransactionLineNumber = Infinity
    firstTransactionLineNumber = Infinity
    for {rowStart} in @transactions ? []
      if rowStart > cursorLineNumber - 1
        nextTransactionLineNumber = Math.min(rowStart - 1, nextTransactionLineNumber)
      firstTransactionLineNumber = Math.min(rowStart - 1, firstTransactionLineNumber)

    # Wrap around to the first transaction in the file
    nextTransactionLineNumber = firstTransactionLineNumber if nextTransactionLineNumber is Infinity

    @moveToLineNumber(nextTransactionLineNumber + 1)

  moveToPreviousTransaction: ->
    cursorLineNumber = @editor.getCursorBufferPosition().row + 1
    previousTransactionLineNumber = -Infinity
    lastTransactionLineNumber = -Infinity
    for {rowStart} in @transactions ? []
      if rowStart + 1 < cursorLineNumber
        previousTransactionLineNumber = Math.max(rowStart - 1, previousTransactionLineNumber)
      lastTransactionLineNumber = Math.max(rowStart - 1, lastTransactionLineNumber)

    # Wrap around to the last transaction in the file
    previousTransactionLineNumber = lastTransactionLineNumber if previousTransactionLineNumber is -Infinity

    @moveToLineNumber(previousTransactionLineNumber + 1)

  moveToLineNumber: (lineNumber=-1) ->
    if lineNumber >= 0
      @editor.setCursorBufferPosition([lineNumber, 0])
      @editor.moveToFirstCharacterOfLine()

  cancelUpdate: ->
    clearImmediate(@immediateId)

  scheduleUpdate: ->
    @cancelUpdate()
    @immediateId = setImmediate(@updateTransactions)

  updateTransactions: =>
    return if @editor.isDestroyed()

    @removeHighlightings()
    if @transactions = @getTransactions()
      @addHighlightings(@transactions)

  addHighlightings: (region) ->
    for {rowStart, rowEnd, scope} in region
      if scope is 'meta.transaction.cleared'
        @highlightRange(rowStart, rowEnd, 'transaction-cleared')
      if scope is 'meta.transaction.uncleared'
        @highlightRange(rowStart, rowEnd, 'transaction-uncleared')
      if scope is 'meta.transaction.pending'
        @highlightRange(rowStart, rowEnd, 'transaction-pending')
    return

  highlightRange: (rowStart, rowEnd, klass) ->
    marker = @editor.markBufferRange([[rowStart, 0], [rowEnd, 0]], class: 'transaction', invalidate: 'never')
    @editor.decorateMarker(marker, type: 'highlight', class: klass)
    @markers.push(marker)

  removeHighlightings: ->
    marker.destroy() for marker in @markers
    @markers = []
