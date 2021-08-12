var CONTAINER_SELECTOR = '.mergeability-details';
var LOADED_CLASS_FLAG = 'hctw-loaded';
var SHIPIT_ENDPOINT = 'https://[SHIPIT_HOST]/merge_status';

function IframeManager() {
  this.iframe = null;
}

if (typeof chrome !== 'undefined') { // Chrome and Firefox
  IframeManager.prototype.build = function IframeManager_build(url) {
    src = chrome.runtime.getURL('src/frame.html#' + url);
    iframe = document.createElement('iframe');
    iframe.src = src;
    iframe.className = 'hctw-frame branch-action-item';
    iframe.style.display = 'none';
    iframe.style.border = '0px';
    iframe.style.width = '100%';
    iframe.style.padding = '0px';
    iframe.style.height = '0px';
    iframe.scrolling = 'no';
    iframe.sandbox = 'allow-scripts allow-forms allow-same-origin allow-popups allow-popups-to-escape-sandbox';
    return iframe;
  }
} else if (typeof safari !== 'undefined') { // Safari
  IframeManager.prototype.build = function IframeManager_build(url) {
    src = safari.extension.baseURI + 'frame.html#' + url;
    iframe = document.createElement('iframe');
    iframe.src = src;
    iframe.className = 'hctw-frame branch-action-item';
    iframe.style.display = 'none';
    iframe.style.border = '0px';
    iframe.style.width = '100%';
    iframe.style.padding = '0px';
    iframe.style.height = '0px';
    iframe.scrolling = 'no';
    iframe.sandbox = 'allow-scripts allow-forms allow-same-origin allow-popups allow-popups-to-escape-sandbox';
    return iframe;
  }
} else {
  console.error("Unsupported browser")
}

IframeManager.prototype.injectIfMissing = function IframeManager_inject(url) {
  var container = document.querySelector(CONTAINER_SELECTOR)
  if (container) {
    if (!container.classList.contains(LOADED_CLASS_FLAG)) {
      container.classList.add(LOADED_CLASS_FLAG);
      this.iframe = this.build(url);
      container.insertBefore(this.iframe, container.querySelector('.merge-message') || container.firstChild);
      return this.iframe;
    }
  } else {
    this.iframe = null;
  }
};

IframeManager.prototype.resize = function IframeManager_resize(height) {
  if (this.iframe) {
    this.iframe.style.display = '';
    this.iframe.style.height = height + 'px';
    this.iframe.style.borderTop = '1px solid #e5e5e5';
  }
};

IframeManager.prototype.getMergeButtons = function IframeManager_getMergeButtons() {
  return document.querySelectorAll('.merge-message .btn-group-merge button');
};

IframeManager.prototype.diminishDefaultMergeButton = function IframeManager_diminishDefaultMergeButton() {
  this.getMergeButtons().forEach(function(btn) { btn.classList.remove('btn-primary', 'btn-danger'); });
};

IframeManager.prototype.highlightDefaultMergeButton = function IframeManager_highlightDefaultMergeButton() {
  this.getMergeButtons().forEach(function(btn) {
    btn.classList.remove('btn-danger');
    btn.classList.add('btn-primary');
  });
};

IframeManager.prototype.discourageDefaultMergeButton = function IframeManager_discourageDefaultMergeButton() {
  this.getMergeButtons().forEach(function(btn) { btn.classList.add('btn-danger'); });
};

IframeManager.prototype.dispatchEvent = function IframeManager_dipatchEvent(data) {
  if (data && data.event == 'hctw:height:change') {
    this.resize(data.height);
  } else if (data && data.event == 'hctw:stack:info') {
    if (data.queue_enabled) {
      this.diminishDefaultMergeButton();
      if (data.status != 'success') {
        this.discourageDefaultMergeButton()
      }
    } else {
      this.highlightDefaultMergeButton();
    }
  } else {
    console.log('Unhandled event:', data);
  }
};

function hashToQueryString(hash) {
  var components = [];
  Object.keys(hash).forEach(function(key) {
    var value = hash[key];
    if (Array.isArray(value)) {
      components = components.concat(value.map(function(element) {
        return key + '[]=' + encodeURIComponent(element);
      }));
    } else {
      components.push(key + '=' + encodeURIComponent(value));
    }
  });
  return components.join('&')
};

function getStylesheetURLs() {
  var nodes = document.querySelectorAll('link[rel="stylesheet"]');
  return Array.prototype.map.call(nodes, function(n) { return n.href; });
}

function getBranch() {
  var branchSpan = document.querySelectorAll('.commit-ref')[0];
  if (branchSpan) {
    return branchSpan.textContent;
  }
}

function getCommitCount() {
  return document.querySelectorAll('.commit').length
}

var manager = new IframeManager();

window.addEventListener("message", function(event) {
  if (event.data.event && event.data.event.startsWith('hctw:')) {
    manager.dispatchEvent(event.data);
  }
}, false);

function mainLoop() {
  if(window.location.pathname.toLowerCase().indexOf("/[GITHUB_ORGANIZATION]/") == 0) {
    var statusURL = SHIPIT_ENDPOINT + '?' + hashToQueryString({
      "branch": getBranch(),
      "referrer": window.location.toString(),
      "stylesheets": getStylesheetURLs(),
      "commits": getCommitCount()
    });
    manager.injectIfMissing(statusURL);
  }
}

setInterval(mainLoop, 500);
