var OutputLines,
  extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  hasProp = {}.hasOwnProperty,
  bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

OutputLines = (function() {
  function OutputLines(screen, render) {
    this.screen = screen;
    this.render = render;
    this.renderingCache = {};
  }

  OutputLines.prototype.append = function(lines) {
    this.screen.append(this.renderLines(this.filter(lines)));
  };

  OutputLines.prototype.setFilter = function() {
    return true;
  };

  OutputLines.prototype.filter = function(lines) {
    return lines;
  };

  OutputLines.prototype.highlight = function(line) {
    return line;
  };

  OutputLines.prototype.renderLines = function(lines) {
    var base, i, len, line, results;
    results = [];
    for (i = 0, len = lines.length; i < len; i++) {
      line = lines[i];
      results.push(this.highlight((base = this.renderingCache)[line] || (base[line] = this.render(line))));
    }
    return results;
  };

  return OutputLines;

})();

this.ClusterizeOutputLines = (function(superClass) {
  extend(ClusterizeOutputLines, superClass);

  function ClusterizeOutputLines(screen, render) {
    this.screen = screen;
    this.render = render;
    ClusterizeOutputLines.__super__.constructor.apply(this, arguments);
    this.raw = [];
    this.query = '';
    this.highlightRegexp = null;
    this.stripCache = {};
  }

  ClusterizeOutputLines.prototype.append = function(lines) {
    this.raw = this.raw.concat(lines);
    ClusterizeOutputLines.__super__.append.apply(this, arguments);
  };

  ClusterizeOutputLines.prototype.setFilter = function(query) {
    if (this.query = query) {
      this.screen.options.no_data_text = 'No matches';
    } else {
      this.screen.options.no_data_text = 'Loading...';
    }
    this.highlightRegexp = this.buildHighlightRegexp(this.query);
    this.reset();
  };

  ClusterizeOutputLines.prototype.reset = function() {
    this.screen.update(this.renderLines(this.filter(this.raw)));
  };

  ClusterizeOutputLines.prototype.strip = function(line) {
    var base;
    return (base = this.stripCache)[line] || (base[line] = AnsiStream.strip(line));
  };

  ClusterizeOutputLines.prototype.filter = function(lines) {
    var i, len, line, results;
    if (!this.query) {
      return lines;
    }
    results = [];
    for (i = 0, len = lines.length; i < len; i++) {
      line = lines[i];
      if (this.strip(line).includes(this.query)) {
        results.push(line);
      }
    }
    return results;
  };

  ClusterizeOutputLines.prototype.buildHighlightRegexp = function(query) {
    var pattern;
    pattern = query.replace(/[|\\{}()[\]^$+*?.]/g, '\\$&').replace(/(\s+)/g, '(<[^>]+>)*$1(<[^>]+>)*');
    return new RegExp("(" + pattern + ")", 'g');
  };

  ClusterizeOutputLines.prototype.highlight = function(renderedLine) {
    if (!this.query) {
      return renderedLine;
    }
    return renderedLine.replace(this.highlightRegexp, '<mark>$1</mark>').replace(/(<mark>[^<>]*)((<[^>]+>)+)([^<>]*<\/mark>)/, '$1</mark>$2<mark>$4');
  };

  return ClusterizeOutputLines;

})(OutputLines);

this.TTY = (function() {
  var FORMATTERS, STICKY_SCROLL_TOLERENCE;

  FORMATTERS = [];

  STICKY_SCROLL_TOLERENCE = 200;

  TTY.appendFormatter = function(formatter) {
    FORMATTERS.push(formatter);
  };

  TTY.prependFormatter = function(formatter) {
    FORMATTERS.unshift(formatter);
  };

  function TTY($body) {
    this.appendChunk = bind(this.appendChunk, this);
    this.filterOutput = bind(this.filterOutput, this);
    var scroller;
    this.outputLines = [];
    this.$code = $body.find('code');
    this.$container = this.$code.closest('.task-output-container');
    if (this.$container.hasClass('clusterize-scroll')) {
      scroller = new Clusterize({
        no_data_text: 'Loading...',
        tag: 'div',
        contentElem: this.$code[0],
        scrollElem: this.$container[0]
      });
      this.output = new ClusterizeOutputLines(scroller, (function(_this) {
        return function(line) {
          return _this.createLine(_this.formatChunks(line));
        };
      })(this));
    } else {
      this.output = new OutputLines(this.$code, (function(_this) {
        return function(line) {
          return _this.createLine(_this.formatChunks(line));
        };
      })(this));
    }
  }

  TTY.prototype.filterOutput = function(query) {
    this.output.setFilter(query);
  };

  TTY.prototype.formatChunks = function(chunk) {
    var formatter, i, len;
    for (i = 0, len = FORMATTERS.length; i < len; i++) {
      formatter = FORMATTERS[i];
      chunk = formatter(chunk) || chunk;
    }
    return chunk;
  };

  TTY.prototype.appendChunk = function(chunk) {
    var lines;
    lines = chunk.rawLines();
    if (!lines.length) {
      return;
    }
    this.preserveScroll((function(_this) {
      return function() {
        _this.output.append(lines);
      };
    })(this));
  };

  TTY.prototype.createLine = function(fragment) {
    var div;
    div = document.createElement('div');
    div.appendChild(fragment);
    div.className = 'output-line';
    return div.outerHTML;
  };

  TTY.prototype.isScrolledToBottom = function() {
    return (this.getMaxScroll() - this.$container.scrollTop()) < 1;
  };

  TTY.prototype.scrollToBottom = function() {
    this.$container.scrollTop(this.getMaxScroll());
  };

  TTY.prototype.getMaxScroll = function() {
    return this.$code.parent().outerHeight(true) - this.$container.outerHeight(true);
  };

  TTY.prototype.preserveScroll = function(callback) {
    var wasScrolledToBottom;
    wasScrolledToBottom = this.isScrolledToBottom();
    callback();
    if (wasScrolledToBottom) {
      this.scrollToBottom();
    }
  };

  return TTY;

})();
