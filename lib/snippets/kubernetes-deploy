#!/usr/bin/env ruby

# Usage: kubernetes-deploy <app's namespace> <kube context>

# Prerequisites:
#  - kubectl 1.5.1+ binary must be available in the shipit machine's path
#  - ENV['KUBECONFIG'] must point to a valid kubeconfig file that includes all the contexts you want to deploy to
#  - ENV['GOOGLE_APPLICATION_CREDENTIALS'] must point to the credentials for an authenticated service account if your user's auth provider is gcp

# Optionally, the following variables can be used to override script defaults:
#  - ENV['K8S_TEMPLATE_FOLDER']: Location of Kubernetes files to deploy. Default is config/deploy/#{environment}.

require 'open3'
require 'securerandom'
require 'erb'
require 'json'
require 'yaml'
require 'shellwords'
require 'tempfile'
require 'logger'
require 'active_support/core_ext/object/blank'
require 'active_support/descendants_tracker'
require 'active_support/core_ext/hash/slice'
require 'active_support/core_ext/numeric/time'

class KubernetesDeploy
  class FatalDeploymentError < StandardError; end

  # Things removed from default prune whitelist:
  # core/v1/Namespace -- not namespaced
  # core/v1/PersistentVolume -- not namespaced
  # core/v1/Endpoints -- managed by services
  # core/v1/PersistentVolumeClaim -- would delete data
  # core/v1/ReplicationController -- superseded by deployments/replicasets
  # extensions/v1beta1/ReplicaSet -- managed by deployments
  # core/v1/Secret -- should not committed / managed by shipit
  PRUNE_WHITELIST = %w(
    core/v1/ConfigMap
    core/v1/Pod
    core/v1/Service
    batch/v1/Job
    extensions/v1beta1/DaemonSet
    extensions/v1beta1/Deployment
    extensions/v1beta1/HorizontalPodAutoscaler
    extensions/v1beta1/Ingress
    apps/v1beta1/StatefulSet
  ).freeze

  PREDEPLOY_SEQUENCE = %w(
    ConfigMap
    PersistentVolumeClaim
    Pod
  )

  def initialize(namespace:, environment:, current_sha:, template_folder: nil, context:)
    @namespace = namespace
    @context = context
    @current_sha = current_sha
    @template_path = File.expand_path('./' + (template_folder || "config/deploy/#{environment}"))
    # Max length of podname is only 63chars so try to save some room by truncating sha to 8 chars
    @id = current_sha[0...8] + "-#{SecureRandom.hex(4)}" if current_sha
  end

  def run
    @current_phase = 0
    phase_heading("Validating configuration")
    validate_configuration

    phase_heading("Configuring kubectl")
    set_kubectl_context
    validate_namespace

    phase_heading("Parsing deploy content")
    resources = discover_resources

    phase_heading("Checking initial resource statuses")
    resources.each(&:sync)

    phase_heading("Predeploying priority resources")
    predeploy_priority_resources(resources)

    phase_heading("Deploying all resources")
    deploy_resources(resources, prune: true)
    wait_for_completion(resources)

    report_final_status(resources)
  rescue FatalDeploymentError => error
    KubernetesDeploy.logger.fatal(error.message)
    exit 1
  end

  def template_variables
    {
      'current_sha' => @current_sha,
      'deployment_id' => @id,
    }
  end

  private

  def predeploy_priority_resources(resource_list)
    PREDEPLOY_SEQUENCE.each do |resource_type|
      matching_resources = resource_list.select { |r| r.type == resource_type }
      next if matching_resources.empty?
      deploy_resources(matching_resources)
      wait_for_completion(matching_resources)
      fail_count = matching_resources.count { |r| r.deploy_failed? || r.deploy_timed_out? }
      if fail_count > 0
        raise FatalDeploymentError, "#{fail_count} priority resources failed to deploy"
      end
    end
  end

  def discover_resources
    resources = []
    Dir.foreach(@template_path) do |filename|
      next unless filename.end_with?(".yml.erb", ".yml")

      split_templates(filename) do |tempfile|
        resource_id = discover_resource_via_dry_run(tempfile)
        type, name = resource_id.split("/", 2) # e.g. "pod/web-198612918-dzvfb"
        resources << KubernetesResource.for_type(type, name, @namespace, tempfile)
        KubernetesDeploy.logger.info "Discovered template for #{resource_id}"
      end
    end
    resources
  end

  def discover_resource_via_dry_run(tempfile)
    resource_id, err, st = run_kubectl("apply", "-f", tempfile.path, "--dry-run", "--output=name")
    raise FatalDeploymentError, "Dry run failed for template #{File.basename(tempfile.path)}." unless st.success?
    resource_id
  end

  def split_templates(filename)
    file_content = File.read(File.join(@template_path, filename))
    rendered_content = render_template(filename, file_content)
    YAML.load_stream(rendered_content) do |doc|
      f = Tempfile.new(filename)
      f.write(YAML.dump(doc))
      f.close
      yield f
    end
  rescue Psych::SyntaxError => e
    KubernetesDeploy.logger.error(rendered_content)
    raise FatalDeploymentError, "Template #{filename} cannot be parsed: #{e.message}"
  end

  def report_final_status(resources)
    if resources.all?(&:deploy_succeeded?)
      log_green("Deploy succeeded!")
    else
      fail_list = resources.select { |r| r.deploy_failed? || r.deploy_timed_out? }.map(&:id)
      KubernetesDeploy.logger.error("The following resources failed to deploy: #{fail_list.join(", ")}")
      raise FatalDeploymentError, "#{fail_list.length} resources failed to deploy"
    end
  end

  def wait_for_completion(watched_resources)
    delay_sync_until = Time.now.utc
    while watched_resources.present?
      if Time.now.utc < delay_sync_until
        sleep (delay_sync_until - Time.now.utc)
      end
      delay_sync_until = Time.now.utc + 3 # don't pummel the API if the sync is fast
      watched_resources.each(&:sync)
      newly_finished_resources, watched_resources = watched_resources.partition(&:deploy_finished?)
      newly_finished_resources.each do |resource|
        next unless resource.deploy_failed? || resource.deploy_timed_out?
        KubernetesDeploy.logger.error("#{resource.id} failed to deploy with status '#{resource.status}'.")
        KubernetesDeploy.logger.error("This script will continue to poll until the status of all resources deployed in this phase is resolved, but the deploy is now doomed and you may wish abort it.")
        KubernetesDeploy.logger.error(resource.status_data)
      end
    end
  end

  def render_template(filename, raw_template)
    return raw_template unless File.extname(filename) == ".erb"

    erb_template = ERB.new(raw_template)
    erb_binding = binding
    template_variables.each do |var_name, value|
      erb_binding.local_variable_set(var_name, value)
    end
    erb_template.result(erb_binding)
  end

  def validate_configuration
    errors = []
    if ENV["KUBECONFIG"].blank? || !File.file?(ENV["KUBECONFIG"])
      errors << "Kube config not found at #{ENV["KUBECONFIG"]}"
    end

    if @current_sha.blank?
      errors << "Current SHA must be specified"
    end

    if !File.directory?(@template_path)
      errors << "Template path #{@template_path} doesn't exist"
    elsif Dir.entries(@template_path).none? { |file| file =~ /\.yml(\.erb)?$/ }
      errors << "#{@template_path} doesn't contain valid templates (postfix .yml or .yml.erb)"
    end

    if @namespace.blank?
      errors << "Namespace must be specified"
    end

    if @context.blank?
      errors << "Context must be specified"
    end

    raise FatalDeploymentError, "Configuration invalid: #{errors.join(", ")}" unless errors.empty?
    KubernetesDeploy.logger.info("All required parameters and files are present")
  end

  def deploy_resources(resources, prune: false)
    command = ["apply", "--namespace=#{@namespace}"]
    KubernetesDeploy.logger.info("Deploying resources:")

    resources.each do |r|
      KubernetesDeploy.logger.info("- #{r.id}")
      command.push("-f", r.file.path)
      r.deploy_started = Time.now.utc
    end

    if prune
      command.push("--prune", "--all")
      PRUNE_WHITELIST.each { |type| command.push("--prune-whitelist=#{type}") }
    end

    run_kubectl(*command)
  end

  def set_kubectl_context
    out, err, st = run_kubectl("config", "get-contexts", "-o", "name", namespaced: false)
    available_contexts = out.split("\n")
    if !st.success?
      raise FatalDeploymentError, err
    elsif !available_contexts.include?(@context)
      raise FatalDeploymentError, "Context #{@context} is not available. Valid contexts: #{available_contexts}"
    end

    _, err, st = run_kubectl("config", "use-context", @context, namespaced: false)
    raise FatalDeploymentError, "Kubectl config is not valid: #{err}" unless st.success?
    KubernetesDeploy.logger.info("Kubectl configured to use context #{@context}")
  end

  def validate_namespace
    _, _, st = run_kubectl("get", "namespace", @namespace, namespaced: false)
    raise FatalDeploymentError, "Failed to validate namespace #{@namespace}" unless st.success?
    KubernetesDeploy.logger.info("Namespace #{@namespace} validated")
  end

  def run_kubectl(*args, namespaced: true)
    args = args.unshift("kubectl")
    if namespaced
      raise FatalDeploymentError, "Namespace missing for namespaced command" unless @namespace
      args.push("--namespace=#{@namespace}")
    end
    KubernetesDeploy.logger.debug Shellwords.join(args)
    out, err, st = Open3.capture3(*args)
    KubernetesDeploy.logger.debug(out.shellescape)
    KubernetesDeploy.logger.warn(err) unless st.success?
    [out.chomp, err.chomp, st]
  end

  def phase_heading(phase_name)
    @current_phase += 1
    heading = "Phase #{@current_phase}: #{phase_name}"
    padding = (100.0 - heading.length)/2
    KubernetesDeploy.logger.info("")
    KubernetesDeploy.logger.info("#{'-' * padding.floor}#{heading}#{'-' * padding.ceil}")
  end

  def log_green(msg)
    STDOUT.puts "\033[0;32m#{msg}\x1b[0m\n" # green
  end

  def self.logger
    @logger ||= begin
      l = Logger.new(STDOUT)
      l.level = ENV["DEBUG"] ? Logger::DEBUG : Logger::INFO
      l.formatter = proc do |severity, _datetime, _progname, msg|
        case severity
        when "FATAL", "ERROR" then "\033[0;31m[#{severity}]\t#{msg}\x1b[0m\n" # red
        when "WARN" then "\033[0;33m[#{severity}]\t#{msg}\x1b[0m\n" # yellow
        when "INFO" then "\033[0;36m#{msg}\x1b[0m\n" # blue
        else "[#{severity}]\t#{msg}\n"
        end
      end
      l
    end
  end

  class KubernetesResource
    extend ActiveSupport::DescendantsTracker

    attr_reader :name, :namespace, :file
    attr_writer :type, :deploy_started

    TIMEOUT = 5.minutes

    def self.handled_type
      name.split('::').last
    end

    def self.for_type(type, name, namespace, file)
      if subclass = descendants.find { |subclass| subclass.handled_type.downcase == type }
        subclass.new(name, namespace, file)
      else
        self.new(name, namespace, file).tap { |r| r.type = type }
      end
    end

    def initialize(name, namespace, file)
      # subclasses must also set these
      @name, @namespace, @file = name, namespace, file
    end

    def id
      "#{type}/#{name}"
    end

    def sync
      log_status
    end

    def deploy_failed?
      false
    end

    def deploy_succeeded?
      if @deploy_started && !@success_assumption_warning_shown
        KubernetesDeploy.logger.warn("Don't know how to monitor resources of type #{type}. Assuming #{id} deployed successfully.")
        @success_assumption_warning_shown = true
      end
      true
    end

    def exists?
      nil
    end

    def status
      @status ||= "Unknown"
      deploy_timed_out? ? "Timed out with status #{@status}" : @status
    end

    def type
      @type || self.class.handled_type
    end

    def deploy_finished?
      deploy_failed? || deploy_succeeded? || deploy_timed_out?
    end

    def deploy_timed_out?
      return false unless @deploy_started
      !deploy_succeeded? && !deploy_failed? && (Time.now.utc - @deploy_started > self.class::TIMEOUT)
    end

    def status_data
      {
        group: group_name,
        name: name,
        status_string: status,
        exists: exists?,
        succeeded: deploy_succeeded?,
        failed: deploy_failed?,
        timed_out: deploy_timed_out?
      }
    end

    def group_name
      type + "s"
    end

    def run_kubectl(*args)
      raise FatalDeploymentError, "Namespace missing for namespaced command" if namespace.blank?
      args = args.unshift("kubectl").push("--namespace=#{namespace}")
      KubernetesDeploy.logger.debug Shellwords.join(args)
      out, err, st = Open3.capture3(*args)
      KubernetesDeploy.logger.debug(out.shellescape)
      KubernetesDeploy.logger.debug("[ERROR] #{err.shellescape}") unless st.success?
      [out.chomp, st]
    end

    def log_status
      STDOUT.puts "[KUBESTATUS] #{JSON.dump(status_data)}"
    end
  end

  class ConfigMap < KubernetesResource
    TIMEOUT = 30.seconds

    def initialize(name, namespace, file)
      @name, @namespace, @file = name, namespace, file
    end

    def sync
      _, st = run_kubectl("get", type, @name)
      @status = st.success? ? "Available" : "Unknown"
      @found = st.success?
      log_status
    end

    def deploy_succeeded?
      exists?
    end

    def deploy_failed?
      false
    end

    def exists?
      @found
    end
  end

  class PersistentVolumeClaim < KubernetesResource
    TIMEOUT = 5.minutes

    def initialize(name, namespace, file)
      @name, @namespace, @file = name, namespace, file
    end

    def sync
      @status, st = run_kubectl("get", type, @name, "--output=jsonpath={.status.phase}")
      @found = st.success?
      log_status
    end

    def deploy_succeeded?
      @status == "Bound"
    end

    def deploy_failed?
      @status == "Lost"
    end

    def exists?
      @found
    end
  end

  class Ingress < KubernetesResource
    TIMEOUT = 30.seconds

    def initialize(name, namespace, file)
      @name, @namespace, @file = name, namespace, file
    end

    def sync
      _, st = run_kubectl("get", type, @name)
      @status = st.success? ? "Created" : "Unknown"
      @found = st.success?
      log_status
    end

    def deploy_succeeded?
      exists?
    end

    def deploy_failed?
      false
    end

    def exists?
      @found
    end

    def group_name
      "Ingresses"
    end
  end

  class Service < KubernetesResource
    TIMEOUT = 15.minutes

    def initialize(name, namespace, file)
      @name, @namespace, @file = name, namespace, file
    end

    def sync
      _, st = run_kubectl("get", type, @name)
      @found = st.success?
      if @found
        endpoints, st = run_kubectl("get", "endpoints", @name, "--output=jsonpath={.subsets[*].addresses[*].ip}")
        @num_endpoints = (st.success? ? endpoints.split.length : 0)
      else
        @num_endpoints = 0
      end
      @status = "#{@num_endpoints} endpoints"
      log_status
    end

    def deploy_succeeded?
      @num_endpoints > 0
    end

    def deploy_failed?
      false
    end

    def exists?
      @found
    end
  end

  class Pod < KubernetesResource
    TIMEOUT = 15.minutes
    SUSPICIOUS_CONTAINER_STATES = %w(ImagePullBackOff RunContainerError).freeze

    def initialize(name, namespace, file, parent: nil)
      @name, @namespace, @file, @parent = name, namespace, file, parent
      @bare = !@parent
    end

    def sync
      out, st = run_kubectl("get", type, @name, "-a", "--output=json")
      if @found = st.success?
        pod_data = JSON.parse(out)
        interpret_json_data(pod_data)
      else # reset
        @status = @phase = nil
        @ready = false
        @containers = []
      end
      display_logs if @bare && deploy_finished?
      log_status
    end

    def interpret_json_data(pod_data)
      @phase = (pod_data["metadata"]["deletionTimestamp"] ? "Terminating" : pod_data["status"]["phase"])
      @containers = pod_data["spec"]["containers"].map { |c| c["name"] }

      if @deploy_started && pod_data["status"]["containerStatuses"]
        pod_data["status"]["containerStatuses"].each do |status|
          waiting_state = status["state"]["waiting"] if status["state"]
          reason = waiting_state["reason"] if waiting_state
          next unless SUSPICIOUS_CONTAINER_STATES.include?(reason)
          KubernetesDeploy.logger.warn("#{id} has container in state #{reason} (#{waiting_state["message"]})")
        end
      end

      if @phase == "Failed"
        @status = "#{@phase} (Reason: #{pod_data["status"]["reason"]})"
      elsif @phase == "Terminating"
        @status = @phase
      else
        ready_condition = pod_data["status"]["conditions"].find { |condition| condition["type"] == "Ready" }
        @ready = ready_condition.present? && (ready_condition["status"] == "True")
        @status = "#{@phase} (Ready: #{@ready})"
      end
    end

    def deploy_succeeded?
      if @bare
        @phase == "Succeeded"
      else
        @phase == "Running" && @ready
      end
    end

    def deploy_failed?
      @phase == "Failed"
    end

    def exists?
      @bare ? @found : true
    end

    def group_name
      @bare ? "Bare pods" : @parent
    end

    private

    def display_logs
      return {} unless exists? && @containers.present? && !@already_displayed

      @containers.each do |container_name|
        out, st = run_kubectl("logs", @name, "--timestamps=true", "--since-time=#{@deploy_started.to_datetime.rfc3339}")
        next unless st.success? && out.present?

        KubernetesDeploy.logger.info "Logs from #{id} container #{container_name}:"
        STDOUT.puts "#{out}"
        @already_displayed = true
      end
    end
  end

  class Deployment < KubernetesResource
    TIMEOUT = 15.minutes

    def initialize(name, namespace, file)
      @name, @namespace, @file = name, namespace, file
    end

    def sync
      json_data, st = run_kubectl("get", type, @name, "--output=json")
      @found = st.success?
      @rollout_data = {}
      @status = nil
      @pods = []

      if @found
        @rollout_data = JSON.parse(json_data)["status"].slice("updatedReplicas", "replicas", "availableReplicas", "unavailableReplicas")
        @status, _ = run_kubectl("rollout", "status", type, @name, "--watch=false") if @deploy_started

        pod_list, st = run_kubectl("get", "pods", "-a", "-l", "name=#{name}", "--output=json")
        if st.success?
          pods_json = JSON.parse(pod_list)["items"]
          pods_json.each do |pod_json|
            pod_name = pod_json["metadata"]["name"]
            pod = Pod.new(pod_name, namespace, nil, parent: "#{@name.capitalize} deployment")
            pod.deploy_started = @deploy_started
            pod.interpret_json_data(pod_json)
            pod.log_status
            @pods << pod
          end
        end
      end

      log_status
    end

    def deploy_succeeded?
      return false unless @rollout_data.key?("availableReplicas")
      # TODO: this should look at the current replica set's pods too
      @rollout_data["availableReplicas"].to_i == @pods.length &&
      @rollout_data.values.uniq.length == 1 # num desired, current, up-to-date and available are equal
    end

    def deploy_failed?
      # TODO: this should look at the current replica set's pods only or it'll never be true for rolling updates
      @pods.present? && @pods.all?(&:deploy_failed?)
    end

    def deploy_timed_out?
      # TODO: this should look at the current replica set's pods only or it'll never be true for rolling updates
      super || @pods.present? && @pods.all?(&:deploy_timed_out?)
    end

    def exists?
      @found
    end

    def status_data
      super.merge(replicas: @rollout_data, num_pods: @pods.length)
    end
  end
end

deployment = KubernetesDeploy.new(
  namespace: ARGV[0],
  context: ARGV[1],
  environment: ENV['ENVIRONMENT'],
  current_sha: ENV['REVISION'],
  template_folder: ENV['K8S_TEMPLATE_FOLDER']
)
deployment.run
