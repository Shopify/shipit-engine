jQuery ($) ->
  displayIgnoreCiMessage = ->
    ignoreCiMessage = $(".ignoring-ci")
    return unless ignoreCiMessage
    $('.dismiss-ignore-ci-warning').click ->
      dismissIgnoreCiMessage()

    if localStorage.getItem(getLocalStorageKey())
      ignoreCiMessage.hide()

  dismissIgnoreCiMessage = ->
    localStorage.setItem(getLocalStorageKey(), true)
    ignoreCiMessage = $(".ignoring-ci")
    ignoreCiMessage.hide() if ignoreCiMessage

  getLocalStorageKey = ->
    stackName = $('.repo-name').data('repo-full-name')
    "ignoreCIDismissed" + stackName

  displayIgnoreCiMessage()

  updatePage = (message) ->
    payload = JSON.parse(message.data)
    $('.layout').load("#{payload.url} .layout > *", -> $('time[data-time-ago]').timeago())

  listenToEventSource = (url) ->
    source = new EventSource(url)
    reconnect = -> listenToEventSource(url)
    #source.onerror = -> setTimeout(reconnect, 3000)
    source.addEventListener 'stack.update', updatePage

  $('[data-event-stream]').each ->
    listenToEventSource($(this).data('event-stream'))
