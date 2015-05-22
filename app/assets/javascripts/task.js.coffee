#= require_tree ./task
#= require_self

jQuery ->
  OutputStream.addEventListener 'status', (task) ->
    $('[data-task-status]').attr('data-task-status', task.status)

  tty = new TTY($('body'))
  OutputStream.addEventListener('chunk', tty.appendChunk)
  Notifications.init(OutputStream)

  $code = $('code')
  OutputStream.init
    status: $code.data('task-status')
    url: $code.data('next-chunks-url')
    text: tty.popInitialOutput()
