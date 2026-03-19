// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file.
//
// Read Sprockets README (https://github.com/sstephenson/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require jquery
//= require jquery_ujs
//= require rails-timeago
//= require jquery-notify
//= require_tree ./shipit
//= require_self

$(document).on('click', '.disabled, .btn--disabled', function(event) {
  event.preventDefault();
});

$(document).on('click', '.banner__dismiss', function(event) {
  $(event.target).closest('.banner').addClass('hidden');
});

$(document).on('click', '.enable-notifications .banner__dismiss', function(event) {
  localStorage.setItem("dismissed-enable-notifications", true);
});

$(document).on('click', '.github-status .banner__dismiss', function(event) {
  localStorage.setItem("dismissed-github-status", true);
});

jQuery(function() {
  var $button, $notificationNotice;
  if (!(localStorage.getItem("dismissed-enable-notifications"))) {
    $notificationNotice = $('.enable-notifications');
    if ($.notifyCheck() === $.NOTIFY_NOT_ALLOWED) {
      $button = $notificationNotice.find('button');
      $button.on('click', function() {
        $.notifyRequest();
        $notificationNotice.addClass('hidden');
      });
      $notificationNotice.removeClass('hidden');
    }
  }
  if (!(localStorage.getItem("dismissed-github-status"))) {
    $('.github-status').removeClass('hidden');
  }
});
