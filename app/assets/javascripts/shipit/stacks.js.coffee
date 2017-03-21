$(document).on 'click', '.commit-lock a', (event) ->
  event.preventDefault()
  $commit = $(event.target).closest('.commit')
  $link = $(event.target).closest('a')

  locked = $commit.hasClass('locked')
  new_toolip = ''

  if locked
    confirmation = confirm("Mark this commit as safe to deploy?");
    unless confirmation
      return
    new_toolip = 'This commit is safe to deploy. Click to mark it as unsafe'
  else
    new_toolip = 'This commit is unsafe to deploy. Click to mark it as safe'

  $link.attr('data-tooltip', new_toolip) # Change DOM
  $link.data('tooltip', new_toolip) # Break data cache
  $commit.toggleClass('locked')
  $.ajax($link.attr('href'), method: 'PATCH', data: {commit: {locked: !locked}})

jQuery ($) ->
  displayIgnoreCiMessage = ->
    ignoreCiMessage = $(".ignoring-ci")
    return unless ignoreCiMessage
    $('.dismiss-ignore-ci-warning').click (event) ->
      event.preventDefault()
      dismissIgnoreCiMessage()

    if localStorage.getItem(getLocalStorageKey())
      ignoreCiMessage.hide()

  dismissIgnoreCiMessage = ->
    localStorage.setItem(getLocalStorageKey(), true)
    ignoreCiMessage = $(".ignoring-ci")
    ignoreCiMessage.hide() if ignoreCiMessage

  getLocalStorageKey = ->
    stackName = $('.repo-name').data('repo-full-name')
    "ignoreCIDismissed" + stackName

  displayIgnoreCiMessage()

  $(document).on 'click', '.setting-ccmenu input[type=submit]', (event) ->
    event.preventDefault()
    $(event.target).prop('disabled', true)
    $.get(event.target.dataset.remote).done((data) ->
      $('#ccmenu-url').val(data.ccmenu_url).removeClass('hidden')
      $(event.target).addClass('hidden')
    ).fail(->
      $(event.target).prop('disabled', false)
    )
