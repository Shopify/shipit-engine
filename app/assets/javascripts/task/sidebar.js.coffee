class @Sidebar
  INSTANCE = null

  @instance: ->
    INSTANCE ||= new this($('.sidebar'), $('.sidebar-plugins'))

  @newWidgetContainer: ->
    Sidebar.instance().newWidgetContainer()

  constructor: (@$sidebar, @$container) ->

  newWidgetContainer: ->
    @$sidebar.addClass('enabled')
    $(document.createElement('div')).addClass('sidebar-plugin').prependTo(@$container)
