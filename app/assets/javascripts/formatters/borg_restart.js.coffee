class @DeployTasksView
  constructor: ->
    @tasks = {}

  appendTo: (@$container) ->

  getTask: (type, id) ->
    if @tasks[id] != undefined
      return @tasks[id]
    @tasks[id] = new type(@$container)

  logSearch: (text, re, callback) ->
    re.lastIndex = 0
    while (res = re.exec(text)) != null
      callback(res)
    null

  update: (text) ->
    @logSearch text, /^.+(sb\d+).chi.shopify.com\] I.+\[(\d+)\/(\d+)\] Restarting/gm, (match) => 
      task = @getTask(LightsTaskView, "restart-"+match[1])
      task.title = match[1]
      task.numPartial = match[2]
      task.numLights = match[3]
      task.update()
    @logSearch text, /^.+(sb\d+).chi.shopify.com\] I.+\[(\d+)\/(\d+)\] Successfully Restarted/gm, (match) => 
      task = @getTask(LightsTaskView, "restart-"+match[1])
      task.numGood = match[2]
      task.numLights = match[3]
      task.update()
    @logSearch text, /^.+(sb\d+).chi.shopify.com\] I.+\[(\d+)\/(\d+)\] Unable to restart/gm, (match) => 
      task = @getTask(LightsTaskView, "restart-"+match[1])
      task.fail()
    null


class LightsTaskView
  title: ""
  numLights: 0
  numPartial: 0
  numGood: 0

  constructor: (@$container) ->
    @elem = $("<div class='task-lights'><span class='task-lights-text'><span class='task-lights-node'></span></span><span class='task-lights-boxes'></span></div>")
    @elem.appendTo(@$container)

  update: ->
    @elem.find('.task-lights-node').html(@title)
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
