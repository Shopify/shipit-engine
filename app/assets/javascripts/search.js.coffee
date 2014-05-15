unless String::contains
  String::contains = (args...) ->
    @indexOf(args...) != -1

$(document).on 'keyup', '.stack-search', (event) ->
  query = $.trim($(event.target).val()).toLowerCase()

  $items = $('[data-search]')

  if query
    for item in $items
      $item = $(item)
      $item.toggleClass('not-matching', !$item.attr('data-search').toLowerCase().contains(query))
  else
    $items.removeClass('not-matching')

jQuery ->
  $('.stack-search').focus()
