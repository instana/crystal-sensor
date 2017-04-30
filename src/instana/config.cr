module Instana
  @@config = ::Instana::Config.new

  class Config
    def initialize
      @@config = {
        :agent_host => "127.0.0.1",
        :agent_port => 42699,

        # Global on/off switch for prebuilt environments
        # Setting this to false will disable this gem
        # from doing anything.
        :enabled => true,

        # Enable/disable metrics globally or individually (default: all enabled)
        :metrics => {:enabled => true,
          :gc => {:enabled => true},
          :memory => {:enabled => true},
          :thread => {:enabled => true},
        },
        # Enable/disable tracing (default: enabled)
        :tracing   => {:enabled => true},
        :collector => {:enabled => true, :interval => 1},

        # EUM Related
        :eum_api_key => nil,
        :eum_baggage => {Symbol, String},

        # Instrumentation
        :action_controller => {:enabled => true},
        :action_view       => {:enabled => true},
        :active_record     => {:enabled => true},
        :dalli             => {:enabled => true},
        :excon             => {:enabled => true},
        :nethttp           => {:enabled => true},
        :rest_client       => {:enabled => true},
      }

      # FIXME
      # if ENV["INSTANA_GEM_DEV"]?
      #   @config[:collector][:interval] = 3
      # end
    end

    def [](key)
      @config[key.to_sym]
    end

    def []=(key, value)
      @config[key.to_sym] = value

      if key == :enabled
        # Configuring global enable/disable flag, then set the
        # appropriate children flags.
        @config[:metrics][:enabled] = value
        @config[:tracing][:enabled] = value
      end
    end
  end
end
