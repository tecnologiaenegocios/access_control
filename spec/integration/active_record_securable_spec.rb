require 'spec_helper'

describe "node association" do
  include WithConstants

  let_active_record(:Record) do
    include AccessControl::Securable
    requires_no_permissions!
  end

  subject { Record.new }

  it "associates a node for a given active record object" do
    AccessControl::Node(subject).should be_a(AccessControl::Node)
  end

  specify "once the node is computed, it is cached" do
    old_result = AccessControl::Node(subject)
    new_result = AccessControl::Node(subject)
    old_result.should be new_result
  end

  it "persists the node when the record is created" do
    node = AccessControl::Node(subject)
    subject.save!
    node.should be_persisted
  end

  specify "the node can be found later for that record" do
    subject.save!
    node = AccessControl::Node(subject)
    other_node = AccessControl::Node(Record.first)
    other_node.should == node
  end

  it "destroys the node when the record is destroyed" do
    subject.save!
    node = AccessControl::Node(subject)
    node.should_receive(:destroy)
    subject.destroy
  end

  describe "update" do
    let(:node) { AccessControl::Node(subject) }

    context "the record already has a node" do
      before do
        subject.save!
        node.persist!
      end

      it "doesn't persist the node again" do
        node.should_not_receive(:persist)
        subject.save!
      end
    end

    context "the record has no node yet" do
      let_active_record(:Record) { }

      before do
        subject.save!
        Record.class_eval do
          include AccessControl::Securable
          requires_no_permissions!
        end
      end

      it "persists the node" do
        record = Record.first
        node = AccessControl::Node(record)
        record.save!
        node.should be_persisted
      end

      specify "the node can be found later for that record" do
        record = Record.first
        record.save!
        node = AccessControl::Node(record)
        other_node = AccessControl::Node(Record.first)
        other_node.should == node
      end
    end
  end
end
