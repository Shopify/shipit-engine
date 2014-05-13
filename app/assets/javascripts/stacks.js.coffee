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


jQuery ->

  $search_box = $('.stack-search input')
  $search_fields = $('[data-search]')
  $search_hints = $('.search-hint')

  search = (search_term) =>
    $search_hints.hide()

    if search_term == ''
      $search_fields.parents('.search-item').show()
      return

    $search_fields.parents('.search-item').hide()

    results = $('[data-search]').filter (index, element) =>
      value = $(element).text().toLowerCase()
      return value.indexOf(search_term.toLowerCase()) > -1

    results.parents('.search-hint').show()
    results.parents('.search-item').show()

  $search_box.keyup =>
    search($search_box.val())

  $search_box.focus()
