module AccessControl
  class ActiveRecordAssociator
    module Boilerplate
      private
      def __associator__
        @__associator__ ||= ActiveRecordAssociator.new(self)
      end
    end

    def self.setup_association(name, key_method, base, &block)
      base.class_eval do
        include Boilerplate

        just_after_create  { __associator__.persist }
        just_after_destroy { __associator__.destroy }

        define_method(name, &block)
      end

      add_associated_name(base, name, key_method)
    end

    def self.add_associated_name(base, name, key_method)
      associated_names_of(base).add([name, key_method])
    end

    def self.associated_names_of(base)
      base.instance_eval { @__associated_names__ ||= Set.new }
    end

    def initialize(instance)
      @instance = instance
      @names    = ActiveRecordAssociator.associated_names_of(instance.class)
    end

    def persist
      @names.each do |name, key_method|
        associated = @instance.send(name)
        associated.send(:"#{key_method}=", @instance.id)
        associated.persist!
      end
    end

    def destroy
      @names.each { |name, key_method| @instance.send(name).destroy }
    end
  end
end
