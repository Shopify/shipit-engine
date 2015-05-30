class @Sidebar
  INSTANCE = null

  @instance: ->
    INSTANCE ||= new this($(window), $('.sidebar-plugins'))

  @newWidgetContainer: ->
    Sidebar.instance().newWidgetContainer()

  constructor: (@$window, @$container) ->
    @saveMinTop()
    @$window.scroll(@updatePosition)
    @$window.resize(@updatePosition)
    @$outerContainer = @$container.parent()

  updatePosition: =>
    @$container.toggleClass('sticky', @$window.scrollTop() > @minTop)
    @$container.height($(window).height() - @$container[0].getBoundingClientRect().top)

  newWidgetContainer: ->
    $(document.createElement('div')).addClass('sidebar-plugin').prependTo(@$container)

  saveMinTop: ->
    @minTop = @$container.position()?.top || 0
