require 'access_control/registry'

module AccessControl
  describe Registry do
    def permission_names
      @permission_names ||= Enumerator.new do |yielder|
        id = 0
        loop do
          yielder.yield("Permission #{id}")
          id += 1
        end
      end
    end

    def permission_assigned_to(class_name, method_name)
      permission_name = permission_names.next
      Registry.store(permission_name) do |permission|
        permission.ac_methods << [class_name, method_name]
      end
    end

    let!(:p1) { permission_assigned_to('Foo', :bar) }
    let!(:p2) { permission_assigned_to('Qux', :bar) }

    describe "#permissions_for" do
      it "returns permissions by class name and method" do
        permissions = Registry.permissions_for('Foo', :bar)
        permissions.should include p1
        permissions.should_not include p2
      end

      it "works even if method is passed as a string" do
        permissions = Registry.permissions_for('Foo', 'bar')
        permissions.should include p1
        permissions.should_not include p2
      end
    end

    after do
      Registry.clear
    end
  end
end
