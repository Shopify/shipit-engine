unless String::contains
  String::contains = (args...) ->
    @indexOf(args...) != -1

KEY =
  UP: 38
  DOWN: 40
  ENTER: 13

class StackSearch

  constructor: (root) ->
    @$root = $(root)
    @$root.on('keyup', '.stack-search', @onKeyUp)
    @$root.on('click', '#show-all-stacks', (e) =>
      @$root.find('.not-matching').removeClass('not-matching')
      e.preventDefault()
    )

  onKeyUp: (event) =>
    @$items = @$root.find('[data-search]')
    switch event.keyCode
      when KEY.ENTER
        event.preventDefault()
        @goToSelectedStack()
      when KEY.UP
        event.preventDefault()
        @selectPrevious()
      when KEY.DOWN
        event.preventDefault()
        @selectNext()
      else
        @filterResults($.trim($(event.target).val()).toLowerCase())

  filterResults: (query) ->
    if query
      for item in @$items
        $item = $(item)
        $item.toggleClass('not-matching', !$item.attr('data-search').toLowerCase().contains(query))
      @selectFirst()
    else
      @$items.removeClass('not-matching')

  selectFirst: ->
    @$items.removeClass('selected').first(':not(.not-matching)').addClass('selected')

  selectNext: ->
    $next = @$items.filter('.selected').removeClass('selected').nextAll(':not(.not-matching)').first()
    $next = @$items.filter(':not(.not-matching)').first() unless $next.length
    $next.addClass('selected')

  selectPrevious: ->
    $previous = @$items.filter('.selected').removeClass('selected').prevAll(':not(.not-matching)').first()
    $previous = @$items.filter(':not(.not-matching)').last() unless $previous.length
    $previous.addClass('selected')

  goToSelectedStack: ->
    if stack = @$items.filter('.selected').filter(':not(.not-matching)').find('.commits-path').attr('href')
      window.location = stack

search = new StackSearch(document)

jQuery ->
  $('.stack-search').focus()
