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

  displayConfigureCiMessage = ->
    commits = $('.commit')
    ciConfigured = !commits.length || commits.length != commits.find('div.unknown').length
    $('.configure-ci').toggleClass('hidden', ciConfigured)
    return

  displayConfigureCiMessage()

  loadFragment = (message, callback, retryCount=0) ->
    json = JSON.parse(message.data)
    success = (response) -> callback(json.id, response)
    jQuery.ajax(json.url, accepts: 'text/partial+html').success(success).error(-> retry(message, callback, retryCount))

  updateStackStatus = (message) ->
    json = JSON.parse(message.data)
    $('[data-stack-status]').attr('data-stack-status', json.stack_status)

  removeCommit = (id) ->
    $("#commit-#{id}").remove()

  onCommitUpdate = (message) ->
    loadFragment message, (id, commit) ->
      $("#commit-#{id}").replaceWith($timeago(commit))
    displayConfigureCiMessage()

  onCommitCreate = (message) ->
    loadFragment message, (id, commit) ->
      if (previousCommitId = findPreviousCommitId(id)) > 0
        $("#commit-#{previousCommitId}").before($timeago(commit))
      else
        $("ul.commit-lst").append($timeago(commit))
    displayConfigureCiMessage()

  findPreviousCommitId = (id) ->
    $commits = $(".commit-lst li.commit")
    ids = $commits.map (_, node) ->
      nodeId = parseInt(node.id.match /\d+/)
      nodeId if nodeId < id

    if ids.length > 0 then Math.max(ids...) else 0

  onCommitRemove = (message) ->
    json = JSON.parse(message.data)
    removeCommit id
    displayConfigureCiMessage()

  onDeploySuccess = (message) ->
    updateStackStatus(message)

    json = JSON.parse(message.data)
    for id in json.commit_ids
      removeCommit id

  onDeployUpdate = (message) ->
    updateStackStatus(message)

    loadFragment message, (id, deploy) ->
      $("#deploy-#{id}").replaceWith($timeago(deploy))

  onDeployCreate = (message) ->
    updateStackStatus(message)

    loadFragment message, (id, deploy) ->
      $("ul.deploy-lst").prepend($timeago(deploy))

  onStackUpdate = (message) ->
    json = JSON.parse(message.data)
    $('[data-stack-locked]').data('stack-locked', json.locked)
    $('.lock-reason p').text(json.lock_reason)
    $('.lock-reason').toggle(json.locked)

  listenToEventSource = (url) ->
    source = new EventSource(url)
    reconnect = -> listenToEventSource(url)
    #source.onerror = -> setTimeout(reconnect, 3000)
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
