class Chunk
  constructor: (@raw) ->

  rawText: ->
    @raw

  text: ->
    @_text ||= AnsiStream.strip(@raw)

  rawLines: ->
    @_rawLines ||= @raw.split(/\r?\n/)

  lines: ->
    @_lines ||= @text().split(/\r?\n/)

class Stream
  INTERVAL = 1000
  MAX_RETRIES = 15

  constructor: ->
    @url = null
    @eventListeners = {}
    @retries = 0
    @status = 'running'

  init: ({url, text, status}) ->
    @status = status
    @broadcastChunk(text)
    @start(url)

  poll: =>
    jQuery.ajax @url,
      success: @success
      error: @error

  success: (response) =>
    @retries = 0
    @broadcastChunks(response.chunks)
    @broadcastStatus(response.status)
    @start(response.url || false)

  broadcastStatus: (status) ->
    if status != @status
      @status = status
      for handler in @listeners('status')
        handler(status)

  broadcastChunk: (raw) ->
    chunk = new Chunk(raw)
    for handler in @listeners('chunk')
      handler(chunk)

  broadcastChunks: (chunks) ->
    @broadcastChunk((c.text for c in chunks).join(''))

  error: (response) =>
    @start() if 600 > response.status >= 500 && (@retries += 1) < MAX_RETRIES

  start: (url = @url) ->
    if @url = url
      setTimeout(@poll, INTERVAL)

  addEventListener: (type, handler) ->
    @listeners(type).push(handler)

  listeners: (type) ->
    @eventListeners[type] ||= []

@OutputStream = new Stream
