require 'active_support/basic_object'

module ResqueDelay
  class DelayProxy < ActiveSupport::BasicObject
    def initialize(target, options)
      @target = target
      @options = options
    end

    def method_missing(method, *args)
      queue = @options[:to] || :default
      run_at = @options[:run_at]

      serializable_method = SerializableMethod.new(@target, method, args)

      if run_at
        # Yes the parameters should look backwards here.
        Resque.enqueue_at_with_queue(queue, run_at.to_time, DelayProxy, 
                                     serializable_method.to_yaml)
      else
        Resque.enqueue_to(queue, DelayProxy, serializable_method.to_yaml)
      end
    end

    # Called asynchrously by Resque
    def self.perform(args)
      YAML.load(args).perform
    end
  end

  module MessageSending
    def delay(options = {})
      DelayProxy.new(self, options)
    end
    alias __delay__ delay

    module ClassMethods
      def handle_asynchronously(method)
        aliased_method, punctuation = method.to_s.sub(/([?!=])$/, ''), $1
        with_method, without_method = "#{aliased_method}_with_delay#{punctuation}", "#{aliased_method}_without_delay#{punctuation}"
        define_method(with_method) do |*args|
          delay.__send__(without_method, *args)
        end
        alias_method_chain method, :delay
      end
    end
  end
end
