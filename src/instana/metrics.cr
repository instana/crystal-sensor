require "./collectors/gc"

module Instana
  @@metrics : ::Instana::Metrics?

  alias MetricsPayload = Hash(Symbol, Int32)

  class Snapshot
    def initialize
      @gc = ::Instana::Collectors::GCSnapshot.new
    end

    def clear!
      @name = nil
      @pid = nil
      @args = nil
      @sensorVersion = nil
      @crystal_version = nil
    end

    JSON.mapping(
      name: {type: String, nilable: true},
      pid: {type: Int32, nilable: true},
      args: {type: Array(String), nilable: true},
      sensorVersion: {type: String, nilable: true},
      crystal_version: {type: String, nilable: true},
      gc: {type: ::Instana::Collectors::GCSnapshot, nilable: false}
    )
  end

  def self.metrics
    @@metrics ||= ::Instana::Metrics.new
  end

  class Metrics
    property :last_report_log

    def initialize
      # Used to send periodic snapshot data every 10 mins
      @interval = 601
      @jsonparser = JSON::PullParser.new "{}"
      @snapshot = ::Instana::Snapshot.new # @jsonparser
    end

    def reset!
      # Reset to 10minutes and 1 second
      # so that we send a snapshot and reset to zero
      @interval = 601
    end

    ##
    # collect_and_report
    #
    # Run through each collector, let them collect up
    # data and then report what we have via the agent
    #
    # @return Bool true on success
    #
    def collect_and_report
      @snapshot.gc.collect

      # Every 5 minutes, send snapshot data as well
      if @interval > 600
        # Add in process related that could have changed since
        # snapshot was taken.
        @snapshot.pid = ::Instana.agent.report_pid
        @snapshot.name = ::Instana.agent.process.name
        @snapshot.args = ::Instana.agent.process.arguments
        @snapshot.sensorVersion = ::Instana::VERSION
        @snapshot.crystal_version = Crystal::VERSION
      end

      if ENV["INSTANA_SHARD_TEST"]?
        true
      else
        # Report all the collected goodies
        success = ::Instana.agent.report_metrics(@snapshot)
        # ::Instana.logger.debug "reported #{success} #{@interval}"
        if success && @interval > 600
          # Success - clear snapshot data and reset interval
          # ::Instana.logger.debug "clearing and resetting interval"
          @snapshot.clear!
          @interval = 0
        end
        @interval = @interval + 1
        success
      end
    end

    # Take two hashes and enforce delta reporting.
    # We only report when values change (instead of reporting all of
    # the time).  This is a recursive method.
    #
    # @param [Hash] the payload have delta reporting applied to
    # @param [Hash] a hash of the last values reported
    #
    # @return [Hash] the candidate hash with delta reporting applied
    #
    def enforce_deltas(candidate, last)
      # FIXME
      #   candidate.each do |k, v|
      #     if v.is_a?(Hash)
      #       last[k] ||= {} of Symbol => Int32
      #       candidate[k] = enforce_deltas(candidate[k], last[k])
      #       candidate.delete(k) if candidate[k].empty?
      #     else
      #       if last[k] == v
      #         candidate.delete(k)
      #       else
      #         last[k] = candidate[k]
      #       end
      #     end
      #   end
      #   candidate
    end
  end
end
