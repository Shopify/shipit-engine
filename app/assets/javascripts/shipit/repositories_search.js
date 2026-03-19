var KEY, RepositorySearch, search,
  bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

KEY = {
  UP: 38,
  DOWN: 40,
  ENTER: 13
};

RepositorySearch = (function() {
  function RepositorySearch(root) {
    this.onKeyUp = bind(this.onKeyUp, this);
    this.$root = $(root);
    this.$root.on('keyup', '.repository-search', this.onKeyUp);
    this.$root.on('click', '.show-all-repositories', (function(_this) {
      return function(event) {
        _this.$root.find('.not-matching').removeClass('not-matching');
        event.preventDefault();
      };
    })(this));
  }

  RepositorySearch.prototype.onKeyUp = function(event) {
    this.$items = this.$root.find('[data-search]');
    switch (event.keyCode) {
      case KEY.ENTER:
        event.preventDefault();
        this.goToSelectedRepository();
        break;
      case KEY.UP:
        event.preventDefault();
        this.selectPrevious();
        break;
      case KEY.DOWN:
        event.preventDefault();
        this.selectNext();
        break;
      default:
        this.filterResults($.trim($(event.target).val()).toLowerCase());
    }
  };

  RepositorySearch.prototype.filterResults = function(query) {
    var $item, i, item, len, ref;
    if (query) {
      ref = this.$items;
      for (i = 0, len = ref.length; i < len; i++) {
        item = ref[i];
        $item = $(item);
        $item.toggleClass('not-matching', indexOf.call($item.attr('data-search').toLowerCase(), query) < 0);
      }
      this.selectFirst();
    } else {
      this.$items.removeClass('not-matching');
    }
  };

  RepositorySearch.prototype.selectFirst = function() {
    this.$items.removeClass('selected').first(':not(.not-matching)').addClass('selected');
  };

  RepositorySearch.prototype.selectNext = function() {
    var $next;
    $next = this.$items.filter('.selected').removeClass('selected').nextAll(':not(.not-matching)').first();
    if (!$next.length) {
      $next = this.$items.filter(':not(.not-matching)').first();
    }
    $next.addClass('selected');
  };

  RepositorySearch.prototype.selectPrevious = function() {
    var $previous;
    $previous = this.$items.filter('.selected').removeClass('selected').prevAll(':not(.not-matching)').first();
    if (!$previous.length) {
      $previous = this.$items.filter(':not(.not-matching)').last();
    }
    $previous.addClass('selected');
  };

  RepositorySearch.prototype.goToSelectedRepository = function() {
    var repository;
    if (repository = this.$items.filter('.selected').filter(':not(.not-matching)').find('.commits-path').attr('href')) {
      window.location = repository;
    }
  };

  return RepositorySearch;

})();

search = new RepositorySearch(document);

jQuery(function() {
  $('.repository-search').focus();
});
