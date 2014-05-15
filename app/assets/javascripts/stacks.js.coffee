jQuery ($) ->
  MAX_RETRY = 4

  $timeago = (html) ->
    $element = $(html)
    $element.find('time[data-time-ago]').timeago()
    $element

  retry = (message, callback, retryCount=0) ->
    retryCount += 1
    return if retryCount >= MAX_RETRY
    setTimeout((-> loadFragment(message, callback, retryCount)), 1000 * retryCount)

  loadFragment = (message, callback, retryCount=0) ->
    json = JSON.parse(message.data)
    success = (response) -> callback(json.id, response)
    jQuery.ajax(json.url, accepts: 'text/partial+html').success(success).error(-> retry(message, callback, retryCount))

  removeCommit = (id) ->
    $("#commit-#{id}").remove()

  onCommitUpdate = (message) ->
    loadFragment message, (id, commit) ->
      $("#commit-#{id}").replaceWith($timeago(commit))

  onCommitCreate = (message) ->
    loadFragment message, (id, commit) ->
      $("ul.commit-lst").prepend($timeago(commit))

  onCommitRemove = (message) ->
    json = JSON.parse(message.data)
    removeCommit id

  onDeploySuccess = (message) ->
    json = JSON.parse(message.data)
    for id in json.commit_ids
      removeCommit id

  onDeployUpdate = (message) ->
    loadFragment message, (id, deploy) ->
      $("#deploy-#{id}").replaceWith($timeago(deploy))

  onDeployCreate = (message) ->
    loadFragment message, (id, deploy) ->
      $("ul.deploy-lst").prepend($timeago(deploy))

  DEPLOY_BUTTON = { value: "Deploy", className: "btn" }
  LOCKED_BUTTON = { value: "Locked", className: "btn disabled failure deploy-action"}

  updateDeployButtons = (locked) ->
    $(".commit input[type='submit']").each ->
      {@value, @className} = if locked then LOCKED_BUTTON else DEPLOY_BUTTON

  onStackUpdate = (message) ->
    locked = JSON.parse(message.data).locked
    updateDeployButtons(locked)
    $('[data-stack-locked]').data('stack-locked', locked)

  updateDeployButtons($('[data-stack-locked]').data('stack-locked'))

  listenToEventSource: (url) ->
    source = new EventSource(url)
    reconnect = -> listenToEventSource(url)
    source.onerror = -> setTimeout(reconnect, 3000)
    source.addEventListener 'commit.update', onCommitUpdate
    source.addEventListener 'commit.create', onCommitCreate
    source.addEventListener 'commit.remove', onCommitRemove

    source.addEventListener 'deploy.success', onDeploySuccess
    source.addEventListener 'deploy.success', onDeployUpdate

    source.addEventListener 'deploy.failed', onDeployUpdate
    source.addEventListener 'deploy.error', onDeployUpdate
    source.addEventListener 'deploy.running', onDeployUpdate
    source.addEventListener 'deploy.pending', onDeployCreate

    source.addEventListener 'stack.update', onStackUpdate

  $('[data-event-stream]').each ->
    listenToEventSource($(this).data('event-stream'))
