require 'spec_helper'
require 'access_control/association_security'

module AccessControl
  describe AssociationSecurity do

    let(:model) { mock('model') }
    let(:reflection) { mock('reflection', :name => 'reflection_name',
                            :active_record => model) }
    let(:association_proxy_class) do
      Class.new do
      private
        def find_target(*args)
          do_find
        end
        def do_find; end
      end
    end
    let(:association_proxy) do
      r = association_proxy_class.new
      r.instance_variable_set(:@reflection, reflection)
      r
    end
    let(:manager) do
      r = Class.new.new
      r.class.class_eval do
        def without_query_restriction
          yield
        end
      end
      r
    end

    describe "#find_target" do

      before do
        AccessControl.stub(:security_manager).and_return(manager)
        association_proxy_class.class_eval do
          include AccessControl::AssociationSecurity
        end
      end

      it "is kept private" do
        association_proxy.private_methods.should include('find_target')
      end

      it "verifies if the model restricts the association" do
        model.should_receive(:association_restricted?).
          with(reflection.name.to_sym).
          and_return(false)
        association_proxy.send(:find_target)
      end

      describe "when the owner class doesn't include ModelSecurity" do
        it "delegates to superclass method" do
          manager.should_not_receive(:without_query_restriction)
          association_proxy.should_receive(:do_find)
          association_proxy.send(:find_target)
        end
        it "returns whatever it returned" do
          association_proxy.stub(:do_find).and_return('results')
          association_proxy.send(:find_target).should == 'results'
        end
      end

      describe "when the class doesn't restrict for this association" do
        before do
          model.stub(:association_restricted?).and_return(false)
        end
        it "opens a .without_query_restriction block" do
          manager.should_receive(:without_query_restriction)
          association_proxy.send(:find_target)
        end
        it "calls the superclass implementation" do
          association_proxy.should_receive(:do_find)
          association_proxy.send(:find_target)
        end
        it "calls the implementation from within the block" do
          manager.instance_eval do
            def without_query_restriction
              result = yield
              yielded(result)
              result
            end
            def yielded(result); end
          end
          association_proxy.should_receive(:do_find).and_return('results')
          manager.should_receive(:yielded).with('results')
          association_proxy.send(:find_target)
        end
        it "returns whatever it returned" do
          association_proxy.stub(:do_find).and_return('results')
          association_proxy.send(:find_target).should == 'results'
        end
      end

      describe "when the class enforces restriction" do
        before do
          model.stub(:association_restricted?).and_return(true)
        end
        it "delegates to superclass method" do
          manager.should_not_receive(:without_query_restriction)
          association_proxy.should_receive(:do_find)
          association_proxy.send(:find_target)
        end
        it "returns whatever it returned" do
          association_proxy.stub(:do_find).and_return('results')
          association_proxy.send(:find_target).should == 'results'
        end
      end

    end

  end
end
