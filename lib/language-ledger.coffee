{Ledger} = require 'ledger-cli'
{TextEditor, CompositeDisposable} = require 'atom'
fsm = require 'javascript-state-machine'
pluralize = require 'pluralize'

module.exports =
  output: null
  subscriptions: null

  # Your config schema!
  config:
    ledgerBinary:
      title: 'Ledger binary'
      description: 'Full path to the Ledger binary'
      type: 'string'
      default: 'path/to/ledger'

  activate: (state) ->
    @output ?= atom.notifications

    bufferFilePath = -> atom.workspace.getActivePaneItem()?.buffer.file?.path

    if not @subscriptions
      @subscriptions = new CompositeDisposable
      @subscriptions.add atom.workspace.observePaneItems (item) =>
        return unless item?
        return unless item instanceof TextEditor

        editor = item
        {name} = editor.getGrammar()
        return unless name is 'Ledger'

        buffer = editor.getBuffer()
        @subscriptions?.add @disposableFor(buffer)

  disposableFor: (buffer) ->
    # There is just one disposable right now: it passes the buffers file to
    # Ledger when it is saved. Parser errors will be reported. Also the first
    # successful pass will be reported. This behavior is modeled by a FSM.

    # One notification per buffer
    bufferNotification = null

    # One report FSM per buffer
    bufferReport = fsm.create
      initial: 'init'
      events: [
        {name: 'fail', from: ['*'], to: 'error'},
        {name: 'pass', from: ['error'], to: 'passLoud'},
        {name: 'pass', from: ['init', 'passLoud', 'passMute'], to: 'passMute'}
      ]
      callbacks:
        onpassLoud: (event, from, to, {detail}) =>
          bufferNotification?.dismiss()
          bufferNotification = @output.addInfo "Ledger journal errors are fixed\n",
            dismissable: false
            detail: detail
        onfail: (event, from, to, {detail}) =>
          bufferNotification?.dismiss()
          bufferNotification = @output.addError "Ledger journal has errors\n",
            dismissable: true
            detail: detail

    disposable = buffer.onDidSave ({path}) =>
      ledger = new Ledger
        binary: atom.config.get 'language-ledger.ledgerBinary'
        file: path
      ledger.stats (err, stat) =>
        if (err?)
          bufferReport.fail detail: @failDetail(err)
        else
          detail: null
          if (stat.files?)
            sf = stat.files
            detail = "  in #{pluralize('file', sf.length)} #{sf.join(', ')}"
          bufferReport.pass {detail}

    buffer.onDidDestroy () => @subscriptions?.remove(disposable)
    return disposable

  failDetail: (message) ->
    parserErrorPattern = /While parsing file +\"(.+)\", line ([\d]+): [\n\r]+([\s\S]+)$/m
    hasParserError = parserErrorPattern.test message

    if hasParserError
      blocks = message.match parserErrorPattern
      error = message.trim().split("\n").pop() # parser error in last line
      "  in file #{blocks[1]}, line: #{parseInt(blocks[2])}\n#{error}"

  deactivate: ->
    console.log "deactivate"
    @subscriptions?.dispose()
    @output?.detach()

  serialize: ->
    console.log "serialize"
    ledgerViewState: @output?.serialize()
