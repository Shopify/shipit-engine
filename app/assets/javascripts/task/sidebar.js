this.Sidebar = (function() {
  var INSTANCE;

  INSTANCE = null;

  Sidebar.instance = function() {
    return INSTANCE || (INSTANCE = new this($('.sidebar'), $('.sidebar-plugins')));
  };

  Sidebar.newWidgetContainer = function() {
    return Sidebar.instance().newWidgetContainer();
  };

  function Sidebar($sidebar, $container) {
    this.$sidebar = $sidebar;
    this.$container = $container;
  }

  Sidebar.prototype.newWidgetContainer = function() {
    this.$sidebar.addClass('enabled');
    return $(document.createElement('div')).addClass('sidebar-plugin').prependTo(this.$container);
  };

  return Sidebar;

})();
