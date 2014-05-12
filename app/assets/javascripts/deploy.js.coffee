class ChunkPoller
  INTERVAL = 1000
  MAX_RETRIES = 15
  STICKY_SCROLL_TOLERENCE = 200

  @init: ->
    $('code').each ->
      $(this).html(ChunkPoller::colorize(this.innerHTML))

    pollUrl = $('code').data('next-chunks-url')
    return unless pollUrl
    poller = new ChunkPoller($('body'), pollUrl)
    poller.start()

  constructor: ($body, @pollUrl) ->
    @$status = $body.find('[data-deploy-status]')
    @$code = $body.find('code')
    @$body = $body
    @$window = $(window)

  poll: =>
    jQuery.ajax @pollUrl,
      success: @update
      error: @error

  error: (response) =>
    (@retries ||= 0)
    @start() if 600 > response.status > 500 && (@retries += 1) < MAX_RETRIES

  update: (response) =>
    @retries = 0
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
      @$window.scrollTop(@codeBottomPosition() - @$window.height() + 50)

  isScrolledToBottom: ->
    @viewportBottomPosition() >= @codeBottomPosition() - STICKY_SCROLL_TOLERENCE and \
    @viewportBottomPosition() < @codeBottomPosition() + STICKY_SCROLL_TOLERENCE

  viewportBottomPosition: ->
    window.scrollY + @$window.height()

  codeBottomPosition: ->
    @$code.position().top + @$code.height()

  start: ->
    setTimeout(@poll, INTERVAL)

  updateDeployStatus: (deploy) ->
    @$status.attr('data-deploy-status', deploy.status)

  deployIsFinished: (deploy) ->
    @$status.attr('data-deploy-status') not in ['pending', 'running']

  appendChunks: (chunks) ->
    return unless chunks.length

    text = chunks.map((c) -> c.text).join('')
    @$code.append(@colorize(@escapeHTML(text)))

  colorize: (text) ->
    ansi_up.ansi_to_html(text)


  ENTITIES = {
    '&': '&amp;'
    '<': '&lt;'
    '>': '&gt;'
    '"': '&quot;'
    "'": '&#x27;'
  }
  ESCAPE_PATTERN = new RegExp("[#{Object.keys(ENTITIES).join('')}]", 'g')

  escapeHTML: (html) ->
    html.replace ESCAPE_PATTERN, (char) ->
      ENTITIES[char]

jQuery ->
  ChunkPoller.init()
