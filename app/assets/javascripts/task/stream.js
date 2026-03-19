var Chunk,
  bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  slice = [].slice;

Chunk = (function() {
  function Chunk(raw) {
    this.raw = raw;
  }

  Chunk.prototype.rawText = function() {
    return this.raw;
  };

  Chunk.prototype.text = function() {
    return this._text || (this._text = AnsiStream.strip(this.raw));
  };

  Chunk.prototype.rawLines = function() {
    return this._rawLines || (this._rawLines = this.splitLines(this.raw));
  };

  Chunk.prototype.lines = function() {
    return this._lines || (this._lines = this.splitLines(this.text()));
  };

  Chunk.prototype.splitLines = function(text) {
    var lines;
    lines = text.split(/\r?\n/);
    if (!lines[lines.length - 1]) {
      lines.pop();
    }
    return lines;
  };

  return Chunk;

})();

this.Stream = (function() {
  var INTERVAL, MAX_RETRIES;

  INTERVAL = 1000;

  MAX_RETRIES = 15;

  function Stream() {
    this.error = bind(this.error, this);
    this.success = bind(this.success, this);
    this.poll = bind(this.poll, this);
    this.url = null;
    this.eventListeners = {};
    this.retries = 0;
    this.status = 'running';
  }

  Stream.prototype.init = function(arg) {
    var status, text, url;
    url = arg.url, text = arg.text, status = arg.status;
    this.status = status;
    this.broadcastOutput(text);
    this.start(url);
  };

  Stream.prototype.poll = function() {
    jQuery.ajax(this.url, {
      success: this.success,
      error: this.error
    });
  };

  Stream.prototype.success = function(response) {
    this.retries = 0;
    this.broadcastOutput(response.output, response);
    this.broadcastStatus(response.status, response);
    this.start(response.url || false);
  };

  Stream.prototype.broadcastStatus = function() {
    var args, error, handler, i, len, ref, status;
    status = arguments[0], args = 2 <= arguments.length ? slice.call(arguments, 1) : [];
    if (status !== this.status) {
      this.status = status;
      ref = this.listeners('status');
      for (i = 0, len = ref.length; i < len; i++) {
        handler = ref[i];
        try {
          handler.apply(null, [status].concat(slice.call(args)));
        } catch (error1) {
          error = error1;
          if (typeof console !== "undefined" && console !== null) {
            console.log("Plugin error: " + error);
          }
        }
      }
    }
  };

  Stream.prototype.broadcastOutput = function() {
    var args, chunk, error, handler, i, len, raw, ref;
    raw = arguments[0], args = 2 <= arguments.length ? slice.call(arguments, 1) : [];
    if (!raw) {
      return;
    }
    chunk = new Chunk(raw);
    ref = this.listeners('chunk');
    for (i = 0, len = ref.length; i < len; i++) {
      handler = ref[i];
      try {
        handler.apply(null, [chunk].concat(slice.call(args)));
      } catch (error1) {
        error = error1;
        if (typeof console !== "undefined" && console !== null) {
          console.log("Plugin error: " + error);
        }
      }
    }
  };

  Stream.prototype.error = function(response) {
    var ref;
    if ((600 > (ref = response.status) && ref >= 500) && (this.retries += 1) < MAX_RETRIES) {
      this.start();
    }
  };

  Stream.prototype.start = function(url) {
    if (url == null) {
      url = this.url;
    }
    if (this.url = url) {
      setTimeout(this.poll, INTERVAL);
    }
  };

  Stream.prototype.addEventListener = function(type, handler) {
    this.listeners(type).push(handler);
  };

  Stream.prototype.listeners = function(type) {
    var base;
    return (base = this.eventListeners)[type] || (base[type] = []);
  };

  return Stream;

})();
