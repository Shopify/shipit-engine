class OutputLines
  constructor: (@screen, @render) ->
    @renderingCache = {}

  append: (lines) ->
    @screen.append(@renderLines(@filter(lines)))

  setFilter: ->
    true

  filter: (lines) ->
    lines

  highlight: (line) ->
    line

  renderLines: (lines) ->
    for line in lines
      @highlight(@renderingCache[line] ||= @render(line))

class @ClusterizeOutputLines extends OutputLines
  constructor: (@screen, @render) ->
    super
    @raw = []
    @query = ''
    @highlightRegexp = null
    @stripCache = {}

  append: (lines) ->
    @raw = @raw.concat(lines)
    super

  setFilter: (query) ->
    if @query = query
      @screen.options.no_data_text = 'No matches'
    else
      @screen.options.no_data_text = 'Loading...'
    @highlightRegexp = @buildHighlightRegexp(@query)
    @reset()

  reset: ->
    @screen.update(@renderLines(@filter(@raw)))

  strip: (line) ->
    @stripCache[line] ||= AnsiStream.strip(line)

  filter: (lines) ->
    return lines unless @query
    line for line in lines when @strip(line).includes(@query)

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
    @$container = @$code.closest('.task-output-container')
    if @$container.hasClass('clusterize-scroll')
      scroller = new Clusterize(
        no_data_text: 'Loading...'
        tag: 'div'
        contentElem: @$code[0]
        scrollElem: @$container[0]
      )
      @output = new ClusterizeOutputLines(scroller, (line) => @createLine(@formatChunks(line)))
    else
      @output = new OutputLines(@$code, (line) => @createLine(@formatChunks(line)))

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

