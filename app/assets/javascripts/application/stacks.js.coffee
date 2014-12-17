class RollbackPreview
  @for: (element) ->
    $element = $(element)
    unless instance = $element.data('rollback-preview')
      instance = new RollbackPreview($element)
      $element.data('rollback-preview', instance)
    instance

  constructor: (@$button) ->
    $rollbackable = @$button.closest('[data-rollbackable]')
    @$scope = $rollbackable.add($rollbackable.prevAll('[data-rollbackable]'))

  toggle: (show) ->
    @$scope.toggleClass('rolling-back', show)

$(document).on 'mouseenter mouseleave', '.rollback-action', (event) ->
  RollbackPreview.for(this).toggle(event.type == 'mouseenter')

jQuery ($) ->
  displayConfigureCiMessage = ->
    commits = $('.commit')
    ciConfigured = !commits.length || commits.length != commits.find('div.unknown').length
    $('.configure-ci').toggleClass('hidden', ciConfigured)
    return

  displayConfigureCiMessage()

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
