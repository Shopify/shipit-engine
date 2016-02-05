$document = $(document)

toggleDeployButton = ->
  $('.trigger-deploy').toggleClass('disabled btn--disabled', !!$(':checkbox.required:not(:checked)').length)

$document.on('change', ':checkbox.required', toggleDeployButton)

jQuery ($) ->
  toggleDeployButton()
