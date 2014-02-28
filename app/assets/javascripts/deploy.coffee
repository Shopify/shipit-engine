$ ->
  chunkUrl = $("code").data('next-chunks-url')
  if chunkUrl
    func = ->
      jQuery.get chunkUrl, (data) ->
        $("#status").html(data.deploy.status)
        chunkUrl = data.url
        if data.chunks.length > 0
          data.chunks.map (chunk) ->
            $("code").append(chunk.text)
        if data.deploy.status != 'pending' && data.deploy.status != 'running'
          clearTimeout(tid)
    tid = setInterval func, 500
