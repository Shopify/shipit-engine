$ ->
  colorize = (text) -> ansi_up.ansi_to_html(text)

  chunkUrl = $("code").data('next-chunks-url')
  if chunkUrl
    func = ->
      jQuery.get chunkUrl, (data) ->
        $("#status").html(data.deploy.status)
        chunkUrl = data.url
        if data.chunks.length > 0
          chunk_text = data.chunks.map (chunk) -> chunk.text
          $("code").append(colorize(chunk_text.join('')))
        if data.deploy.status != 'pending' && data.deploy.status != 'running'
          clearTimeout(tid)
    tid = setInterval func, 500

  $("code").each ->
    $(this).html(colorize(this.innerHTML))
