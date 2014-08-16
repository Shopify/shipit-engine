class @Sidebar
  PLUGINS = []

  @registerPlugin: (plugin) ->
    PLUGINS.push(plugin)

  @init: ($window, $container) ->
    new this($window, $container)

  constructor: (@$window, @$container) ->
    @saveMinTop()
    @$window.scroll(@updatePosition)
    for plugin in PLUGINS
      plugin.appendTo(@appendPluginContainer())

  updatePosition: =>
    @$container.toggleClass('fixed', @$window.scrollTop() > @minTop)

  appendPluginContainer: ->
    $('<div>').addClass('sidebar-plugin').appendTo(@$container)

  saveMinTop: ->
    @minTop = @$container.position()?.top || 0
