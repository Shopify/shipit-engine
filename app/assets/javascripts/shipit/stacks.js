var $document;

$document = $(document);

$document.on('click', '.commit-lock a', function(event) {
  var $commit, $link, locked;
  event.preventDefault();
  $commit = $(event.target).closest('.commit');
  $link = $(event.target).closest('a');
  locked = $commit.hasClass('locked');
  $commit.toggleClass('locked');
  $.ajax($link.attr('href'), {
    method: 'PATCH',
    data: {
      commit: {
        locked: !locked
      }
    }
  });
});

$document.on('click', '.action-set-release-status', function(event) {
  var $deploy, $link, newStatus;
  event.preventDefault();
  $link = $(event.target).closest('a');
  $deploy = $link.closest('.deploy');
  newStatus = $link.data('status');
  if ($deploy.attr('data-release-status') === newStatus) {
    return;
  }
  $.ajax($link.attr('href'), {
    method: 'POST',
    data: {
      status: newStatus
    }
  }).success(function(last_status) {
    $deploy.attr('data-release-status', last_status.state);
  });
});

jQuery(function($) {
  var dismissIgnoreCiMessage, displayIgnoreCiMessage, getLocalStorageKey;
  displayIgnoreCiMessage = function() {
    var ignoreCiMessage;
    ignoreCiMessage = $(".ignoring-ci");
    if (!ignoreCiMessage) {
      return;
    }
    $('.dismiss-ignore-ci-warning').click(function(event) {
      event.preventDefault();
      dismissIgnoreCiMessage();
    });
    if (localStorage.getItem(getLocalStorageKey())) {
      ignoreCiMessage.hide();
    }
  };
  dismissIgnoreCiMessage = function() {
    var ignoreCiMessage;
    localStorage.setItem(getLocalStorageKey(), true);
    ignoreCiMessage = $(".ignoring-ci");
    if (ignoreCiMessage) {
      ignoreCiMessage.hide();
    }
  };
  getLocalStorageKey = function() {
    var stackName;
    stackName = $('.repo-name').data('repo-full-name');
    return "ignoreCIDismissed" + stackName;
  };
  displayIgnoreCiMessage();
  $(document).on('click', '.setting-ccmenu input[type=submit]', function(event) {
    event.preventDefault();
    $(event.target).prop('disabled', true);
    $.get(event.target.dataset.remote).done(function(data) {
      $('#ccmenu-url').val(data.ccmenu_url).removeClass('hidden');
      $(event.target).addClass('hidden');
    }).fail(function() {
      $(event.target).prop('disabled', false);
    });
  });
});
