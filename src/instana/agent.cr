require "json"
require "http/client"
require "socket"
require "uri"
require "quartz"

module Instana
  @@agent : Agent?

  def self.agent
    @@agent ||= Agent.new
  end

  class Agent
    property :state
    property :agent_uuid
    property :process

    LOCALHOST      = "127.0.0.1"
    MIME_JSON      = "application/json"
    DISCOVERY_PATH = "com.instana.plugin.crystal.discovery"

    @default_gateway : String | Nil
    @discovered = {} of Symbol => String | Int32
    @@agent_uuid : String | Nil

    def initialize
      # Supported two states (unannounced & announced)
      @state = :unannounced

      # Timestamp of the last successful response from
      # entity data reporting.
      @entity_last_seen = Time.now

      # Used to track the last time the collect timer was run.
      @last_collect_run = Time.now

      # Nil by default
      # @announce_timer = nil
      # @collect_timer = nil

      # Detect platform flags
      @has_procfs = File.directory?("/proc")

      # In case we're running in Docker, have the default gateway available
      # to check in case we"re running in bridged network mode
      if @has_procfs
        @default_gateway = "127.0.0.1"
        # FIXME
        # @default_gateway = `/sbin/ip route | awk "/default/ { print $3 }"`.chomp
      else
        # Nil by default
        # @default_gateway = nil
      end

      # The agent UUID returned from the host agent
      # Nil by default
      # @@agent_uuid = nil

      # Collect process information
      @process = {} of Symbol => String | Int32 | Array(String) | Nil
      @process = ::Instana::Util.collect_process_info
    end

    # Used post fork to re-initialize state and restart communications with
    # the host agent.
    #
    def after_fork
      ::Instana.logger.debug "after_fork hook called. Falling back to unannounced state and spawning a new background agent thread."

      # Reseed the random number generator for this
      # new thread.
      srand

      # Re-collect process information post fork
      @process = ::Instana::Util.collect_process_info

      transition_to(:unannounced)
      setup
      spawn_background_thread
    end

    # Spawns the background thread and calls start.  This method is separated
    # out for those who wish to control which thread the background agent will
    # run in.
    #
    # This method can be overridden with the following:
    #
    # module Instana
    #   class Agent
    #     def spawn_background_thread
    #       # start thread
    #       start
    #     end
    #   end
    # end
    #
    def spawn_background_thread
      # The thread calling fork is the only thread in the created child process.
      # fork doesn’t copy other threads.
      # Restart our background thread
      Thread.new do
        start
      end
    end

    # Sets up periodic timers and starts the agent in a background thread.
    #
    def setup
      # The announce timer
      # We attempt to announce this crystal sensor to the host agent.
      # In case of failure, we try again in 30 seconds.
      @announce_timer = Quartz::PeriodicTimer.new(30) do
        if host_agent_ready? && announce_sensor
          ::Instana.logger.warn "Host agent available. We're in business."
          transition_to(:announced)
        end
        true
      end

      # The collect timer
      # If we are in announced state, send metric data (only delta reporting)
      # every 1 seconds.
      @collect_timer = Quartz::PeriodicTimer.new(1) do
        # Make sure that this block doesn't get called more often than the interval.  This can
        # happen on high CPU load and a back up of timer runs.  If we are called before `interval`
        # then we just skip.
        unless (Time.now - @last_collect_run) < Time::Span.new(0, 0, 0, 1)
          @last_collect_run = Time.now
          if @state == :announced
            if !::Instana.metrics.collect_and_report
              # If report has been failing for more than 1 minute,
              # fall back to unannounced state
              if (Time.now - @entity_last_seen) > Time::Span.new(0, 0, 1, 0)
                ::Instana.logger.warn "Host agent offline for >1 min.  Going to sit in a corner..."
                transition_to(:unannounced)
              end
            end
            ::Instana.processor.send
          end
          true
        end
      end
    end

    # Starts the timer loop for the timers that were initialized
    # in the setup method.  This is blocking and should only be
    # called from an already initialized background thread.
    #
    def start
      ::Instana.logger.warn "Host agent not available.  Will retry periodically." unless host_agent_ready?
      loop do
        if @state == :unannounced
          # @collect_timer.pause
          # @announce_timer.resume
        else
          # @announce_timer.pause
          # @collect_timer.resume
        end
        sleep
      end
    ensure
      if @state == :announced
        # Pause the timers so they don"t fire while we are
        # reporting traces
        # FIXME
        # @collect_timer.cancel
        # @announce_timer.cancel

        ::Instana.logger.debug "Agent exiting. Reporting final #{::Instana.processor.queue_count} trace(s)."
        ::Instana.processor.send
      end
    end

    # Collect process ID, name and arguments to notify
    # the host agent.
    #
    def announce_sensor
      if @discovered.empty?
        ::Instana.logger.debug("announce_sensor called but discovery hasn't run yet!")
        return false
      end

      announce_payload = {
        :pid  => pid_namespace? ? get_real_pid : Process.pid,
        :name => @process[:name],
        :args => @process[:arguments],
      }

      # FIXME
      # if @has_procfs && !::Instana.test?
      #   # We create an open socket to the host agent in case we are running in a container
      #   # and the real pid needs to be detected.
      #   socket = TCPSocket.new(@discovered[:agent_host], @discovered[:agent_port])
      #   announce_payload[:fd] = socket.fileno
      #   announce_payload[:inode] = File.readlink("/proc/#{Process.pid}/fd/#{socket.fileno}")
      # end

      uri = URI.parse("http://#{@discovered[:agent_host]}:#{@discovered[:agent_port]}/#{DISCOVERY_PATH}")
      body = announce_payload.to_json

      ::Instana.logger.debug "Announce: http://#{@discovered[:agent_host]}:#{@discovered[:agent_port]}/#{DISCOVERY_PATH} - payload: #{body}"

      response = make_host_agent_request(uri, body, :post)

      if response && (response.status_code == 200)
        data = JSON.parse(response.body)
        @process[:report_pid] = data["pid"].to_s
        @@agent_uuid = data["agentUuid"].to_s
        true
      else
        false
      end
    rescue e
      Instana.logger.error "announce_sensor:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
      Instana.logger.debug e.backtrace.join("\r\n")
      return false
    ensure
      # FIXME
      # socket.close if socket
    end

    # Method to report metrics data to the host agent.
    #
    # @param paylod [Hash] The collection of metrics to report.
    #
    # @return [Bool] true on success, false otherwise
    #
    def report_metrics(payload)
      if @discovered.empty?
        ::Instana.logger.debug("report_metrics called but discovery hasn't run yet!")
        return false
      end

      path = "com.instana.plugin.crystal.#{@process[:report_pid]}"
      uri = URI.parse("http://#{@discovered[:agent_host]}:#{@discovered[:agent_port]}/#{path}")

      response = make_host_agent_request(uri, payload.to_json, :post)

      if response
        if response.body && response.body.size > 2
          # The host agent returned something indicating that is has a request for us that we
          # need to process.
          handle_response(response.body)
        end

        if response.status_code == 200
          @entity_last_seen = Time.now
          return true
        end
      end
      false
    rescue e
      Instana.logger.error "report_metrics:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
      Instana.logger.debug e.backtrace.join("\r\n")
    end

    # When a request is received by the host agent, it is sent here
    # from processing and response.
    #
    # @param json_string [String] the request from the host agent
    #
    def handle_response(json_string)
      return
      # FIXME
      # their_request = JSON.parse(json_string).first
      #
      # if their_request["action"]?
      #   if their_request["action"] == "crystal.source"
      #     payload = ::Instana::Util.get_cr_source(their_request["args"]["file"])
      #   else
      #     payload = {:error => "Unrecognized action: #{their_request["action"]}. An newer Instana gem may be required for this. Current version: #{::Instana::VERSION}"}
      #   end
      # else
      #   payload = {:error => "Instana Crystal: No action specified in request."}
      # end
      #
      # path = "com.instana.plugin.crystal/response.#{@process[:report_pid]}?messageId=#{URI.encode(their_request["messageId"])}"
      # uri = URI.parse("http://#{@discovered[:agent_host]}:#{@discovered[:agent_port]}/#{path}")
      # ::Instana.logger.debug_response "Responding to agent: #{payload.inspect}"
      # make_host_agent_request(uri, payload.to_json, :post)
    end

    # Accept and report spans to the host agent.
    #
    # @param traces [Array] An array of [Span]
    # @return [Bool]
    #
    def report_spans(spans)
      return unless @state == :announced

      if @discovered.empty?
        ::Instana.logger.debug("report_spans called but discovery hasn't run yet!")
        return false
      end

      path = "com.instana.plugin.crystal/traces.#{@process[:report_pid]}"
      uri = URI.parse("http://#{@discovered[:agent_host]}:#{@discovered[:agent_port]}/#{path}")
      response = make_host_agent_request(uri, spans.to_json, :post)

      if response
        last_trace_response = response.status_code

        if [200, 204].includes?(last_trace_response)
          return true
        end
      end
      false
    rescue e
      Instana.logger.debug "report_spans:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
      Instana.logger.debug e.backtrace.join("\r\n")
    end

    # Check that the host agent is available and can be contacted.  This will
    # first check localhost and if not, then attempt on the default gateway
    # for docker in bridged mode.
    #
    def host_agent_ready?
      run_discovery unless @discovered[:done]
      if @discovered
        # Try default location or manually configured (if so)
        uri = URI.parse("http://#{@discovered[:agent_host]}:#{@discovered[:agent_port]}/")

        response = make_host_agent_request(uri, nil, :get)

        if response && (response.status_code == 200)
          return true
        end
      end
      false
    rescue e
      Instana.logger.error "host_agent_ready?:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
      Instana.logger.debug e.backtrace.join("\r\n") unless ::Instana.test?
      return false
    end

    # Runs a discovery process to determine where we can contact the host agent.  This is usually just
    # localhost but in docker can be found on the default gateway.  This also allows for manual
    # configuration via ::Instana.config[:agent_host/port].
    #
    # @return [Hash] a hash with :agent_host, :agent_port values or empty hash
    #
    def run_discovery
      discovered = {
        :agent_host => ::Instana.config[:agent_host],
        :agent_port => ::Instana.config[:agent_port],
      }

      ::Instana.logger.debug "run_discovery: Running agent discovery..."

      # Try default location or manually configured (if so)
      uri = URI.parse("http://#{::Instana.config[:agent_host]}:#{::Instana.config[:agent_port]}/")

      ::Instana.logger.debug "run_discovery: Trying #{::Instana.config[:agent_host]}:#{::Instana.config[:agent_port]}"

      response = make_host_agent_request(uri, nil, :get)

      if response && (response.status_code == 200)
        ::Instana.logger.debug "run_discovery: Found #{discovered[:agent_host]}:#{discovered[:agent_port]}"
        return discovered
      end

      return nil unless @has_procfs

      # We are potentially running on Docker in bridged networking mode.
      # Attempt to contact default gateway
      uri = URI.parse("http://#{@default_gateway}:#{::Instana.config[:agent_port]}/")

      ::Instana.logger.debug "run_discovery: Trying default gateway #{@default_gateway}:#{::Instana.config[:agent_port]}"

      response = make_host_agent_request(uri, nil, :get)

      if response && (response.status_code == 200)
        discovered[:agent_host] = @default_gateway
        discovered[:agent_port] = ::Instana.config[:agent_port]
        ::Instana.logger.debug "run_discovery: Found #{discovered[:agent_host]}:#{discovered[:agent_port]}"
        return discovered
      end
      nil
    end

    # Returns the PID that we are reporting to
    #
    def report_pid
      @process[:report_pid]
    end

    # Indicates if the agent is ready to send metrics
    # and/or data.
    #
    def ready?
      # In test, we"re always ready :-)
      return true if ENV["INSTANA_GEM_TEST"]

      if forked?
        ::Instana.logger.debug "Instana: detected fork.  Calling after_fork"
        after_fork
      end

      @state == :announced
    rescue e
      Instana.logger.debug "ready?:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
      Instana.logger.debug e.backtrace.join("\r\n") unless ::Instana.test?
      return false
    end

    # Handles any/all steps required in the transtion
    # between states.
    #
    # @param state [Symbol] Can be 1 of 2 possible states:
    #   `:announced`, `:unannounced`
    #
    protected def transition_to(state)
      ::Instana.logger.debug("Transitioning to #{state}")
      case state
      when :announced
        # announce successful; set state
        @state = :announced

        # Reset the entity timer
        @entity_last_seen = Time.now
      when :unannounced
        @state = :unannounced
      else
        ::Instana.logger.warn "Uknown agent state: #{state}"
      end
      ::Instana.metrics.reset_timer!
      true
    end

    # Centralization of the net/http communications
    # with the host agent. Pass in a prepared <req>
    # of type Net::HTTP::Get|Put|Head
    #
    # @param req [Net::HTTP::Req] A prepared Net::HTTP request object of the type
    #  you wish to make (Get, Put, Post etc.)
    #
    protected def make_host_agent_request(uri, body, method)
      # FIXME: open timeout, read timeout? dns timeout?
      h = HTTP::Headers{"Accept" => MIME_JSON, "Content-Type" => MIME_JSON}
      response = HTTP::Client.exec(method.to_s, url: uri, headers: h, body: body)

      ::Instana.logger.debug "#{method}->#{uri} body:(#{body}) Response:#{response} body:(#{response.body})"
      response
      # FIXME
      # rescue e : Errno::ECONNREFUSED
      #   return nil


    rescue e
      Instana.logger.error "make_host_agent_request:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
      Instana.logger.debug e.backtrace.join("\r\n") unless ::Instana.test?
      return nil
    end

    # Indicates whether we are running in a pid namespace (such as
    # Docker).
    #
    protected def pid_namespace?
      return false unless @has_procfs
      Process.pid != get_real_pid
    end

    # Attempts to determine the true process ID by querying the
    # /proc/<pid>/sched file.  This works on linux currently.
    #
    protected def get_real_pid
      raise Exception.new("Unsupported platform: get_real_pid") unless @has_procfs

      sched_file = "/proc/#{Process.pid}/sched"
      pid = Process.pid

      if File.exists?(sched_file)
        v = File.read_lines(sched_file)
        pid = v[0].match(/\d+/).to_s.to_i
      end
      pid
    end

    # Determine whether the pid has changed since Agent start.
    #
    # @ return [Bool] true or false to indicate if forked
    #
    protected def forked?
      @process[:pid] != Process.pid
    end
  end
end
