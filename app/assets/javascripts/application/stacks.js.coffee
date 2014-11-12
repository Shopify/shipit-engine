jQuery ($) ->
  displayConfigureCiMessage = ->
    commits = $('.commit')
    ciConfigured = !commits.length || commits.length != commits.find('div.unknown').length
    $('.configure-ci').toggleClass('hidden', ciConfigured)
    return

  displayConfigureCiMessage()

  updatePage = (message) ->
    payload = JSON.parse(message.data)
    $('.layout').load("#{payload.url} .layout > *").find('time[data-time-ago]').timeago()

  listenToEventSource = (url) ->
    source = new EventSource(url)
    reconnect = -> listenToEventSource(url)
    #source.onerror = -> setTimeout(reconnect, 3000)
    source.addEventListener 'stack.update', updatePage

  $('[data-event-stream]').each ->
    listenToEventSource($(this).data('event-stream'))
