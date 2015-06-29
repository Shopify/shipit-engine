class @StickyElement
  @init: (selector) ->
    $element = $(selector)
    return unless $element.length
    new @($element)

  constructor: (@$element) ->
    @staticElementTop = @$element.position().top
    @refresh()

  refresh: =>
    @toggleStickyClass()
    window.requestAnimationFrame(@refresh)

  toggleStickyClass: ->
    @$element.toggleClass('sticky', window.pageYOffset >= @staticElementTop)
