#= require_tree ./borg/

class DataCenter
  LOG_PATTERN = /^\s*\[([a-zA-Z\d\.]+)\]\[\w+\] (.*)$/

  constructor: ->
    @hosts = {}

  parseLog: (line) ->
    if match = line.match(LOG_PATTERN)
      @host(match[1]).parseLog(match[2] || '')

  host: (name) ->
    unless @hosts[name]
      @hosts[name] = new Host(name)
      delete @sortedHosts
    @hosts[name]

  sorted: ->
    @sortedHosts ||= @sortHosts()

  sortHosts: ->
    (h for _, h of @hosts when h.dc == 'ash').sort (a, b) ->
      if a.dc > b.dc
        -1
      else if a.dc < b.dc
        1
      else if a.type > b.type
        -1
      else if a.type < b.type
        1
      else
        a.index - b.index

  isEmpty: ->
    for name, host of @hosts
      return false if host.containers.length > 0
    true

class Host
  PATTERNS =
    restarting: /\[(\d+)\/(\d+)\] \(([\w\-]+)\) restarting/i
    restarted: /\[(\d+)\/(\d+)\] \(([\w\-]+)\) (successfully restarted|was not required to restart in time)/i
    timeout: /\[(\d+)\/(\d+)\] \(([\w\-]+)\) (did not restart in time|failed to restart|unable to restart)/i

  constructor: (name) ->
    @fullname = name
    [@name, @dc] = name.split('.')
    [_, @type, index] = @name.match(/^([a-z]+)(\d+)$/)
    @index = index | 0
    @containers = []

  parseLog: (output) ->
    for status, pattern of PATTERNS
      if match = output.match(pattern)
        @update
          total: match[2] | 0
          container:
            index: (match[1] | 0) - 1
            name: match[3]
            status: status

  update: (attributes) ->
    @initializeContainers(attributes.total)
    container = attributes.container
    @containers[container.index].update(container)

  initializeContainers: (total) ->
    return if @containers.length
    for i in [1..total]
      @containers.push(new Container)

class Container
  constructor: ->
    @status = 'running'

  update: ({status, name, index}) ->
    @status = status
    @name = name
    @index = index


dataCenterWidget = null
render = ->
  return if dataCenter.isEmpty()
  dataCenterWidget ||= React.render(
    React.createElement(DataCenterStatus, null),
    Sidebar.newWidgetContainer()[0]
  )
  dataCenterWidget.setState(hosts: dataCenter.sorted())

dataCenter = new DataCenter
OutputStream.addEventListener 'chunk', (chunk) ->
  for line in chunk.lines()
    dataCenter.parseLog(line)
  render()
