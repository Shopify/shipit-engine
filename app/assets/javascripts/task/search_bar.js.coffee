class @SearchBar
  DEBOUNCE = 300

  constructor: (@$bar) ->
    @eventListeners = {}
    @query = ''
    @$input = @$bar.find('.search-input')
    @$input.on('blur', @closeIfEmpty)
    @$input.on('input', @updateQuery)
    @broadcastQueryChange = _.debounce(@rawBroadcastQueryChange, DEBOUNCE)
    Mousetrap.bind(['command+f', 'ctrl+f'], @open)

  addEventListener: (type, handler) ->
    @listeners(type).push(handler)

  listeners: (type) ->
    @eventListeners[type] ||= []

  updateQuery: =>
    oldQuery = @query
    @query = @$input.val()
    @broadcastQueryChange() unless @query == oldQuery

  rawBroadcastQueryChange: =>
    for handler in @listeners('query')
      handler(@query)

  open: (event) =>
    event.preventDefault()
    @$bar.removeClass('hidden')
    @focus()

  focus: ->
    @$input.focus()[0].select()

  closeIfEmpty: (event) =>
    @close() unless @query.length

  close: ->
    @$bar.addClass('hidden')
