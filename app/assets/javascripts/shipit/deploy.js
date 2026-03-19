var AbortButton,
  bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

AbortButton = (function() {
  var SELECTOR;

  SELECTOR = '[data-action="abort"]';

  AbortButton.listen = function() {
    return $(document).on('click', SELECTOR, this.handle);
  };

  AbortButton.handle = function(event) {
    var button;
    event.preventDefault();
    button = new AbortButton($(event.currentTarget));
    button.trigger();
  };

  function AbortButton($button) {
    this.$button = $button;
    this.reenable = bind(this.reenable, this);
    this.waitForCompletion = bind(this.waitForCompletion, this);
    this.url = this.$button.attr('href');
    this.shouldRollback = this.$button.data('rollback');
  }

  AbortButton.prototype.trigger = function() {
    if (this.isDisabled()) {
      return false;
    }
    this.disable();
    this.waitForCompletion();
    $.post(this.url).success(this.waitForCompletion).error(this.reenable);
  };

  AbortButton.prototype.waitForCompletion = function() {
    setTimeout(this.reenable, 3000);
  };

  AbortButton.prototype.reenable = function() {
    this.$button.removeClass('pending btn-disabled');
    this.$button.siblings(SELECTOR).removeClass('btn-disabled');
  };

  AbortButton.prototype.disable = function() {
    this.$button.addClass('pending btn-disabled');
    this.$button.siblings(SELECTOR).addClass('btn-disabled');
  };

  AbortButton.prototype.isDisabled = function() {
    return this.$button.hasClass('btn-disabled');
  };

  return AbortButton;

})();

AbortButton.listen();
