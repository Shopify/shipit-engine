jQuery ($) ->
  displayIgnoreCiMessage = ->
    ignoreCiMessage = $(".ignoring-ci")
    return unless ignoreCiMessage
    $('.dismiss-ignore-ci-warning').click (event) ->
      event.preventDefault()
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
    $('[data-layout-content]').load("#{payload.url} [data-layout-content] > *", -> $('time[data-time-ago]').timeago())

  retries = 0
  listenToEventSource = (url) ->
    source = new EventSource(url)
    source.addEventListener 'stack.update', updatePage
    interval = setInterval ->
      switch source.readyState
        when source.CLOSED
          clearInterval(interval)
          if retries > 0
            retries -= 1
            listenToEventSource(url)
        else
          retries = 2
    , 30000

  $('[data-event-stream]').each ->
    listenToEventSource($(this).data('event-stream'))

  $(document).on 'click', '.setting-ccmenu input[type=submit]', (event) ->
    event.preventDefault()
    $(event.target).prop('disabled', true)
    $.get(event.target.dataset.remote).done((data) ->
      $('#ccmenu-url').val(data.ccmenu_url).removeClass('hidden')
      $(event.target).addClass('hidden')
    ).fail(->
      $(event.target).prop('disabled', false)
    )
