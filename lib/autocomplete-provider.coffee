execFile = require('child_process').execFile

module.exports =
  selector: '.source.ledger .string.account'
  inclusionPriority: 2
  suggestionPriority: 1

  getSuggestions: ({editor, prefix, bufferPosition}) ->
    accounts = @getAccountNames(editor)
    prefix = @getPrefix(editor, bufferPosition)
    prefix_low = prefix.toLowerCase()

    filter = (acc, pref) ->
      return acc.toLowerCase().indexOf(pref) >= 0

    suggestions = ({text: a, replacementPrefix: prefix} for a in accounts when filter(a, prefix_low))
    suggestions

  getPrefix: (editor, bufferPosition) ->
    line = editor.getTextInRange([[bufferPosition.row, 0], bufferPosition])
    line.trim()

  getAccountNames: (editor) ->
    if (editor.ledgerAccountsList?)
      return editor.ledgerAccountsList
    return @loadAccounts(editor)

  dispose: ->
    @disposable.dispose()

  loadAccounts: (editor) ->
    unless @disposable?
      @disposable = editor.onDidSave (event) =>
        editor.ledgerAccountsList = undefined
    escapedPath = editor.getPath().split("'''").join("\\'\\'\\'")
    pythonScript = """
import ledger
def print_recursive(accounts):
  for a in accounts:
    print a.fullname()
    print_recursive(a.accounts())

print_recursive(ledger.read_journal('''#{escapedPath}''').master.accounts())
"""
    ledgerBinary = atom.config.get 'language-ledger.ledgerBinary'
    return new Promise (resolve, reject) ->
      proc = execFile ledgerBinary, ["python"], {windowsHide: true}, (err, result, stderr) =>
        if (err?)
          console.log(err)
          reject []
        else
          editor.ledgerAccountsList = result.split "\n"
          resolve editor.ledgerAccountsList
      proc.stdin.end(pythonScript)
