class ChunkPoller
  INTERVAL = 1000
  constructor: ($body, @pollUrl) ->
    @$status = $body.find('[data-deploy-status]')
    @$code = $body.find('code')
    @$body = $body
    @$window = $(window)

  poll: =>
    jQuery.get(@pollUrl, @update)

  update: (response) =>
    @pollUrl = response.url
    @restoreBrowserScroll =>
      @appendChunks(response.chunks)
    @updateDeployStatus(response.deploy)
    unless @deployIsFinished(response.deploy)
      @start()

  restoreBrowserScroll: (callback) ->
    wasScrolledToBottom = @isScrolledToBottom()
    callback()
    if wasScrolledToBottom
      @$window.scrollTop(@$body.height())

  isScrolledToBottom: ->
    @$body.height() - @$window.height() == window.scrollY

  start: ->
    setTimeout(@poll, INTERVAL)

  updateDeployStatus: (deploy) ->
    @$status.attr('data-deploy-status', deploy.status)

  deployIsFinished: (deploy) ->
    @$status.attr('data-deploy-status') not in ['pending', 'running']

  appendChunks: (chunks) ->
    return unless chunks.length

    text = chunks.map((c) -> c.text).join('')
    @$code.append(@colorize(text))

  colorize: (text) ->
    ansi_up.ansi_to_html(text)

jQuery ->
  poller = new ChunkPoller($('body'), $('code').data('next-chunks-url'))
  poller.start()

  $('code').each ->
    $(this).html(ChunkPoller::colorize(this.innerHTML))
