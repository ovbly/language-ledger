{TextEditor} = require 'atom'
path = require 'path'

describe "Ledger grammar", ->
  [grammar] = []

  beforeEach ->
    grammarFile = path.join __dirname, '../grammars/ledger.cson'
    grammar = atom.grammars.readGrammarSync grammarFile

  it "parses the grammar", ->
    expect(grammar).toBeTruthy()
    expect(grammar.scopeName).toBe 'source.ledger'

  describe "grammar", ->
    it "tokenizes line comments", ->
      tokensByLines = grammar.tokenizeLines """
; This is a single line comment,
#  and this,
%   and this,
|    and this,
*     and this.
"""
      for tokens in tokensByLines
        expect(tokens[0].value).toMatch /[Tt]his/
        expect(tokens[0].scopes).toEqual ['source.ledger', 'comment.line']

  describe "directives", ->
    it "tokenizes directives", ->
      directiveLists =
        'keyword.account': ['account']
        'keyword.commodity': ['commodity']
        'keyword.directive': [
          'apply tag', 'end tag',
          'alias',
          'assert',
          'bucket',
          'capture',
          'check',
          'define',
          'include',
          'tag',
          'year', 'Y']

      for scope, list of directiveLists
        for directive in list
          {tokens} = grammar.tokenizeLine directive
          expect(tokens[0].value).toEqual directive
          expect(tokens[0].scopes).toEqual ['source.ledger', 'meta.directive', scope]

# TODO
    xit "tokenizes block directives and block comments", ->
      directiveLists =
        'directive.block': ['apply account', 'apply tag']
        'comment.block' : ['comment']

      for scope, list of directiveLists
        for directive in list
          tokensByLines = grammar.tokenizeLines """
#{directive}
  This is a block directive or block comment with
  multiple lines
end #{directive}
"""
          expect(tokensByLines[0][0].value).toEqual directive
          for tokens in tokensByLines
            expect(tokens[0].scopes).toEqual ['source.ledger', 'meta.directive', scope]

    it "tokenizes accounts declared by account directive", ->
      {tokens} = grammar.tokenizeLine('account equity')
      expect(tokens[2].value).toEqual 'equity'
      expect(tokens[2].scopes).toEqual ['source.ledger', 'meta.directive', 'string.account']

    it "tokenizes commodities declared by commodity directive", ->
      {tokens} = grammar.tokenizeLine('commodity $')
      expect(tokens[2].value).toEqual '$'
      expect(tokens[2].scopes).toEqual ['source.ledger', 'meta.directive', 'constant.other.symbol.commodity']

      {tokens} = grammar.tokenizeLine('commodity EUR')
      expect(tokens[2].value).toEqual 'EUR'
      expect(tokens[2].scopes).toEqual ['source.ledger', 'meta.directive', 'constant.other.symbol.commodity']

  describe "transactions", ->
    it "tokenizes transactions", ->
      tokensByLines = grammar.tokenizeLines """
2015/01/01 (1000) payee  ; comment
  foo    1.01   ; comment
  bar  $-1.02   ; no 7.00
  baz   +0,01 € ; ; ;
  fizz   AAPL 10
  bu zz  GOOG  1
  ; comment
  quux
"""
      transactionTokens = ['source.ledger', 'meta.transaction.uncleared']
      expectedLines = []
      expectedLines.push [
        {'2015/01/01': transactionTokens.concat ['constant.numeric.date.transaction']}
        {' '         : transactionTokens}
        {'(1000)'    : transactionTokens.concat ['entity.payee.transaction', 'constant.other.symbol.code']}
        {' '         : transactionTokens.concat ['entity.payee.transaction']}
        {'payee'     : transactionTokens.concat ['entity.payee.transaction', 'string.payee.transaction']}
        {'  '        : transactionTokens.concat ['entity.payee.transaction']}
        {'; comment' : transactionTokens.concat ['entity.payee.transaction', 'comment.note.transaction']}
      ]

      postingTokens = transactionTokens.concat ['entity.transaction.posting']
      expectedLines.push [
        {'  '        : postingTokens}
        {'foo'       : postingTokens.concat ['string.account']}
        {'    '      : postingTokens}
        {'1.01'      : postingTokens.concat ['constant.numeric.amount']}
        {'   '       : postingTokens}
        {'; comment' : postingTokens.concat ['comment.transaction']}
      ]
      expectedLines.push [
        {'  '        : postingTokens}
        {'bar'       : postingTokens.concat ['string.account']}
        {'  '        : postingTokens}
        {'$'         : postingTokens.concat ['constant.other.symbol.commodity']}
        {'-1.02'     : postingTokens.concat ['constant.numeric.amount']}
        {'   '       : postingTokens}
        {'; no 7.00' : postingTokens.concat ['comment.transaction']}
      ]
      expectedLines.push [
        {'  '        : postingTokens}
        {'baz'       : postingTokens.concat ['string.account']}
        {'   '       : postingTokens}
        {'+0,01'     : postingTokens.concat ['constant.numeric.amount']}
        {' '         : postingTokens}
        {'€'         : postingTokens.concat ['constant.other.symbol.commodity']}
        {' '         : postingTokens}
        {'; ; ;'     : postingTokens.concat ['comment.transaction']}
      ]
      expectedLines.push [
        {'  '        : postingTokens}
        {'fizz'      : postingTokens.concat ['string.account']}
        {'   '       : postingTokens}
        {'AAPL'      : postingTokens.concat ['constant.other.symbol.commodity']}
        {' '         : postingTokens}
        {'10'        : postingTokens.concat ['constant.numeric.amount']}
      ]
      expectedLines.push [
        {'  '        : postingTokens}
        {'bu zz'     : postingTokens.concat ['string.account']}
        {'  '        : postingTokens}
        {'GOOG'      : postingTokens.concat ['constant.other.symbol.commodity']}
        {'  '        : postingTokens}
        {'1'         : postingTokens.concat ['constant.numeric.amount']}
      ]
      expectedLines.push [
        {'  '        : postingTokens}
        {'; comment' : postingTokens.concat ['comment.transaction']}
      ]
      expectedLines.push [
        {'  '        : postingTokens}
        {'quux'      : postingTokens.concat ['string.account']}
      ]

      for expectedLine, line in expectedLines
        expect(tokensByLines[line].length).toEqual expectedLine.length
        for token, index in expectedLine
          for value, scopes of token
            expect(tokensByLines[line][index].value).toEqual value
            expect(tokensByLines[line][index].scopes).toEqual scopes

    it "tokenizes flagged transactions", ->
      {tokens} = grammar.tokenizeLine '2015/01/01 ! 1000 payee  ; comment'

      pendingTransaction = ['source.ledger', 'meta.transaction.pending']
      expect(tokens[2].value).toEqual '!'
      expect(tokens[2].scopes).toEqual pendingTransaction.concat ['keyword.transaction.pending']

      {tokens} = grammar.tokenizeLine '2015/01/01 * 1000 payee  ; comment'

      clearedTransaction = ['source.ledger', 'meta.transaction.cleared']
      expect(tokens[2].value).toEqual '*'
      expect(tokens[2].scopes).toEqual clearedTransaction.concat ['keyword.transaction.cleared']

  describe "indentation", ->
    beforeEach ->
      waitsForPromise ->
        atom.packages.activatePackage('language-ledger')

    expectPreservedIndentation = (text) ->
      editor = new TextEditor({})
      editor.setGrammar(grammar)

      editor.insertText(text)
      editor.selectAll()
      editor.autoIndentSelectedRows()

      actualLines = editor.getText().split("\n")
      expectedLines = text.split("\n")

      WhitespaceLine = /^\s*$/

      for actualLine, i in actualLines
        # Skip indentation check of whitespace-only lines, since the indents are
        # usually wanted at manual input. The whitespace package will remove
        # them, once the file is saved.
        unless WhitespaceLine.test(actualLine)
          expect([
            actualLine,
            editor.indentLevelForLine(actualLine)
          ]).toEqual([
            expectedLines[i],
            editor.indentLevelForLine(expectedLines[i])
          ], "on line #{i+1}")

    it "preserves fixture indentation", ->
      fixture = null
      waitsForPromise ->
        atom.project.open('drewr3.dat', autoIndent: false).then (o) -> fixture = o

      runs ->
        expectPreservedIndentation fixture.getText()
