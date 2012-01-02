require 'spec_helper'
require 'access_control/persistency_protector'

module AccessControl
  describe PersistencyProtector do

    let(:manager)      { mock('manager') }
    let(:parent_model) { Class.new }
    let(:model)        { Class.new }
    let(:instance)     { model.new }

    before do
      AccessControl.stub(:manager).and_return(manager)
    end

    describe "controlling parents" do
      let(:permissions) { Set['permission'] }
      [1,2,3,4].each { |n| let(:"parent#{n}") { parent_model.new } }

      before do
        # Parenter.stub(:parents_of).with(instance).and_return(initial_parents)
        PersistencyProtector.track_parents(instance)
      end

      # Sometimes one want to ensure if an instance can be put right below a
      # parent (this is called "attaching").  This method does exactly this.
      #
      # But it is convenient to just pass the instance being attached.  It is
      # assumed that the current parents can be guessed through the instance
      # itself, and only the new ones are used to do the verification.  This is
      # why we call .track_parents(instance) first (to make our magic and keep
      # track of the initial parents an instance had at some point).  A further
      # call to .verify_attachment!(instance) will have ways to guess which
      # parents were added, and happily verify attachment to each one.
      #
      # An exception is raised if the needed permissions aren't granted (they
      # must be granted for all new parents).  Use this as a safe belt in
      # places where reporting lack of permissions is not possible (too deep
      # into your code).
      #
      # For historical reasons the permissions to attaching an object to a
      # parent are the ones required to create, and are defined in the model of
      # the instance being created.  Creation is nothing but attaching to a
      # parent.
      describe ".verify_attachment!" do
        let(:initial_parents) { Set[parent1, parent4] }
        let(:current_parents) { initial_parents.dup }

        before do
          # Parenter.stub(:parents_of).with(instance).and_return(current_parents)
          model.stub(:permissions_required_to_create).and_return(permissions)
        end

        xit "checks create permissions for every attached parent" do
          current_parents.add(parent2)
          current_parents.add(parent3)
          current_parents.delete(parent4)
          manager.should_receive(:can!).with(permissions, parent2)
          manager.should_receive(:can!).with(permissions, parent3)
          PersistencyProtector.verify_attachment!(instance)
        end
      end

      # Similar to .verify_attachment!, except that only parents which were
      # gone are verified for detachment (that is, those to which the instance
      # is not positioned below anymore).
      #
      # Again, a previous call to .track_parents is needed in order to get this
      # to work.
      #
      # For historical reasons the permissions to detaching an object from a
      # parent are the ones required to destroy, and are defined in the model
      # of the instance being destroyed.  Destruction is nothing but detaching
      # from a parent.
      describe ".verify_detachment!" do
        let(:initial_parents) { Set[parent1, parent2, parent3] }
        let(:current_parents) { initial_parents.dup }

        before do
          # Parenter.stub(:parents_of).with(instance).and_return(current_parents)
          model.stub(:permissions_required_to_destroy).and_return(permissions)
        end

        xit "checks destroy permissions for every detached parent" do
          current_parents.subtract([parent1, parent2])
          current_parents.add(parent4)
          manager.should_receive(:can!).with(permissions, parent1)
          manager.should_receive(:can!).with(permissions, parent2)
          PersistencyProtector.verify_detachment!(instance)
        end
      end
    end

    # It is possible to ensure that an object can be updated.  Use this method
    # for this and it will look for the right permissions in the class of the
    # instance, and verify if the current user has those permissions in the
    # context of the instance.
    #
    # An exception is raised if the needed permissions aren't granted.  Use
    # this as a safe belt in places where reporting lack of permissions is not
    # possible (too deep into your code).
    describe ".verify_update!" do
      let(:permissions) { Set['permission'] }

      before do
        model.stub(:permissions_required_to_update).and_return(permissions)
      end

      xit "checks update permissions at the instance" do
        manager.should_receive(:can!).with(permissions, instance)
        PersistencyProtector.verify_update!(instance)
      end
    end
  end
end
