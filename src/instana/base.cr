require "./version"
require "./logger"
require "./util"
require "./helpers"

module Instana
  property :agent
  property :collector
  property :tracer
  property :processor
  property :config
  property :logger
  property :pid

  ##
  # setup
  #
  # Setup the Instana language agent to an informal "ready
  # to run" state.
  #
  def self.setup
    @@agent  = ::Instana::Agent.new
    @@tracer = ::Instana::Tracer.new
    @@processor = ::Instana::Processor.new
    @@collector = ::Instana::Collector.new
  end

  # Indicates whether we are running in a development environment.
  #
  # @return Boolean
  #
  def self.debug?
    ENV.key?("INSTANA_GEM_DEV")
  end

  # Indicates whether we are running in the test environment.
  #
  # @return Boolean
  #
  def self.test?
    ENV.key?("INSTANA_GEM_TEST")
  end
end

# Setup the logger as early as possible
::Instana.logger = ::Instana::XLogger.new(STDOUT)
::Instana.logger.unknown "Stan is on the scene.  Starting Instana instrumentation."
