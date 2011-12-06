require 'access_control/persistency_protector'

module AccessControl
  describe PersistencyProtector do

    let(:manager)  { mock('manager', :can! => nil) }
    let(:model)    { Class.new }
    let(:instance) { model.new }

    before do
      AccessControl.stub(:manager).and_return(manager)
    end

    describe "#verify!" do
      let(:permissions) { Set.new }
      before do
        model.stub(:permissions_required_to_do_foo).and_return(permissions)
      end

      def verify
        PersistencyProtector.new(instance).verify!('do_foo')
      end

      it "gets the permission according to the action provided" do
        model.should_receive(:permissions_required_to_do_foo).
          and_return(Set.new)
        verify
      end

      context "when there are permissions" do
        let(:permissions) { Set.new(['permission']) }
        it "passes the permissions to the manager for verification" do
          manager.should_receive(:can!).with(permissions, instance)
          verify
        end
      end

      context "when there are no permissions" do
        let(:permissions) { Set.new }
        it "just skip calling the manager" do
          manager.should_not_receive(:can!)
          verify
        end
      end
    end
  end
end
