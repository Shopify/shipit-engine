$document = $(document)

toggleDeployButton = ->
  $('.trigger-deploy').toggleClass('disabled', !!$(':checkbox[name=checklist]:not(:checked)').length)

if $('html[data-controller=deploys][data-action=new]').length
  $document.on('change', ':checkbox[name=checklist]', toggleDeployButton)

jQuery ($) ->
  toggleDeployButton()
