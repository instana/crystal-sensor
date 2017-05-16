module Instana
  @@config = ::Instana::Config.new

  def self.config
    @@config
  end

  class Config
    # Global on/off switch for prebuilt environments
    # Setting this to false will disable this shard
    # from doing anything.
    property enabled = true
    property metrics_enabled = true
    property tracing_enabled = true

    property agent_host = "127.0.0.1"
    property agent_port = 42699

    # EUM Related
    property eum_api_key = ""
    property eum_baggage = {} of Symbol => String

    def initialize
      # FIXME
      # if ENV["INSTANA_SHARD_DEV"]?
      #   @config[:collector][:interval] = 3
      # end
    end
  end
end
