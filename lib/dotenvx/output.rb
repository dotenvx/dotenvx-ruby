module Dotenvx
  module Output
    def self.install(secrets)
      return if secrets.all?(&:empty?)

      stream = $stdout
      stream.singleton_class.prepend(self) unless stream.is_a?(self)
      stream.dotenvx_redact(secrets)
    end

    def dotenvx_redact(secrets)
      unless @dotenvx_output_filter
        @dotenvx_output_lock = Mutex.new
        @dotenvx_output_filter = Native::OutputRedactor.new
        at_exit { dotenvx_finish_output unless closed? }
      end
      @dotenvx_output_lock.synchronize { @dotenvx_output_filter.add(secrets) }
    end

    def write(*strings)
      return super unless @dotenvx_output_filter

      texts = strings.map(&:to_s)
      @dotenvx_output_lock.synchronize do
        texts.sum do |text|
          output = @dotenvx_output_filter.write(text)
          super(output.force_encoding(text.encoding)) unless output.empty?
          text.bytesize
        end
      end
    end

    private

    def dotenvx_finish_output
      @dotenvx_output_lock.synchronize do
        output = @dotenvx_output_filter.finish
        method(:write).super_method.call(output) unless output.empty?
        flush
      end
    end
  end
end
