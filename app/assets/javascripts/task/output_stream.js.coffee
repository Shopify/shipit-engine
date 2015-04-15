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
    @broadcastRawText(text)
    @start(url)

  poll: =>
    jQuery.ajax @url,
      success: @success
      error: @error

  success: (response) =>
    @retries = 0
    @broadcastChunks(response.chunks)
    @broadcastStatus(response.task)
    @start(response.url || false)

  broadcastStatus: (task) ->
    if task.status != @status
      @status = task.status
      for handler in @listeners('status')
        handler(task)

  broadcastRawText: (raw) ->
    text = AnsiStream.strip(raw)

    for handler in @listeners('chunk')
      handler(raw: raw, text: text)

    raw_lines = raw.split('\n')
    for raw in raw_lines
      text = AnsiStream.strip(raw)
      for handler in @listeners('line')
        handler(raw: raw, text: text)

  broadcastChunks: (chunks) ->
    @broadcastRawText((c.text for c in chunks).join())

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
