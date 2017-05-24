require "./base"
require "./config"
require "./agent"
require "./metrics"
require "./tracer"
require "./tracing/processor"
require "./instrumentation"

::Instana.setup
::Instana.agent.setup

# Require supported OpenTracing interfaces
require "../opentracing"

# The Instana agent is now setup.  The only remaining
# task for a complete boot is to call
# `Instana.agent.start` in the thread of your choice.
# This can be in a simple `Thread.new` block or
# any other thread system you may use (e.g. actor
# threads).
#
# Note that `start` should only be called once per process.
#
# Thread.new do
#   ::Instana.agent.start
# end
