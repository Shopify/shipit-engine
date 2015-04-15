#= require ansi_stream
#= require ./tty

stream = new AnsiStream()
TTY.appendFormatter (chunk) ->
  stream.process(chunk)
