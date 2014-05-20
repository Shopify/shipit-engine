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
    @$root.on('keydown', '.stack-search', @onKeyUp)

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
    window.location = @$items.filter('.selected').find('.commits-path').attr('href')

search = new StackSearch(document)

jQuery ->
  $('.stack-search').focus()
