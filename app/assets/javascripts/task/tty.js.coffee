class OutputLines
  constructor: (@screen, @render) ->
    @query = ''
    @highlightRegexp = null
    @raw = []
    @renderingCache = {}
    @stripCache = {}

  setFilter: (query) ->
    if @query = query
      @screen.options.no_data_text = 'No matches'
    else
      @screen.options.no_data_text = 'Loading...'
    @highlightRegexp = @buildHighlightRegexp(@query)
    @reset()

  reset: ->
    @screen.update(@renderLines(@filter(@raw)))

  filter: (lines) ->
    return lines unless @query
    line for line in lines when @strip(line).includes(@query)

  strip: (line) ->
    @stripCache[line] ||= AnsiStream.strip(line)

  append: (lines) ->
    @raw = @raw.concat(lines)
    @screen.append(@renderLines(@filter(lines)))

  renderLines: (lines) ->
    for line in lines
      @highlight(@renderingCache[line] ||= @render(line))

  buildHighlightRegexp: (query) ->
    pattern = query.replace(/[|\\{}()[\]^$+*?.]/g, '\\$&').replace(/(\s+)/g, '(<[^>]+>)*$1(<[^>]+>)*')
    new RegExp("(#{pattern})", 'g')

  highlight: (renderedLine) ->
    return renderedLine unless @query

    renderedLine.replace(@highlightRegexp, '<mark>$1</mark>').replace(/(<mark>[^<>]*)((<[^>]+>)+)([^<>]*<\/mark>)/, '$1</mark>$2<mark>$4');


class @TTY
  FORMATTERS = []
  STICKY_SCROLL_TOLERENCE = 200

  @appendFormatter: (formatter) ->
    FORMATTERS.push(formatter)

  @prependFormatter: (formatter) ->
    FORMATTERS.unshift(formatter)

  constructor: ($body) ->
    @outputLines = []
    @$code = $body.find('code')
    @$container = @$code.closest('.clusterize-scroll')
    scroller = new Clusterize(
      no_data_text: 'Loading...'
      tag: 'div'
      contentElem: @$code[0]
      scrollElem: @$container[0]
    )
    @output = new OutputLines(scroller, (line) => @createLine(@formatChunks(line)))

  filterOutput: (query) =>
    @output.setFilter(query)

  formatChunks: (chunk) ->
    for formatter in FORMATTERS
      chunk = formatter(chunk) || chunk
    chunk

  appendChunk: (chunk) =>
    lines = chunk.rawLines()
    return unless lines.length

    @preserveScroll =>
      @output.append(lines)

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

