require "logger"

module Instana
  class XLogger < Logger
    LEVELS = [:agent, :agent_comm, :trace, :agent_response, :tracing]
    STAMP  = "Instana: "

    def initialize(*args)
      super(*args)
      if ENV["INSTANA_SHARD_TEST"]?
        self.level = Logger::DEBUG
      elsif ENV["INSTANA_DEBUG"]?
        self.level = Logger::DEBUG
      else
        self.level = Logger::WARN
      end
    end

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
