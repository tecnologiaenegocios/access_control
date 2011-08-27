require 'spec_helper'
require 'access_control/active_record_securable'

module AccessControl
  describe ActiveRecordSecurable do
    # A Mix-in module for ActiveRecord models.

    let(:base)  { Class.new }
    let(:model) { Class.new(base) }

    before do
      base.stub(:after_create)
      base.stub(:has_one)
    end

    it "includes associator" do
      model.send(:include, ActiveRecordSecurable)
      model.should include(ActiveRecordAssociator)
    end

    it "configures an association for Node" do
      Node.should_receive(:name).and_return("Node's class name")
      model.should_receive(:associate_with_access_control).
        with(:ac_node, "Node's class name", :securable)
      model.send(:include, ActiveRecordSecurable)
    end

  end
end
