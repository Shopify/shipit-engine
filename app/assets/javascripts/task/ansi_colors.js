//= require ansi_stream
//= require ./tty

var stream;

stream = new AnsiStream();

TTY.appendFormatter(function(chunk) {
  return stream.process(chunk);
});
