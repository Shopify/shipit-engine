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
#= require jquery-notify
#= require ansi_stream
#= require_tree ./application
#= require_self

stream = new AnsiStream()

ChunkPoller.registerFormatter (chunk) ->
  stream.process(chunk)

jQuery ->
  Sidebar.init($(window), $('.sidebar-plugins'))
  ChunkPoller.init()

$(document).on 'click', 'a.disabled', (event) ->
  event.preventDefault()

jQuery ->
  $notificationNotice = $('.notifications')

  if $.notifyCheck() == $.NOTIFY_NOT_ALLOWED
    $button = $notificationNotice.find('button')
    $button.on 'click', ->
      $.notifyRequest()
      $notificationNotice.addClass('hidden')
    $notificationNotice.removeClass('hidden')
    
