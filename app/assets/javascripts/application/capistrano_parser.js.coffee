class @CapistranoParser
  LOG_PATTERN = /^\s*\[([a-zA-Z\d\.]+)\]\[(\w+)\] (.*)$/gm
  TASK_START_PATTERN = /^\s*\*(?: \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})? executing `([^']+)'\s*$|^.*\*+ Execute (\S+)/gm
  TASK_END_PATTERN = /^\s*triggering after callbacks for `([^']+)'\s*$|^\s*\* Finished (\S+) in /gm
  lastIndex: 0

  constructor: (@text) ->


  matchPattern: (pattern, callback) ->
    pattern.lastIndex = @lastIndex
    while (match = pattern.exec(@text)) != null
      res = callback(match)
      break if res == false
    @lastIndex = pattern.lastIndex
    null

  eachMessage: (callback) ->
    @matchPattern LOG_PATTERN, (match) ->
      callback
        source: match[2]
        host: match[1]
        output: match[3] || ''
