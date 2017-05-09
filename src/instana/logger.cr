require "logger"

module Instana
  class XLogger < Logger
    LEVELS = [:agent, :agent_comm, :trace, :agent_response, :tracing]
    STAMP  = "Instana: "

    def initialize(*args)
      super(*args)
      if ENV["INSTANA_GEM_TEST"]?
        self.level = Logger::DEBUG
      elsif ENV["INSTANA_GEM_DEV"]?
        self.level = Logger::DEBUG
      else
        self.level = Logger::WARN
      end
    end

    # Sets the debug level for this logger.  The debug level is broken up into various
    # sub-levels as defined in LEVELS:
    #
    # :agent          - All agent related messages such as state & announcements
    # :agent_comm     - Output all payload comm sent between this Crystal gem and the host agent
    # :agent_response - Outputs messages related to handling requests received by the host agent
    # :trace          - Output all traces reported to the host agent
    # :tracing        - Output messages related to tracing components, spans and management
    #
    # To use:
    # ::Instana.logger.debug_level = [:agent_comm, :trace]
    #
    def error(msg)
      super(STAMP + msg)
    end

    def warn(msg)
      super(STAMP + msg)
    end

    def info(msg)
      super(STAMP + msg)
    end

    def debug(msg)
      super(STAMP + msg)
    end

    def unknown(msg)
      super(STAMP + msg)
    end
  end

  @@logger : XLogger?

  # Access the logger with:
  # ::Instana.logger...
  def self.logger
    @@logger ||= ::Instana::XLogger.new(STDOUT)
  end
end
