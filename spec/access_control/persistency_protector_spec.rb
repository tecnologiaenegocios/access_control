require 'spec_helper'
require 'access_control/persistency_protector'

module AccessControl
  describe PersistencyProtector do

    let(:manager)      { mock('manager') }
    let(:model)        { Class.new }
    let(:parent_model) { Class.new }
    let(:instance)     { model.new }

    before do
      AccessControl.stub(:manager).and_return(manager)
    end

    describe "controlling parents" do
      let(:permissions) { Set['permission'] }
      [1,2,3,4].each { |n| let(:"parent#{n}") { parent_model.new } }

      before do
        Parenter.stub(:parents_of).with(instance).and_return(initial_parents)
        PersistencyProtector.track_parents(instance)
      end

      describe ".verify_attachment!" do
        let(:initial_parents) { Set[parent1, parent4] }
        let(:current_parents) { initial_parents.dup }

        before do
          Parenter.stub(:parents_of).with(instance).and_return(current_parents)
          parent_model.stub(:permissions_required_to_create).
            and_return(permissions)
        end

        it "checks create permissions for every attached parent" do
          current_parents.add(parent2)
          current_parents.add(parent3)
          current_parents.delete(parent4)
          manager.should_receive(:can!).with(permissions, parent2)
          manager.should_receive(:can!).with(permissions, parent3)
          PersistencyProtector.verify_attachment!(instance)
        end
      end

      describe ".verify_detachment!" do
        let(:initial_parents) { Set[parent1, parent2, parent3] }
        let(:current_parents) { initial_parents.dup }

        before do
          Parenter.stub(:parents_of).with(instance).and_return(current_parents)
          parent_model.stub(:permissions_required_to_destroy).
            and_return(permissions)
        end

        it "checks destroy permissions for every detached parent" do
          current_parents.subtract([parent1, parent2])
          current_parents.add(parent4)
          manager.should_receive(:can!).with(permissions, parent1)
          manager.should_receive(:can!).with(permissions, parent2)
          PersistencyProtector.verify_detachment!(instance)
        end
      end
    end

    describe ".verify_update!" do
      let(:permissions) { Set['permission'] }

      before do
        model.stub(:permissions_required_to_update).and_return(permissions)
      end

      it "checks update permissions at the instance" do
        manager.should_receive(:can!).with(permissions, instance)
        PersistencyProtector.verify_update!(instance)
      end
    end
  end
end
