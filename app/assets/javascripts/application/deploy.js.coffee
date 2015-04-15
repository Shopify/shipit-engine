$(document).on 'click', '.deploy-abort .deploy-action', (event) ->
  event.preventDefault()
  $target = $(event.currentTarget)
  return if $target.hasClass('pending')
  $target.addClass('pending')
  enable = -> $target.removeClass('pending')
  $.post($target.attr('href')).done(-> setTimeout(enable, 3000))
