var bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

this.SearchBar = (function() {
  var DEBOUNCE;

  DEBOUNCE = 300;

  function SearchBar($bar) {
    this.$bar = $bar;
    this.closeIfEmpty = bind(this.closeIfEmpty, this);
    this.open = bind(this.open, this);
    this.immediateBroadcastQueryChange = bind(this.immediateBroadcastQueryChange, this);
    this.updateQuery = bind(this.updateQuery, this);
    this.eventListeners = {};
    this.query = window.location.hash.replace(/^#/, '');
    this.$input = this.$bar.find('.search-input');
    this.$input.on('blur', this.closeIfEmpty);
    this.$input.on('input', this.updateQuery);
    this.broadcastQueryChange = _.debounce(this.immediateBroadcastQueryChange, DEBOUNCE);
    Mousetrap.bindGlobal(['command+f', 'ctrl+f'], this.open);
    if (this.query) {
      this.open();
      this.setQuery(this.query);
    }
  }

  SearchBar.prototype.addEventListener = function(type, handler) {
    this.listeners(type).push(handler);
  };

  SearchBar.prototype.listeners = function(type) {
    var base;
    return (base = this.eventListeners)[type] || (base[type] = []);
  };

  SearchBar.prototype.setQuery = function(query) {
    this.$input.val(query);
    this.updateQuery();
  };

  SearchBar.prototype.updateQuery = function() {
    var oldQuery;
    oldQuery = this.query;
    this.query = this.$input.val();
    if (this.query !== oldQuery) {
      this.broadcastQueryChange();
    }
  };

  SearchBar.prototype.immediateBroadcastQueryChange = function() {
    var handler, i, len, ref;
    this.updateHash();
    ref = this.listeners('query');
    for (i = 0, len = ref.length; i < len; i++) {
      handler = ref[i];
      handler(this.query);
    }
  };

  SearchBar.prototype.updateHash = function() {
    window.location.hash = "#" + this.query;
  };

  SearchBar.prototype.open = function(event) {
    if (event != null) {
      event.preventDefault();
    }
    this.$bar.removeClass('hidden');
    this.focus();
  };

  SearchBar.prototype.focus = function() {
    this.$input.focus()[0].select();
  };

  SearchBar.prototype.closeIfEmpty = function(event) {
    if (!this.query.length) {
      this.close();
    }
  };

  SearchBar.prototype.close = function() {
    this.$bar.addClass('hidden');
  };

  return SearchBar;

})();
