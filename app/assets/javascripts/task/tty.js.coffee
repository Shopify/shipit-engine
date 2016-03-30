class @TTY
  FORMATTERS = []
  STICKY_SCROLL_TOLERENCE = 200

  @appendFormatter: (formatter) ->
    FORMATTERS.push(formatter)

  @prependFormatter: (formatter) ->
    FORMATTERS.unshift(formatter)

  constructor: ($body) ->
    @$code = $body.find('code')
    @$container = @$code.closest('.clusterize-scroll')
    @scroller = new Clusterize(
      no_data_text: 'Loading...'
      tag: 'div'
      contentElem: @$code[0]
      scrollElem: @$container[0]
    )
    window.scroller = @scroller

  formatChunks: (chunk) ->
    for formatter in FORMATTERS
      chunk = formatter(chunk) || chunk
    chunk

  appendChunk: (chunk) =>
    lines = chunk.rawLines()
    lines.pop() unless lines[-1]
    return unless lines.length

    @preserveScroll =>
      @scroller.append(lines.map(@formatChunks).map(@createLine))

  createLine: (fragment) ->
    div = document.createElement('div')
    div.appendChild(fragment)
    div.className = 'output-line'
    div.outerHTML

  isScrolledToBottom: ->
    (@getMaxScroll() - @$container.scrollTop()) < 1

  scrollToBottom: ->
    @$container.scrollTop(@getMaxScroll())

  getMaxScroll: ->
    @$code.parent().outerHeight(true) - @$container.outerHeight(true)

  preserveScroll: (callback) ->
    wasScrolledToBottom = @isScrolledToBottom()
    callback()
    @scrollToBottom() if wasScrolledToBottom

