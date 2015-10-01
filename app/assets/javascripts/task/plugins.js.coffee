@Shipit ||= {}
@Shipit.Plugins =
  config: (name) ->
    config = $("""meta[name="#{name}-config"]""").attr('content')
    try
      JSON.parse(config)
    catch
      null
