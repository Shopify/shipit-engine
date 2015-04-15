class @CapistranoParser
  LOG_PATTERN = /^\s*\[([a-zA-Z\d\.]+)\]\[(\w+)\] (.*)$/gm
  TASK_START_PATTERN = /^\s*\*(?: \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})? executing `([^']+)'\s*$|^.*\*+ Execute (\S+)/gm
  TASK_END_PATTERN = /^\s*triggering after callbacks for `([^']+)'\s*$|^\s*\* Finished (\S+) in /gm
  lastIndex: 0

  constructor: (@text) ->


  matchPattern: (pattern, callback) ->
    pattern.lastIndex = @lastIndex
    while (match = pattern.exec(@text)) != null
      res = callback(match)
      break if res == false
    @lastIndex = pattern.lastIndex
    null

  eachMessage: (callback) ->
    @matchPattern LOG_PATTERN, (match) ->
      callback
        source: match[2]
        host: match[1]
        output: match[3] || ''

filterAshburn = (text) ->
  String(text).replace(/^.*\[ash\].*$/gm, '').replace(/^.*\.ash\.shopify\.com.*$/gm, '').replace(/\[chi\]/mg,'')

# Abstract, need to implement @refresh and @parse
class BaseTaskWidget
  constructor: ->
    @active = false

  addHeading: ->
    @$headingEl = $("<h2 class='task-group-heading'></h2>")
    @$headingEl.appendTo(@$container)

  newContainer: ->
    if @$container
      @$container.empty()
    else
      @$container = Sidebar.newWidgetContainer()
    @addHeading()
    @$container.append("<div class='section-bottom'></div>")

  activate: ->
    return if @active
    @newContainer()
    @$headingEl.text(@heading)
    @active = true

  finish: ->
    return unless @active
    @$headingEl.text(@heading + " \u2713") # add check mark
    @active = false
    @tasks = {}

  update: (text) ->
    parser = new CapistranoParser(filterAshburn(text))
    @parse(parser)
    @refresh()
    null

# Abstract, need to implement @parse
class ProgressBarTaskWidget extends BaseTaskWidget
  constructor: ->
    super
    @total = 1
    @done = 0

  newContainer: ->
    super
    @$bar = $("<div>").addClass("task-progress-container")
    @$donePart = $("<div>").addClass("task-progress-bar").appendTo(@$bar)
    @$bar.insertBefore(@$container.find('.section-bottom'))

  refresh: ->
    return unless @active
    frac = @done / @total
    doneWidth = @$bar.width() * frac
    @$donePart.width(doneWidth)

class AssetsUploadWidget extends ProgressBarTaskWidget
  constructor: ->
    super
    @heading = "Uploading Assets"

  update: (text) ->
    parser = new CapistranoParser(filterAshburn(text))
    @parse(parser)
    null

  parse: (parser) ->
    parser.eachMessage (log) =>
      if match = log.output.match(/S3 assets uploading \[(\d+)\/(\d+)\]/)
        @activate()
        @done = +(match[1])
        @total = +(match[2])
        @refresh()
    null

class ContainersRestartWidget extends BaseTaskWidget
  constructor: ->
    super
    @heading = "Restarting Servers"
    @containers = []
    @tasks = {}

  createTask: (host) ->
    task = new LightsTaskView(@$container, host)
    @push(task)
    task

  getTask: (host) ->
    @activate()
    @tasks[host] ||= @createTask(host)

  push: (container) ->
    @containers.push(container)

  refresh: ->
    @sort()
    @getList().empty()
    @getList().html(c.updateDOM().$element[0] for c in @containers)
    this

  getList: ->
    unless @$list?.length
      @$list = $('<div>').addClass('container-tasks').appendTo(@$container)
    @$list

  sort: ->
    @containers.sort (a, b) ->
      if a.type > b.type
        -1
      else if a.type < b.type
        1
      else
        a.index - b.index

  updateTask: (host, attrs) ->
    task = @getTask(host).update(attrs)
    task

  parse: (parser) ->
    parser.eachMessage (log) =>
      if match = log.output.match(/\[(\d+)\/(\d+)\].* restarting/i)
        @updateTask log.host,
          numPending: match[1]
          numLights: match[2]
      else if match = log.output.match(/\[(\d+)\/(\d+)\].* (successfully restarted|was not required to restart in time)/i)
        @updateTask log.host,
          numDone: match[1]
          numLights: match[2]
      else if match = log.output.match(/\[(\d+)\/(\d+)\].* did not restart in time/i)
        @updateTask(
          log.host,
          numPending: match[1],
          numLights: match[2]
        ).fail()
      else if match = log.output.match(/\[(\d+)\/(\d+)\].* (failed to restart|unable to restart)/i)
        @updateTask(
          log.host,
          numPending: match[1],
          numLights: match[2]
        ).fail()
    null

class LightsTaskView
  TEMPLATE = $.trim """
    <div class="task-lights">
      <span class="task-lights-text">
        <span class="task-lights-title"></span>
      </span>
      <span class="task-lights-boxes"></span>
    </div>
  """
  numLights: 0
  numPending: 0
  numDone: 0

  constructor: (@$container, host) ->
    @$element = $(TEMPLATE)
    @$title = host.split('.')[0]
    @parseTitle(@$title)
    @$element.find('.task-lights-title').text(@$title)

  parseTitle: (title) ->
    [_, @type, index] = title.match(/^([a-z]+)(\d+)$/)
    @index = parseInt(index, 10)

  genBoxes: ->
    boxes = document.createDocumentFragment();
    for i in [1..(+@numLights)]
      status = if i <= @numDone
        'up'
      else if i <= @numPending
        'partial'
      else
        'neutral'
      $('<span>').addClass("task-lights-box box-#{status}").appendTo(boxes)
    boxes

  update: (attrs) ->
    $.extend(this, attrs)
    this

  updateDOM: ->
    @$element.find('.task-lights-boxes').html(@genBoxes())
    @$element.toggleClass('wide', @numLights > 10)
    this

  fail: ->
    @$element.addClass('task-failed')

BORG_WIDGETS = [AssetsUploadWidget, ContainersRestartWidget]
borgWidgetInstances = for widget in BORG_WIDGETS
  new widget()

TTY.prependFormatter (chunk) ->
  for widget in borgWidgetInstances
    widget.update(AnsiStream.strip(chunk))
  false
