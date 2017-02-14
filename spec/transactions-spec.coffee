TransactionsView = require '../lib/transactions-view'

describe "Ledger transactions view", ->
  [editor, transactionsView] = []

  beforeEach ->
    waitsForPromise ->
      atom.packages.activatePackage('language-ledger')

    waitsForPromise ->
      atom.workspace.open()

    runs ->
      editor = atom.workspace.getActiveTextEditor()
      transactionsView = new TransactionsView(editor)

  describe "when the editor has added transactions", ->
    beforeEach ->
      editor.insertText('2015/01/01 foo')
      editor.insertNewline()
      editor.insertText('2015/01/01 ! bar')
      editor.insertNewline()
      editor.insertText('2015/01/01 * baz')
      editor.insertNewline()

    it "retrieves the transactions", ->
      expect(TransactionsView.getTransactions(editor, ['meta.transaction.cleared']).length).toBe 1
      expect(TransactionsView.getTransactions(editor, ['meta.transaction.uncleared']).length).toBe 1
      expect(TransactionsView.getTransactions(editor, ['meta.transaction.pending']).length).toBe 1
      expect(TransactionsView.getTransactions(editor).length).toBe 3

    it "marks the transactions", ->
      advanceClock(editor.getBuffer().stoppedChangingDelay)

      markers = editor.findMarkers()
      expect(markers.length).toEqual 3

  describe "when the editor is showing fixture", ->
    beforeEach ->
      fixture = null
      waitsForPromise ->
        atom.workspace.open('drewr3.dat').then (o) -> fixture = o

      runs ->
        @editor = fixture
        @transactionsView = new TransactionsView(@editor)

    it "retrieves the transactions", ->
      expect(TransactionsView.getTransactions(@editor).length).toBe 11
      expect(TransactionsView.getTransactions(@editor, ["meta.transaction.cleared"]).length).toBe 2
      expect(TransactionsView.getTransactions(@editor, ["meta.transaction.uncleared"]).length).toBe 9
      expect(TransactionsView.getTransactions(@editor, ["meta.transaction.pending"]).length).toBe 0

    it "marks the transactions", ->
      @editor.setGrammar(atom.grammars.selectGrammar('source.ledger'))
      editorView = atom.views.getView(@editor)
      jasmine.attachToDOM(editorView)

      advanceClock(@editor.getBuffer().stoppedChangingDelay)

      markers = @editor.findMarkers()
      expect(markers.length).toEqual 11

      decorationsCls = []
      decorationObserverDisposable = @editor.observeDecorations((decoration) -> decorationsCls.push(decoration.getProperties().class))
      decorationObserverDisposable.dispose()

      expect(decorationsCls.filter((cls) -> cls.includes('ledger-transaction')).length).toEqual markers.length

  describe "move-to-next-transaction/move-to-previous-transaction events", ->
    [editorView] = []

    beforeEach ->
      editor.setGrammar(atom.grammars.selectGrammar('source.ledger'))
      editorView = atom.views.getView(editor)
      jasmine.attachToDOM(editorView)

      editor.insertText('2015/01/01 foo')
      editor.insertNewline()
      editor.insertText('2015/01/01 bar')
      editor.insertNewline()
      editor.insertText('2015/01/01 baz')
      editor.insertNewline()
      advanceClock(editor.getBuffer().stoppedChangingDelay)

    it "moves the cursor to first character of the next/previous transaction", ->
      editor.setCursorBufferPosition {row: 1, column: 0}
      atom.commands.dispatch(editorView, 'ledger:move-to-next-transaction')
      expect(editor.getCursorBufferPosition()).toEqual {row: 2, column: 0}

      editor.setCursorBufferPosition {row: 2, column: Infinity}
      atom.commands.dispatch(editorView, 'ledger:move-to-previous-transaction')
      expect(editor.getCursorBufferPosition()).toEqual {row: 1, column: 0}

    it "wraps around to the first/last transaction in the file", ->
      editor.setCursorBufferPosition {row: 2}
      atom.commands.dispatch(editorView, 'ledger:move-to-next-transaction')
      expect(editor.getCursorBufferPosition()).toEqual {row: 0}

      atom.commands.dispatch(editorView, 'ledger:move-to-previous-transaction')
      expect(editor.getCursorBufferPosition()).toEqual {row: 2}
