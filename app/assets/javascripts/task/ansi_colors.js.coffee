#= require ansi_stream
#= require ./tty

AnsiStream.strip = (text) ->
  text.replace(/(?:(?:\u001b\[)|\u009b)(?:(?:[0-9]{1,3})?(?:(?:;[0-9]{0,3})*)?[A-M|f-m])|\u001b[A-M]/g, '')

entityMap =
 "&": "&amp;"
 "<": "&lt;"
 ">": "&gt;"
 '"': '&quot;'
 "'": '&#39;'
 "/": '&#x2F;'

escapeHtml = (string) ->
  String(string).replace(/[&<>"'\/]/g, (s) -> entityMap[s])

stream = new AnsiStream()

TTY.appendFormatter (chunk) ->
  stream.process(escapeHtml(chunk))
