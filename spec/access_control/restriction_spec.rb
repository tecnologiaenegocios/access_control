require 'spec_helper'
require 'access_control/restriction'

module AccessControl
  describe Restriction do

    let(:base) do
      Class.new do
        def self.find(*args); end;
        def self.with_scope(*args)
          before_yield
          results = yield
          after_yield
          results
        end
        def self.after_yield; end
        def self.before_yield; end
      end
    end
    let(:model)   { Class.new(base) }
    let(:manager) { mock('manager') }

    before do
      model.send(:include, Restriction)
    end

    describe ".find" do

      before do
        model.stub(:permissions_required_to_query)
        model.stub(:permissions_required_to_view)
        AccessControl.stub(:security_manager).and_return(manager)
        manager.stub(:restrict_queries?).and_return(true)
        manager.stub(:verify_access!)
      end

      describe "without query restriction" do

        before { manager.stub(:restrict_queries?).and_return(false) }

        it "calls the base class's find" do
          arguments = stub('arguments')
          base.should_receive(:find).with(arguments)
          model.find(arguments)
        end

        it "returns whatever is returned by find_without_permissions" do
          results = stub('results')
          base.stub(:find).and_return(results)
          model.find.should == results
        end

        it "never calls verify_access! on manager" do
          manager.should_not_receive(:verify_access!)
          model.find
        end

      end

      describe "with query restriction" do

        describe "finding every" do

          # :all, :first and :last options triggers this behavior: using the
          # query permissions to filter records.

          let(:restricter)   { mock('restricter', :options => find_options) }
          let(:find_options) { stub('find options') }

          before do
            model.stub(:permissions_required_to_query).
              and_return('the query permissions')
            Restricter.stub(:new).and_return(restricter)
          end

          [:all, :first, :last].each do |option|

            it "builds a restricter from the model" do
              Restricter.should_receive(:new).and_return(restricter)
              model.find(option, 'find arguments')
            end

            it "gets the find options from the restricter" do
              restricter.should_receive(:options).
                with('the query permissions').
                and_return(find_options)
              model.find(option, 'find arguments')
            end

            it "runs a .with_scope with the find options from the restricter" do
              model.should_receive(:with_scope).with(:find => find_options)
              model.find(option, 'find arguments')
            end

            it "forwards all parameters to base's find" do
              base.should_receive(:find).with(option, 'find arguments')
              model.find(option, 'find arguments')
            end

            it "returns the results of calling base's find" do
              base.stub(:find).and_return('results')
              model.find(option, 'find arguments').should == 'results'
            end

            it "runs the query entirely within the scope" do
              base.should_receive(:before_yield).ordered
              base.should_receive(:find).ordered.and_return('results')
              base.should_receive(:after_yield).ordered
              model.find(option, 'find arguments').should == 'results'
            end

          end

        end

        describe "finding one" do

          # Passing a single id causes a permission test with the record
          # returned.

          before do
            model.stub(:permissions_required_to_view).
              and_return('the view permissions')
            base.stub(:find).and_return('some result')
          end

          it "forwards to base class's find" do
            base.should_receive(:find).with(23, 'options').
              and_return('some result')
            model.find(23, 'options')
          end

          it "test the record returned with the manager" do
            manager.should_receive(:verify_access!).
              with('some result', 'the view permissions')
            model.find(23, 'options')
          end

          it "returns the result" do
            model.find(23, 'options').should == 'some result'
          end

        end

        describe "finding some" do

          # Passing a list of ids or an argument list of ids causes a
          # permission test with each record returned.

          before do
            model.stub(:permissions_required_to_view).
              and_return('the view permissions')
            base.stub(:find).and_return(['result 1', 'result 2'])
          end

          [
            [[23, 45], 'options'],
            [23, 45, 'options']
          ].each do |parameters|

            it "forwards to base class's find_without_permissions" do
              base.should_receive(:find).with(parameters).
                and_return(['result 1', 'result 2'])
              model.find(parameters)
            end

            it "test each record returned with the manager" do
              manager.should_receive(:verify_access!).
                with('result 1', 'the view permissions')
              manager.should_receive(:verify_access!).
                with('result 2', 'the view permissions')
              model.find(parameters)
            end

            it "returns the results" do
              model.find(parameters).should == ['result 1', 'result 2']
            end

          end

        end

      end

    end

  end
end
