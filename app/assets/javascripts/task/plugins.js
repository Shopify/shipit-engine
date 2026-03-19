this.Shipit || (this.Shipit = {});

this.Shipit.Plugins = {
  config: function(name) {
    var config;
    config = $("meta[name=\"" + name + "-config\"]").attr('content');
    try {
      return JSON.parse(config);
    } catch (error) {
      return null;
    }
  }
};
