module Instana
  module Collectors
    class GCSnapshot
      JSON.mapping(
        bsgc: {type: UInt64, nilable: true},
        fb: {type: UInt64, nilable: true},
        hs: {type: UInt64, nilable: true},
        tb: {type: UInt64, nilable: true},
        ub: {type: UInt64, nilable: true}
      )

      def initialize
      end

      ##
      # collect
      #
      # To collect garbage collector related metrics.
      #
      def collect
        stats = ::GC.stats

        @bsgc = stats.bytes_since_gc
        @fb = stats.free_bytes
        @hs = stats.heap_size
        @tb = stats.total_bytes
        @ub = stats.unmapped_bytes
      rescue e
        ::Instana.logger.error "collect:gc.cr #{e.message}"
        ::Instana.logger.debug e.backtrace.join("\r\n")
      end
    end
  end
end
