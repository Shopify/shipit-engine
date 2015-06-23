jQuery ($) ->
  $popoverContainers = $(".popover-container")

  $popoverContainers.click ->
    $popover = $(this).find(".popover")
    $popover.toggleClass("popover--visible")
