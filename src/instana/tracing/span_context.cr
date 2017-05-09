module Instana
  class SpanContext
    property :trace_id
    property :span_id
    property :baggage

    # Create a new SpanContext
    #
    # @param tid [Integer] the trace ID
    # @param sid [Integer] the span ID
    # @param baggage [Hash] baggage applied to this trace
    #
    def initialize(tid, sid, baggage = {} of Symbol => String)
      @trace_id = tid
      @span_id = sid
      if baggage.is_a?(Hash)
        @baggage = baggage
      end
    end

    def trace_id_header
      ::Instana::Util.id_to_header(@trace_id)
    end

    def span_id_header
      ::Instana::Util.id_to_header(@span_id)
    end

    def to_hash
      {:trace_id => @trace_id, :span_id => @span_id}
    end
  end
end
