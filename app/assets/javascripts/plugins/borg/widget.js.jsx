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
      hostClass = 'task-lights'
      if (this.props.containers.length > 10) {
        hostClass += ' wide';
      }
      return (
        <div className={hostClass}>
          <span className="task-lights-text">
              <span className="task-lights-title">{this.props.name}</span>
              <span className="task-lights-boxes">{this.renderContainers()}</span>
          </span>
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
      classes = 'task-lights-box box-' + this.props.status
      return (
        <span className={classes} />
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
          <h2 className="task-group-heading">Restarting Servers</h2>
          <HostList hosts={this.state.hosts} />
        </div>
      );
    }
  });
})();
