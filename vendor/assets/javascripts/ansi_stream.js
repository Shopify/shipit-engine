// Compiled from ansi_stream gem's ansi_stream.coffee using CoffeeScript 1.12.7
var AnsiSpan, AnsiStyle;

this.AnsiStream = (function() {
  var ANSI_CODE;

  ANSI_CODE = /((\u001b\[)|\u009b)(\d{0,3}(;\d{0,3})*[A-M|f-m])|\u001b[A-M]/g;

  AnsiStream.strip = function(text) {
    return text.replace(ANSI_CODE, '');
  };

  function AnsiStream() {
    this.style = new AnsiStyle();
    this.span = new AnsiSpan();
  }

  AnsiStream.prototype.process = function(text) {
    var first_part, i, len, part, partText, parts, ref, span, spans, styles;
    parts = text.split(/\033\[/);
    spans = document.createDocumentFragment();
    first_part = parts.shift();
    if (first_part) {
      spans.appendChild(this.span.create(first_part, this.style));
    }
    for (i = 0, len = parts.length; i < len; i++) {
      part = parts[i];
      ref = this._extractTextAndStyles(part), partText = ref[0], styles = ref[1];
      this.style.apply(styles);
      span = this.span.create(partText, this.style);
      spans.appendChild(span);
    }
    return spans;
  };

  AnsiStream.prototype._extractTextAndStyles = function(originalText) {
    var matches, numbers, ref, text;
    matches = originalText.match(/^([\d;]*)m([^]*)$/);
    if (!matches) {
      return [originalText, null];
    }
    ref = matches, matches = ref[0], numbers = ref[1], text = ref[2];
    return [text, numbers.split(";")];
  };

  return AnsiStream;

})();

AnsiStyle = (function() {
  var COLORS;

  COLORS = {
    0: 'black',
    1: 'red',
    2: 'green',
    3: 'yellow',
    4: 'blue',
    5: 'magenta',
    6: 'cyan',
    7: 'white',
    8: null,
    9: 'default'
  };

  function AnsiStyle() {
    this.reset();
  }

  AnsiStyle.prototype.apply = function(newStyles) {
    var i, len, style;
    if (!newStyles) {
      return;
    }
    for (i = 0, len = newStyles.length; i < len; i++) {
      style = newStyles[i];
      style = parseInt(style);
      if (style === 0) {
        this.reset();
      } else if (style === 1) {
        this.bright = true;
      } else if ((30 <= style && style <= 39) && style !== 38) {
        this._applyStyle('foreground', style);
      } else if ((40 <= style && style <= 49) && style !== 48) {
        this._applyStyle('background', style);
      } else if (style === 4) {
        this.underline = true;
      } else if (style === 24) {
        this.underline = false;
      }
    }
  };

  AnsiStyle.prototype.reset = function() {
    this.background = this.foreground = 'default';
    this.underline = this.bright = false;
  };

  AnsiStyle.prototype.toClass = function() {
    var classes;
    classes = [];
    if (this.background) {
      classes.push("ansi-background-" + this.background);
    }
    if (this.foreground) {
      classes.push("ansi-foreground-" + this.foreground);
    }
    if (this.bright) {
      classes.push("ansi-bright");
    }
    if (this.underline) {
      classes.push("ansi-underline");
    }
    return classes.join(" ");
  };

  AnsiStyle.prototype._applyStyle = function(layer, number) {
    this[layer] = COLORS[number % 10];
  };

  return AnsiStyle;

})();

AnsiSpan = (function() {
  function AnsiSpan() {}

  AnsiSpan.prototype.create = function(text, style) {
    var span;
    span = document.createElement('span');
    span.textContent = text;
    span.className = style.toClass();
    return span;
  };

  return AnsiSpan;

})();
