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

        after_create  { |record| record.send(:__associator__).persist }
        after_update  { |record| record.send(:__associator__).sync }
        after_destroy { |record| record.send(:__associator__).destroy }

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
        pk_method  = @instance.class.primary_key
        associated.send(:"#{key_method}=", @instance.send(pk_method))
        associated.persist!
      end
    end

    def sync
      @names.each do |name, key_method|
        associated = @instance.send(name)
        associated.persist!
      end
    end

    def destroy
      @names.each { |name, key_method| @instance.send(name).destroy }
    end
  end
end
