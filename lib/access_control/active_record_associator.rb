module AccessControl
  class ActiveRecordAssociator
    module Boilerplate
      private
      def __associator__
        @__associator__ ||= ActiveRecordAssociator.new(self)
      end
    end

    def self.setup_association(name, base, &block)
      base.class_eval do
        include Boilerplate

        just_after_create  { __associator__.persist }
        just_after_destroy { __associator__.destroy }

        define_method(name, &block)
      end

      add_associated_name(base, name)
    end

    def self.add_associated_name(base, name)
      associated_names_of(base).add(name)
    end

    def self.associated_names_of(base)
      base.instance_eval { @__associated_names__ ||= Set.new }
    end

    def initialize(instance)
      @instance = instance
      @names    = ActiveRecordAssociator.associated_names_of(instance.class)
    end

    def persist
      @names.each { |name| @instance.send(name).persist }
    end

    def destroy
      @names.each { |name| @instance.send(name).destroy }
    end
  end
end
