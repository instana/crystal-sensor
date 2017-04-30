module Instana
  module Util
    # An agnostic approach to method aliasing.
    #
    # @param klass [Object] The class or module that holds the method to be alias'd.
    # @param method [Symbol] The name of the method to be aliased.
    #
    def self.method_alias(klass, method)
      if klass.method_defined?(method.to_sym) ||
         klass.private_method_defined?(method.to_sym)
        w = "#{method}_with_instana"
        wo = "#{method}_without_instana"

        klass.class_eval do
          alias_method wo, method.to_s
          alias_method method.to_s, w
        end
      else
        ::Instana.logger.debug "No such method (#{method}) to alias on #{klass}"
      end
    end

    # Calls on target_class to 'extend' cls
    #
    # @param target_cls [Object] the class/module to do the 'extending'
    # @param cls [Object] the class/module to be 'extended'
    #
    def self.send_extend(target_cls, cls)
      target_cls.send(:extend, cls) if defined?(target_cls)
    end

    # Calls on <target_cls> to include <cls> into itself.
    #
    # @param target_cls [Object] the class/module to do the 'including'
    # @param cls [Object] the class/module to be 'included'
    #
    def self.send_include(target_cls, cls)
      target_cls.send(:include, cls) if defined?(target_cls)
    end

    # Debugging helper method
    #
    def self.pry!
      # FIXME: Useful in Crystal?
    end

    # Retrieves and returns the source code for any crystal
    # files requested by the UI via the host agent
    #
    # @param file [String] The fully qualified path to a file
    #
    def self.get_cr_source(file)
      if (file =~ /.rb$/).nil?
        {:error => "Only Crystal source files are allowed. (*.rb)"}
      else
        {:data => File.read(file)}
      end
    rescue e
      return {:error => e.inspect}
    end

    # Method to collect up process info for snapshots.  This
    # is generally used once per process.
    #
    def self.take_snapshot
      data = {:sensorVersion   => ::Instana::VERSION,
              :crystal_version => crystal_version}

      # Report Bundle
      # FIXME Convert to shard list
      # if defined?(::Gem) && Gem.respond_to?(:loaded_specs)
      #   data[:versions] = {String => String}
      #
      #   Gem.loaded_specs.each do |k, v|
      #     data[:versions][k] = v.version.to_s
      #   end
      # end

      data
    rescue e
      ::Instana.logger.error "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
      ::Instana.logger.debug e.backtrace.join("\r\n")
      return data
    end

    # Used in class initialization and after a fork, this method
    # collects up process information
    #
    def self.collect_process_info
      process = {String, String}
      cmdline_file = "/proc/#{Process.pid}/cmdline"

      # If there is a /proc filesystem, we read this manually so
      # we can split on embedded null bytes.  Otherwise (e.g. OSX, Windows)
      # use ProcTable.
      if File.exist?(cmdline_file)
        # FIXME: Null bye results in unterminated call?
        # cmdline = IO.read(cmdline_file).split(?\x00)
      else
        cmdline = ProcTable.ps(Process.pid).cmdline.split(' ')
      end

      if CRYSTAL_PLATFORM =~ /darwin/i
        cmdline.delete_if { |e| e.include?('=') }
        process[:name] = cmdline.join(' ')
      else
        process[:name] = cmdline.shift
        process[:arguments] = cmdline
      end

      process[:pid] = Process.pid
      # This is usually Process.pid but in the case of containers, the host agent
      # will return to us the true host pid in which we use to report data.
      process[:report_pid] = nil
      process
    end

    # Get the current time in milliseconds
    #
    # @return [Integer] the current time in milliseconds
    #
    def self.ts_now
      (Time.now.to_f * 1000).floor
    end

    # Convert a Time value to milliseconds
    #
    # @param time [Time]
    #
    def self.time_to_ms(time = Time.now)
      (time.to_f * 1000).floor
    end

    # Generate a random 64bit ID
    #
    # @return [Integer] a random 64bit integer
    #
    def self.generate_id
      # Max value is 9223372036854775807 (signed long in Java)
      rand(-2**63..2**63 - 1)
    end

    # Convert an ID to a value appropriate to pass in a header.
    #
    # @param id [Integer] the id to be converted
    #
    # @return [String]
    #
    def self.id_to_header(id)
      unless id.is_a?(Integer) || id.is_a?(String)
        Instana.logger.debug "id_to_header received a #{id.class}: returning empty string"
        return String.new
      end
      [id.to_i].pack("q>").unpack("H*")[0]
    rescue e
      Instana.logger.error "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
      Instana.logger.debug e.backtrace.join("\r\n")
    end

    # Convert a received header value into a valid ID
    #
    # @param header_id [String] the header value to be converted
    #
    # @return [Integer]
    #
    def self.header_to_id(header_id)
      if !header_id.is_a?(String)
        Instana.logger.debug "header_to_id received a #{header_id.class}: returning 0"
        return 0
      end
      [header_id].pack("H*").unpack("q>")[0]
    rescue e
      Instana.logger.error "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
      Instana.logger.debug e.backtrace.join("\r\n")
    end
  end
end
