stream = new AnsiStream()

ChunkPoller.registerFormatter (chunk) ->
  stream.process(chunk)
