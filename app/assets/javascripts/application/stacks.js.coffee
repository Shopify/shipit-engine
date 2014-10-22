class CommitList
  @insert: (commit) ->
    commit.getContent (content) =>
      if previousCommitId = @findPreviousCommitId(commit.id))
        $("#commit-#{previousCommitId}").before(content)
      else
        $("ul.commit-lst").append(content)

  @findPreviousCommitId: (id) ->
    $commits = $(".commit-lst li.commit")
    ids = $commits.map (_, node) ->
      nodeId = parseInt(node.id.match /\d+/)
      nodeId if nodeId < id
    Math.max(ids...)


class Commit
  MAX_RETRY = 4

  @fromJSON: (message) ->
    json = JSON.parse(message)
    new this(json)

  constructor: ({@id, @url}) ->
    @$element = $("#commit-#{@id}")

    #@previous = new Commit(findPreviousCommitId(id))

  update: () ->
    @getContent (content) =>
      @$element.replaceWith(content)

  remove: ->
    @$element.remove()

  getContent: (callback) ->
    @loadFragment (rawContent) => callback(@$timeago(rawContent))

  $timeago: (html) ->
    $element = $(html)
    $element.find('time[data-time-ago]').timeago()
    $element

  loadFragment: (callback, retryCount=0) ->
    jQuery.ajax(@url, accepts: 'text/partial+html').success(callback).error =>
      @retry(callback, retryCount)

  retry: (callback, retryCount=0) ->
    retryCount += 1
    return if retryCount >= MAX_RETRY
    setTimeout((=> @loadFragment(callback, retryCount)), 1000 * retryCount)


jQuery ($) ->


  displayConfigureCiMessage = ->
    commits = $('.commit')
    ciConfigured = !commits.length || commits.length != commits.find('div.unknown').length
    $('.configure-ci').toggleClass('hidden', ciConfigured)
    return

  displayConfigureCiMessage()



  updateStackStatus = (message) ->
    json = JSON.parse(message.data)
    $('[data-stack-status]').attr('data-stack-status', json.stack_status)

  removeCommit = (id) ->
    $("#commit-#{id}").remove()

  onCommitUpdate = (message) ->
    Commit.fromJSON(message.data).update()
    displayConfigureCiMessage()

  onCommitCreate = (message) ->
    CommitList.insert(Commit.fromJSON(message.data))

    displayConfigureCiMessage()



  onCommitRemove = (message) ->
    Commit.fromJSON(message.data).remove()
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
    $('[data-stack-locked]').attr('data-stack-locked', json.locked)
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
