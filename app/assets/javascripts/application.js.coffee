# This is a manifest file that'll be compiled into application.js, which will include all the files
# listed below.
#
# Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
# or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
#
# It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
# compiled file.
#
# Read Sprockets README (https:#github.com/sstephenson/sprockets#sprockets-directives) for details
# about supported directives.
#
#= require jquery
#= require jquery_ujs
#= require rails-timeago
#= require jquery.hc-sticky
#= require jquery-notify
#= require ansi_up
#= require_tree .

jQuery ->
  $('.inner-sidebar').hcSticky();

$(document).on 'click', 'a.disabled', (event) ->
  event.preventDefault()

jQuery ->
  btn = $('button.notifications')
  if $.notifyCheck() == $.NOTIFY_NOT_ALLOWED
    btn.click () =>
      $.notifyRequest()
      btn.hide()
  else
  	btn.hide()
