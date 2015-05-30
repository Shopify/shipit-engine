#= require_tree ./task
#= require_self

class StickyBanner
  constructor: (@$banner) ->
    @staticBannerTop = @$banner.position().top
    @refresh()

  refresh: =>
    @toggleBannerClass()
    window.requestAnimationFrame(@refresh)

  toggleBannerClass: ->
    @$banner.toggleClass('sticky', window.scrollY >= @staticBannerTop)

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

  new StickyBanner($('.deploy-banner'))
