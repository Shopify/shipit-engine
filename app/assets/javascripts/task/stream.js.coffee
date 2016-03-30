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

class @Stream
  INTERVAL = 1000
  MAX_RETRIES = 15

  constructor: ->
    @url = null
    @eventListeners = {}
    @retries = 0
    @status = 'running'

  init: ({url, status}) ->
    @status = status
    @start(url)

  poll: =>
    jQuery.ajax @url,
      success: @success
      error: @error

  success: (response) =>
    @retries = 0
    @broadcastOutput(response.output, response)
    @broadcastStatus(response.status, response)
    @start(response.url || false)

  broadcastStatus: (status, args...) ->
    if status != @status
      @status = status
      for handler in @listeners('status')
        try
          handler(status, args...)
        catch error
          console?.log("Plugin error: #{error}")

  broadcastOutput: (raw, args...) ->
    if raw
      chunk = new Chunk(raw)
      for handler in @listeners('chunk')
        try
          handler(chunk, args...)
        catch error
          console?.log("Plugin error: #{error}")

  error: (response) =>
    @start() if 600 > response.status >= 500 && (@retries += 1) < MAX_RETRIES

  start: (url = @url) ->
    if @url = url
      setTimeout(@poll, INTERVAL)

  addEventListener: (type, handler) ->
    @listeners(type).push(handler)

  listeners: (type) ->
    @eventListeners[type] ||= []
