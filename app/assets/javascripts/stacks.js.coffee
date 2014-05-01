jQuery ->
  loadFragment = (message, callback) ->
    json = JSON.parse(message.data)
    success = (response) -> callback(json.id, response.responseText)
    jQuery.get(json.url, success, 'text/partial+html')

  removeCommit = (id) ->
    $("#commit-#{id}").remove()

  onCommitUpdate = (message) ->
    loadFragment message, (id, commit) ->
      $("#commit-#{id}").html(commit)

  onCommitCreate = (message) ->
    loadFragment message, (id, commit) ->
      $("ul.commit-lst").prepend(commit)

  onCommitRemove = (message) ->
    json = JSON.parse(message.data)
    removeCommit id

  onDeploySuccess = (message) ->
    json = JSON.parse(message.data)
    for id in json.commit_ids
      removeCommit id

  onDeployUpdate = (message) ->
    loadFragment message, (id, deploy) ->
      $("#deploy-#{id}").html(deploy)

  onDeployCreate = (message) ->
    loadFragment message, (id, deploy) ->
      $("ul.deploy-lst").prepend(deploy)

  $('[data-event-stream]').each ->
    url = $(this).data('event-stream')
    source = new EventSource(url)
    source.addEventListener 'commit.update', onCommitUpdate
    source.addEventListener 'commit.create', onCommitCreate
    source.addEventListener 'commit.remove', onCommitRemove

    source.addEventListener 'deploy.success', onDeploySuccess
    source.addEventListener 'deploy.success', onDeployUpdate

    source.addEventListener 'deploy.failed', onDeployUpdate
    source.addEventListener 'deploy.error', onDeployUpdate
    source.addEventListener 'deploy.running', onDeployUpdate
    source.addEventListener 'deploy.pending', onDeployCreate

