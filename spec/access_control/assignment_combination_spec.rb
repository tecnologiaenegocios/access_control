require "spec_helper"

module AccessControl
  describe AssignmentCombination do

    it "is an Enumerable" do
      subject.should be_kind_of Enumerable
    end

    describe "results generation" do
      subject { AssignmentCombination.new(:node_id => 1, :principal_id => 2,
                                          :role_id => 3) }
      let!(:results) { subject.all }

      it "doesn't occur if no property was modified" do
        subject.all.should == results
      end

      it "occurs if the 'node_id' was modified" do
        subject.node_id = -1
        subject.all.should_not == results
      end

      it "occurs if the 'role_id' was modified" do
        subject.role_id = -1
        subject.all.should_not == results
      end

      it "occurs if the 'principal_id' was modified" do
        subject.principal_id = -1
        subject.all.should_not == results
      end
    end

    properties = %w[roles_ids principals_ids nodes_ids]

    properties.each do |property|
      describe "the property #{property}" do
        setter   = "#{property}="

        it "can be set on initialization" do
          subject = AssignmentCombination.new(property => [1,2,3])

          return_value = subject.public_send(property)
          return_value.should == [1,2,3]
        end

        it "when set to an enumerable, remains as the enumerable set" do
          subject.public_send(setter, [1,2,3])

          return_value = subject.public_send(property)
          return_value.should == [1,2,3]
        end

        it "can be set to a single value, when used in singular form" do
          singular_setter = setter.gsub(/s_ids=/,"_id=")
          subject.public_send(singular_setter, 1)

          return_value = subject.public_send(property)
          return_value.should == Set[1]
        end

        it "when set to nil, is redefined as an empty Set" do
          subject.public_send(setter, nil)

          return_value = subject.public_send(property)
          return_value.should == Set.new
        end

        pretty_setter = setter.gsub(/_ids/,'')
        describe "the pretty setter '#{pretty_setter}'" do

          it "when used with a enumerable, defines #{property} as their ids" do
            collection = [stub(:id => 4321), stub(:id => 1234)]
            subject.public_send(pretty_setter, collection)

            return_value = subject.public_send(property)
            return_value.should == Set[1234, 4321]
          end

          it "when used in singular form, defines #{property} as its id" do
            singular_setter = pretty_setter.gsub(/s=/,"=")

            object = stub(:id => 1234)
            subject.public_send(singular_setter, object)

            return_value = subject.public_send(property)
            return_value.should == Set[1234]
          end

          it "removes nil ids in a collection" do
            collection = [stub(:id => 4321), stub(:id => nil)]
            subject.public_send(pretty_setter, collection)

            return_value = subject.public_send(property)
            return_value.should == Set[4321]
          end
        end
      end

    end

    describe "#all" do
      it "returns an Array" do
        subject.all.should be_kind_of Array
      end

      it "doesn't raise exceptions if the properties are not arrays" do
        subject.roles_ids      = Set[1,2,3]
        subject.principals_ids = (4..6)
        subject.nodes_ids      = 7

        lambda {
          subject.all
        }.should_not raise_exception
      end

      it "can be iterated by using #each" do
        subject.roles_ids      = [1,2,3]
        subject.principals_ids = [4,5,6]
        subject.nodes_ids      = [7,8,9]

        Assignment.stub(:new) { |*args| args }

        yielded_values = Array.new
        subject.each do |value|
          yielded_values << value
        end

        all_assignments = subject.all
        yielded_values.should include(*all_assignments)
        yielded_values.length.should == all_assignments.length
      end
    end

    describe "the returned assignments" do
      let(:roles_ids)      { [1,2,3] }
      let(:principals_ids) { [4,5,6] }
      let(:nodes_ids)      { [7,8,9] }

      subject do
        AssignmentCombination.new.tap do |combination|
          combination.roles_ids      = roles_ids
          combination.principals_ids = principals_ids
          combination.nodes_ids      = nodes_ids
        end
      end
      let(:returned_instances) { subject.all }

      specify "are created using Assignment.new" do
        combinations_count = [roles_ids,principals_ids,nodes_ids].
                               map(&:length).inject(:*)

        new_assignment = stub("new assignment")
        Assignment.stub(:new).and_return(new_assignment)

        expected_result = [new_assignment]*combinations_count
        returned_instances.should include(*expected_result)
        returned_instances.length.should == expected_result.length
      end

      specify "cover all the roles_ids" do
        returned_instances.map(&:role_id).should include(*roles_ids)
      end

      specify "cover all the principals_ids" do
        returned_instances.map(&:principal_id).
          should include(*principals_ids)
      end

      specify "cover all the nodes_ids" do
        returned_instances.map(&:node_id).should include(*nodes_ids)
      end

      specify "have unique combinations of role, principal and node ids" do
        combinations = returned_instances.map do |assignment|
          [assignment.role_id, assignment.principal_id, assignment.node_id]
        end

        combinations.uniq.length.should == combinations.length
      end

    end

    context "when an overlapping assignment exists" do
      let(:roles_ids)      { [1,2] }
      let(:principals_ids) { [3] }
      let(:nodes_ids)      { [5] }

      subject do
        AssignmentCombination.new.tap do |combination|
          combination.roles_ids      = roles_ids
          combination.principals_ids = principals_ids
          combination.nodes_ids      = nodes_ids
        end
      end

      let(:existing_assignment) do
        stub("Existing Assignment", :role_id => 1, :principal_id => 3, :node_id => 5)
      end

      let(:new_assignment) do
        stub("New Assignment", :role_id => 2, :principal_id => 3, :node_id => 5)
      end

      before do
        Assignment.stub(:new => new_assignment)
        Assignment.stub(:overlapping).with(roles_ids, principals_ids, nodes_ids).
          and_return(Set[existing_assignment])
      end

      context "and 'include_existing_assignments' is true" do
        before { subject.include_existing_assignments = true }

        let(:return_value) { subject.all }

        it "returns the existing assignment" do
          return_value.should include(existing_assignment)
        end

        it "returns new assignments" do
          return_value.should include(new_assignment)
        end
      end

      context "and 'include_existing_assignments' is false" do
        before { subject.include_existing_assignments = false }

        let(:return_value) { subject.all }

        it "doesn't return exising assignments" do
          return_value.should_not include(existing_assignment)
        end

        it "returns new assignments" do
          return_value.should include(new_assignment)
        end
      end
    end

  end
end
