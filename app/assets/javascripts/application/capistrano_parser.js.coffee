class @CapistranoParser
  PATTERN = /^\*+ +\[(\w+) :: ([a-zA-Z\d\.]+)\] (.*)$/gm
  constructor: (@text) ->

  stream: (callback) ->
    PATTERN.lastIndex = 0
    while (match = PATTERN.exec(@text)) != null
      callback
        source: match[1]
        host: match[2]
        output: match[3] || ''
    null
