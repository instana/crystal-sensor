module OpenTracing
  # Text format for #inject and #extract
  FORMAT_TEXT_MAP = 1

  # Binary format for #inject and #extract
  FORMAT_BINARY = 2

  # Specific format to handle how Rack changes environment variables.
  FORMAT_RACK = 3

  property :global_tracer

  def self.method_missing(method_name, *args, &block)
    @global_tracer.send(method_name, *args, &block)
  end
end
