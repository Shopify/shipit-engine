//= require string_includes
//= require mousetrap
//= require mousetrap-global-bind
//= require lodash
//= require clusterize
//= require_tree ./task
//= require_self

this.OutputStream = new Stream;

jQuery(function() {
  var $code, initialOutput, search, task, tty;
  $code = $('code');
  initialOutput = $code.attr('data-output');
  $code.removeAttr('data-output');
  search = new SearchBar($('.search-bar'));
  OutputStream.addEventListener('status', function(status, response) {
    $('[data-status]').attr('data-status', status);
    if (status === 'aborted' && response.rollback_url) {
      window.location = response.rollback_url;
    }
  });
  tty = new TTY($('body'));
  search.addEventListener('query', tty.filterOutput);
  search.immediateBroadcastQueryChange();
  OutputStream.addEventListener('chunk', tty.appendChunk);
  if (task = $('[data-task]').data('task')) {
    Notifications.init(OutputStream, task);
  }
  OutputStream.init({
    status: $code.closest('[data-status]').data('status'),
    url: $code.data('next-chunks-url'),
    text: initialOutput
  });
});
