class @DeployTasksView
  constructor: ->
    @tasks = {}

  appendTo: (@$container) ->

  getTask: (type, id) ->
    @tasks[id] ||= new type(@$container)

  update: (text) ->
    new CapistranoParser(text).stream (log) =>
      if match = log.output.match(/\[(\d+)\/(\d+)\] Restarting/)
        @getTask(LightsTaskView, "restart-#{log.host}").update
          host: log.host
          numPartial: match[1]
          numLights: match[2]
      else if match = log.output.match(/\[(\d+)\/(\d+)\] Successfully Restarted/)
        @getTask(LightsTaskView, "restart-#{log.host}").update
          host: log.host
          numGood: match[1]
          numLights: match[2]
      else if match = log.output.match(/\[(\d+)\/(\d+)\] Unable to restart/)
        @getTask(LightsTaskView, "restart-#{log.host}").update(host: log.host).fail()
    null


class LightsTaskView
  numLights: 0
  numPartial: 0
  numGood: 0

  constructor: (@$container) ->
    @elem = $("<div class='task-lights'><span class='task-lights-text'><span class='task-lights-node'></span></span><span class='task-lights-boxes'></span></div>")
    @elem.appendTo(@$container)

  update: ({@host, @numGood, @numLights, @numPartial}) ->
    @updateTitle(@host)
    boxes = document.createDocumentFragment();
    for i in [1..(+@numLights)]
      status = if i <= @numGood
        "up"
      else if i <= @numPartial
        "partial"
      else
        "neutral"
      box = document.createElement("span")
      box.className = "task-lights-box box-"+status
      boxes.appendChild(box)
    @elem.find('.task-lights-boxes').empty().append(boxes)

  fail: ->
    @elem.addClass("task-failed")

  updateTitle: (host) ->
    title = host.split('.')[0]
    @elem.find('.task-lights-node').text(title)
