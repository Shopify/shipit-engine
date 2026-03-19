var PageUpdater,
  bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

PageUpdater = (function() {
  var DEBOUNCE, MAX_RETRIES, RETRY_DELAY;

  DEBOUNCE = 100;

  RETRY_DELAY = 5000;

  MAX_RETRIES = 5;

  PageUpdater.callbacks = [];

  PageUpdater.afterUpdate = function(callback) {
    this.callbacks.push(callback);
  };

  function PageUpdater(channel, selectors) {
    this.channel = channel;
    this.selectors = selectors;
    this.updatePage = bind(this.updatePage, this);
    this.fetchPage = bind(this.fetchPage, this);
    this.scheduleUpdate = bind(this.scheduleUpdate, this);
    this.requestUpdate = bind(this.requestUpdate, this);
    this.parser = new DOMParser();
    this.source = this.listen();
    this.previousLastModified = null;
  }

  PageUpdater.prototype.requestUpdate = function() {
    this.updateRequested = true;
    this.scheduleUpdate();
  };

  PageUpdater.prototype.scheduleUpdate = function() {
    if (this.updateScheduled) {
      return;
    }
    if (!this.updateRequested) {
      return;
    }
    setTimeout(this.fetchPage, DEBOUNCE);
    this.updateScheduled = true;
  };

  PageUpdater.prototype.fetchPage = function(message) {
    this.updateRequested = false;
    jQuery.get(window.location.toString()).done(this.updatePage).fail((function(_this) {
      return function() {
        _this.updateScheduled = false;
      };
    })(this));
  };

  PageUpdater.prototype.updatePage = function(html, status, response) {
    var callback, i, j, lastModified, len, len1, newDocument, ref, ref1, selector;
    lastModified = response.getResponseHeader('last-modified');
    if ((lastModified != null) && lastModified !== this.previousLastModified) {
      this.previousLastModified = lastModified;
      newDocument = this.parser.parseFromString(html, 'text/html');
      ref = this.selectors;
      for (i = 0, len = ref.length; i < len; i++) {
        selector = ref[i];
        $(selector).html(newDocument.querySelectorAll(selector + " > *"));
      }
      ref1 = PageUpdater.callbacks;
      for (j = 0, len1 = ref1.length; j < len1; j++) {
        callback = ref1[j];
        callback();
      }
    }
    this.updateScheduled = false;
  };

  PageUpdater.prototype.listen = function() {
    this.source = new EventSource(this.channel);
    this.source.addEventListener('update', this.requestUpdate);
    this.retries = MAX_RETRIES;
    this.interval = setInterval((function(_this) {
      return function() {
        switch (_this.source.readyState) {
          case _this.source.CLOSED:
            clearInterval(_this.interval);
            if (_this.retries > 0) {
              _this.retries -= 1;
              _this.listen();
            }
            break;
          default:
            _this.retries = MAX_RETRIES;
        }
      };
    })(this), RETRY_DELAY);
  };

  return PageUpdater;

})();

jQuery(function($) {
  var channel, e, selectors;
  PageUpdater.afterUpdate(function() {
    $('time[data-time-ago]').timeago();
  });
  channel = $('meta[name=subscription-channel]').attr('content');
  selectors = (function() {
    var i, len, ref, results;
    ref = $('meta[name=subscription-selector]');
    results = [];
    for (i = 0, len = ref.length; i < len; i++) {
      e = ref[i];
      results.push(e.content);
    }
    return results;
  })();
  if (channel && selectors) {
    new PageUpdater(channel, selectors);
  }
});
