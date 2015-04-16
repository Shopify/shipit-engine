//= require react

var DataCenterStatus = (function() {
  var HostList = React.createClass({
    render: function() {
      return (
        <div className="container-tasks">
          {this.renderHosts()}
        </div>
      );
    },
    renderHosts: function() {
      return this.props.hosts.map(function (host) {
        return (
          <Host {...host} />
        );
      });
    }
  });

  var Host = React.createClass({
    render: function() {
      hostClass = 'borg-host'
      if (this.props.containers.length > 10) {
        hostClass += ' wide';
      }
      return (
        <div className={hostClass}>
          <span className="borg-host-name">{this.props.name}</span>
          <span className="borg-containers">{this.renderContainers()}</span>
        </div>
      );
    },
    renderContainers: function() {
      return this.props.containers.map(function (container) {
        return <Container {...container} />
      });
    }
  });

  var Container = React.createClass({
    render: function() {
      classes = 'borg-container borg-status-' + this.props.status
      return (
        <span className={classes} data-tooltip={this.props.name} />
      );
    }
  });

  return React.createClass({
    getInitialState: function() {
      return {hosts: []}
    },
    render: function() {
      return (
        <div>
          <h2 className="borg-widget-title">Restarting Servers</h2>
          <HostList hosts={this.state.hosts} />
        </div>
      );
    }
  });
})();
