class PageUpdater
  DEBOUNCE = 100
  RETRY_DELAY = 5000
  MAX_RETRIES = 5

  @callbacks: []
  @afterUpdate: (callback) ->
    @callbacks.push(callback)

  constructor: (@channel, @selectors) ->
    @parser = new DOMParser()
    @source = @listen()
    @previousLastModified = null

  requestUpdate: =>
    @updateRequested = true
    @scheduleUpdate()

  scheduleUpdate: =>
    return if @updateScheduled
    return unless @updateRequested
    setTimeout(@fetchPage, DEBOUNCE)
    @updateScheduled = true

  fetchPage: (message) =>
    @updateRequested = false
    jQuery.get(window.location.toString()).done(@updatePage).fail(=> @updateScheduled = false)

  updatePage: (html, status, response) =>
    lastModified = response.getResponseHeader('last-modified')
    if lastModified? and lastModified != @previousLastModified
      @previousLastModified = lastModified

      newDocument = @parser.parseFromString(html, 'text/html')
      for selector in @selectors
        $(selector).html(newDocument.querySelectorAll("#{selector} > *"))
      for callback in PageUpdater.callbacks
        callback()

    @updateScheduled = false

  listen: ->
    @source = new EventSource(@channel)
    @source.addEventListener('update', @requestUpdate)
    @retries = MAX_RETRIES
    @interval = setInterval =>
      switch @source.readyState
        when @source.CLOSED
          clearInterval(@interval)
          if @retries > 0
            @retries -= 1
            @listen()
        else
          @retries = MAX_RETRIES
    , RETRY_DELAY

jQuery ($) ->
  PageUpdater.afterUpdate -> $('time[data-time-ago]').timeago()

  channel = $('meta[name=subscription-channel]').attr('content')
  selectors = (e.content for e in $('meta[name=subscription-selector]'))
  if channel and selectors
    new PageUpdater(channel, selectors)
