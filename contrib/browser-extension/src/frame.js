
function buildIframe(statusURL) {
  iframe = document.createElement('iframe');
  iframe.src =  statusURL;
  iframe.style.border = '0px';
  iframe.style.width = '100%';
  iframe.scrolling = 'no';
  return iframe;
}

var statusURL = window.location.hash.replace(/^#/, '')
window.document.body.appendChild(buildIframe(statusURL));

window.addEventListener("message", function(event) {
  if (event.data && event.data.event && event.data.event.startsWith('hctw:')) {
    window.parent.postMessage(event.data, '*');
  }
}, false);
