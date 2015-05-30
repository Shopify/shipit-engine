#= require_tree ./task
#= require_self

class StickyElement
  constructor: (@$element) ->
    @staticElementTop = @$element.position().top
    @refresh()

  refresh: =>
    @toggleStickyClass()
    window.requestAnimationFrame(@refresh)

  toggleStickyClass: ->
    @$element.toggleClass('sticky', window.scrollY >= @staticElementTop)

class

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

  new StickyElement($('.deploy-banner'))
  new StickyElement($('.sidebar'))
