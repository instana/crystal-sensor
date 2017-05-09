require "./version"
require "./logger"
require "./util"
require "./helpers"

module Instana
  property :collector
  property :tracer
  property :processor
  property :config
  property :pid

  ##
  # setup
  #
  # Setup the Instana language agent to an informal "ready
  # to run" state.
  #
  def self.setup
    @@agent = ::Instana::Agent.new
    @@tracer = ::Instana::Tracer.new
    @@processor = ::Instana::Processor.new
  end

  # Indicates whether we are running in a development environment.
  #
  # @return Bool
  #
  def self.debug?
    ENV["INSTANA_GEM_DEV"]?
  end

  # Indicates whether we are running in the test environment.
  #
  # @return Bool
  #
  def self.test?
    ENV["INSTANA_GEM_TEST"]?
  end
end

::Instana.logger.unknown "Stan is on the scene.  Starting Instana instrumentation."
