module ResqueDelay
  class SerializableMethod 
    attr_reader :wrapped_object, :method, :wrapped_args

    def initialize(object, method, args)
      raise NoMethodError, "undefined method `#{method}' for #{object.inspect}" unless object && object.respond_to?(method)
      @wrapped_object = wrap(object)
      @method = method
      @wrapped_args   = args.map{|a| wrap(a)}
    end

    def perform
      # We cannot do anything about objects which were deleted in the meantime
      return true unless object

      object.send(method, *args)
    end

    def object
      wrapped_object.thunk
    end

    def args
      wrapped_args.map(&:thunk)
    end

    private
    def wrap(object)
      [DBWrapper, ClassWrapper, Wrapper].detect{|w| w.can_wrap?(object)}.new(object)
    end

    class Wrapper 
      def self.can_wrap?(object)
        true
      end

      def initialize(object)
        @wrapped = object
      end

      def thunk
        @wrapped
      end
    end

    class ClassWrapper < Wrapper

      def self.can_wrap?(object)
        object.kind_of?(Class)
      end

      def initialize(object)
        super(object)
        @wrapped_class = object.to_s
      end

      def thunk
        @wrapped ||= @wrapped_class.constantize
      end

      def to_yaml_properties
        ["@wrapped_class"]
      end
    end

    class DBWrapper < Wrapper

      def self.can_wrap?(object)
        object.class <= ActiveRecord::Base || object.class <= Mongoid::Document
      end

      def initialize(object)
        super(object)
        @wrapped_class = object.class.to_s
        @wrapped_id = object.id
      end

      def thunk
        @wrapped ||= begin
          @wrapped_class.constantize.find(@wrapped_id)
        rescue => e
          # If loads fails, nothing we can do...
          Rails.logger.info "ResqueDelay can't load #{@wrapped_class} :: #{@wrapped_id}" if Rails
          nil
        end
      end

      def to_yaml_properties
        ["@wrapped_class", "@wrapped_id"]
      end
    end
  end
end
