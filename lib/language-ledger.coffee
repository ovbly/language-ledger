{CompositeDisposable} = require 'atom'
{Ledger} = require 'ledger-cli'

bufferFilePath = -> atom.workspace.getActivePaneItem()?.buffer.file?.path

# callback: (err, data) -> undefined
ledgerStats = (journalPath, callback) ->
  ledger = new Ledger
    binary: atom.config.get 'language-ledger.ledgerBinary'
    file: journalPath
  ledger.stats callback

# callback: (err, data) -> undefined
ledgerTransactions = (journalPath, callback) ->
  ledger = new Ledger
    binary: atom.config.get 'language-ledger.ledgerBinary'
    file: journalPath
  # """--limit "uncleared" --empty"""
  transactions = []
  err = null
  ledger.register(['--uncleared'])
    .on   'data', (entry) -> transactions.push(entry)
    .once 'error', (err) -> callback(String(err), transactions)
    .once 'end', () -> callback(null, transactions)

module.exports =
  # Your config schema!
  config:
    ledgerBinary:
      title: 'Ledger binary'
      description: 'Full path to the Ledger binary'
      type: 'string'
      default: 'ledger'

  activate: (state) ->
    TransactionsView = require './transactions-view'

    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.workspace.observeTextEditors (editor) =>
      grammar = editor.getGrammar()
      return unless grammar.scopeName is 'source.ledger'

      new TransactionsView(editor)
      @handleParserReports(editor)

  handleParserReports: (editor) ->
    notification = null

    # Pass the file to Ledger when it is saved. Parser errors will issue a
    # notification, also the first successful pass. This is modeled by a FSM.
    FSM = require 'javascript-state-machine'
    fsm = FSM.create
      initial: 'init'
      events: [
        {name: 'fail', from: ['*'], to: 'error'},
        {name: 'pass', from: ['error'], to: 'passLoud'},
        {name: 'pass', from: ['init', 'passLoud', 'passMute'], to: 'passMute'}
      ]
      callbacks:
        onpassLoud: (event, from, to, {detail}) =>
          notification?.dismiss()
          notification = atom.notifications.addInfo "Ledger journal errors are fixed\n",
            dismissable: false
            detail: detail
        onfail: (event, from, to, {detail}) =>
          notification?.dismiss()
          notification = atom.notifications.addError "Ledger journal has errors\n",
            dismissable: true
            detail: detail

    buffer = editor.getBuffer()
    bufferSavedSubscription = buffer.onDidSave (file) =>
      failDetail = (message) ->
        parserErrorPattern = /While parsing file +\"(.+)\", line ([\d]+): [\n\r]+([\s\S]+)$/m
        hasParserError = parserErrorPattern.test message

        if hasParserError
          blocks = message.match parserErrorPattern
          error = message.trim().split("\n").pop() # parser error in last line
          "  in file #{blocks[1]}, line: #{parseInt(blocks[2])}\n#{error}"

      ledgerStats file.path, (err, stat) =>
        if (err?)
          fsm.fail detail: failDetail(err)
        else
          detail: null
          if (stat.files?)
            sf = stat.files
            pluralize = require 'pluralize'
            detail = "  in #{pluralize('file', sf.length)} #{sf.join(', ')}"
          fsm.pass {detail}

    editorDestroyedSubscription = editor.onDidDestroy =>
      bufferSavedSubscription.dispose()
      editorDestroyedSubscription.dispose()
      notification?.dismiss()
      reportingFsm = null

      @subscriptions.remove(bufferSavedSubscription)
      @subscriptions.remove(editorDestroyedSubscription)

    @subscriptions.add(bufferSavedSubscription)
    @subscriptions.add(editorDestroyedSubscription)

  deactivate: ->
    console.log "deactivate"
    @subscriptions?.dispose()

  serialize: ->
    console.log "serialize"
