require 'access_control/registry'

module AccessControl
  describe Registry do
    before do
      Registry.store('p1') do |permission|
        permission.ac_methods << ['Foo', :bar]
      end
      Registry.store('p2') do |permission|
        permission.ac_methods << ['Qux', :bar]
      end
    end

    describe "#permission_names_for" do
      it "returns permissions by class name and method" do
        Registry.permission_names_for('Foo', :bar).should include('p1')
        Registry.permission_names_for('Foo', :bar).should_not include('p2')
      end

      it "works even if method is passed as a string" do
        Registry.permission_names_for('Foo', 'bar').should include('p1')
        Registry.permission_names_for('Foo', 'bar').should_not include('p2')
      end
    end

    after do
      Registry.clear_registry
    end
  end
end
