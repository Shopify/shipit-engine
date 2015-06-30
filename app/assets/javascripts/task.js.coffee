#= require_tree ./task
#= require_self

jQuery ->
  OutputStream = new Stream
  OutputStream.addEventListener 'status', (status) ->
    $('[data-status]').attr('data-status', status)

  tty = new TTY($('body'))
  OutputStream.addEventListener('chunk', tty.appendChunk)
  Notifications.init(OutputStream)

  $code = $('code')
  OutputStream.init
    status: $code.closest('[data-status]').data('status')
    url: $code.data('next-chunks-url')
    text: tty.popInitialOutput()

  StickyElement.init('.deploy-banner')
  StickyElement.init('.sidebar')
