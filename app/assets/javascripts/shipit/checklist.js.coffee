$document = $(document)

toggleDeployButton = ->
  $('.trigger-deploy').toggleClass('disabled btn--disabled', !!$(':checkbox[name=checklist]:not(:checked)').length)

$document.on('change', ':checkbox[name=checklist]', toggleDeployButton)

jQuery ($) ->
  toggleDeployButton()
