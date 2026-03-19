var KEY, StackSearch, search,
  slice = [].slice,
  bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

if (!String.prototype.contains) {
  String.prototype.contains = function() {
    var args;
    args = 1 <= arguments.length ? slice.call(arguments, 0) : [];
    return this.indexOf.apply(this, args) !== -1;
  };
}

KEY = {
  UP: 38,
  DOWN: 40,
  ENTER: 13
};

StackSearch = (function() {
  function StackSearch(root) {
    this.onKeyUp = bind(this.onKeyUp, this);
    this.$root = $(root);
    this.$root.on('keyup', '.stack-search', this.onKeyUp);
    this.$root.on('click', '.show-all-stacks', (function(_this) {
      return function(event) {
        _this.$root.find('.not-matching').removeClass('not-matching');
        event.preventDefault();
      };
    })(this));
  }

  StackSearch.prototype.onKeyUp = function(event) {
    this.$items = this.$root.find('[data-search]');
    switch (event.keyCode) {
      case KEY.ENTER:
        event.preventDefault();
        this.goToSelectedStack();
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

  StackSearch.prototype.filterResults = function(query) {
    var $item, i, item, len, ref;
    if (query) {
      ref = this.$items;
      for (i = 0, len = ref.length; i < len; i++) {
        item = ref[i];
        $item = $(item);
        $item.toggleClass('not-matching', !$item.attr('data-search').toLowerCase().contains(query));
      }
      this.selectFirst();
    } else {
      this.$items.removeClass('not-matching');
    }
  };

  StackSearch.prototype.selectFirst = function() {
    this.$items.removeClass('selected').first(':not(.not-matching)').addClass('selected');
  };

  StackSearch.prototype.selectNext = function() {
    var $next;
    $next = this.$items.filter('.selected').removeClass('selected').nextAll(':not(.not-matching)').first();
    if (!$next.length) {
      $next = this.$items.filter(':not(.not-matching)').first();
    }
    $next.addClass('selected');
  };

  StackSearch.prototype.selectPrevious = function() {
    var $previous;
    $previous = this.$items.filter('.selected').removeClass('selected').prevAll(':not(.not-matching)').first();
    if (!$previous.length) {
      $previous = this.$items.filter(':not(.not-matching)').last();
    }
    $previous.addClass('selected');
  };

  StackSearch.prototype.goToSelectedStack = function() {
    var stack;
    if (stack = this.$items.filter('.selected').filter(':not(.not-matching)').find('.commits-path').attr('href')) {
      window.location = stack;
    }
  };

  return StackSearch;

})();

search = new StackSearch(document);

jQuery(function() {
  $('.stack-search').focus();
});
