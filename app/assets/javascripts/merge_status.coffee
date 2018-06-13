class MergeStatusPoller
  POLL_INTERVAL = 3000

  constructor: ->
    @request = {abort: ->}
    @previousLastModified = null
    @timeoutId = null

  start: ->
    @timeoutId = setTimeout(@refreshPage, POLL_INTERVAL)
    @

  stop: ->
    @request.abort()
    clearTimeout(@timeoutId)
    @

  onPageChange: =>
    window.parent.postMessage({event: 'hctw:height:change', height: document.body.clientHeight, service: 'shipit'}, '*')
    window.parent.postMessage({event: 'hctw:stack:info', queue_enabled: @isMergeQueueEnabled(), status: @mergeStatus(), service: 'shipit'}, '*')

  fetchPage: (url, callback) ->
    request = @request = new XMLHttpRequest()
    request.onreadystatechange = ->
      if request.readyState == XMLHttpRequest.DONE
        callback(request.status == 200 && request.responseText, request)
    request.open('GET', url, true)
    request.setRequestHeader('X-Requested-With', 'XMLHttpRequest')
    request.send()

  previousLastModified = null
  refreshPage: =>
    @fetchPage window.location.toString(), (html, response) =>
      @updateDocument(html, response)
      setTimeout(@refreshPage, POLL_INTERVAL)

  updateDocument: (html, response) =>
    lastModified = response.getResponseHeader('last-modified')
    if !lastModified || lastModified != @previousLastModified
      @previousLastModified = lastModified
      if html && container = document.querySelector('[data-layout-content]')
        container.innerHTML = html
        @onPageChange()

  isMergeQueueEnabled: =>
    document.querySelector('.merge-status-container .js-details-container')?.hasAttribute('data-queue-enabled')

  mergeStatus: =>
    document.querySelector('.merge-status-container .js-details-container')?.getAttribute('data-merge-status') || 'unknown'

class AjaxAction
  constructor: (@poller) ->
    document.addEventListener('submit', @submit, false)

  submit: (event) =>
    return unless event.target.getAttribute('data-remote') == 'true'

    event.preventDefault()

    @poller.stop()
    @disableButtons(event.target)
    @submitFormAsynchronously event.target, (html, request) =>
      @poller.updateDocument(html, request)
      @poller.start()

  submitFormAsynchronously: (form, callback) ->
    request = new XMLHttpRequest()
    request.onreadystatechange = ->
      if request.readyState == XMLHttpRequest.DONE
        callback(request.status == 200 && request.responseText, request)
    request.open(form.method.toLocaleUpperCase(), form.action, true)
    request.setRequestHeader('X-Requested-With', 'XMLHttpRequest')
    request.send(new FormData(form))

  disableButtons: (form) ->
    for button in form.querySelectorAll('[data-disable-with]')
      button.disabled = true
      button.textContent = button.getAttribute('data-disable-with')

poller = new MergeStatusPoller
poller.onPageChange()
poller.start()
new AjaxAction(poller)
