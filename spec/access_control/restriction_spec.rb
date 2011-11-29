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
      AccessControl.stub(:manager).and_return(manager)
    end

    describe ".find" do

      before do
        model.stub(:permissions_required_to_index)
        model.stub(:permissions_required_to_show)
        manager.stub(:restrict_queries?).and_return(true)
        manager.stub(:can!)
      end

      describe "without query restriction" do

        before { manager.stub(:restrict_queries?).and_return(false) }

        it "calls the base class's find" do
          arguments = stub('arguments')
          base.should_receive(:find).with(arguments)
          model.find(arguments)
        end

        it "returns whatever is returned by the superclass method" do
          results = stub('results')
          base.stub(:find).and_return(results)
          model.find.should == results
        end

        it "never calls can! on manager" do
          manager.should_not_receive(:can!)
          model.find
        end

      end

      describe "with query restriction" do

        describe "finding every" do

          # :all, :first and :last options triggers this behavior: using the
          # query permissions to filter records.

          let(:restricter)    { mock('restricter',
                                     :sql_condition => sql_condition) }
          let(:sql_condition) { stub('sql condition') }
          let(:global_node)   { stub('global node') }

          before do
            model.stub(:permissions_required_to_index).
              and_return('the index permissions')
            Restricter.stub(:new).and_return(restricter)
          end

          [:all, :first, :last].each do |option|

            context "with permissions in the global node" do

              before do
                Node.stub(:global).and_return(global_node)
                manager.stub(:can?).with('the index permissions', global_node).
                  and_return(true)
              end

              it "calls .can? to verify permissions in the global node" do
                manager.should_receive(:can?).
                  with('the index permissions', global_node).and_return(true)
                model.find(option, 'find arguments')
              end

              it "calls the base class's find" do
                arguments = stub('arguments')
                base.should_receive(:find).with(option, arguments)
                model.find(option, arguments)
              end

              it "returns whatever is returned by the superclass method" do
                results = stub('results')
                base.stub(:find).and_return(results)
                model.find.should == results
              end

            end

            context "without permissions in the global node" do

              before do
                Node.stub(:global).and_return(global_node)
                manager.stub(:can?).with('the index permissions', global_node).
                  and_return(false)
              end

              it "calls .can? to verify permissions in the global node" do
                manager.should_receive(:can?).
                  with('the index permissions', global_node).and_return(false)
                model.find(option, 'find arguments')
              end

              it "builds a restricter from the model" do
                Restricter.should_receive(:new).and_return(restricter)
                model.find(option, 'find arguments')
              end

              it "gets the find options from the restricter" do
                restricter.should_receive(:sql_condition).
                  with('the index permissions').
                  and_return(sql_condition)
                model.find(option, 'find arguments')
              end

              context "when conditions from restricter are not falsy" do

                it "runs a .with_scope with the find options from the "\
                   "restricter" do
                  model.should_receive(:with_scope).
                    with(:find => {:conditions => sql_condition})
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

              context "when conditions from restricter are falsy" do
                before { restricter.stub(:sql_condition).and_return('0') }

                it "doesn't hit the database" do
                  model.should_not_receive(:with_scope)
                  model.find(option, 'find arguments')
                end

                it "returns an empty result" do
                  if option == :all
                    model.find(option, 'find arguments').should == []
                  else
                    model.find(option, 'find arguments').should be_nil
                  end
                end
              end

            end
          end

        end

        describe "finding one" do

          # Passing a single id causes a permission test with the record
          # returned.

          before do
            model.stub(:permissions_required_to_show).
              and_return('the show permissions')
            base.stub(:find).and_return('some result')
          end

          it "forwards to base class's find" do
            base.should_receive(:find).with(23, 'options').
              and_return('some result')
            model.find(23, 'options')
          end

          it "test the record returned with the manager" do
            manager.should_receive(:can!).
              with('the show permissions', 'some result')
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
            model.stub(:permissions_required_to_show).
              and_return('the show permissions')
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
              manager.should_receive(:can!).
                with('the show permissions', 'result 1')
              manager.should_receive(:can!).
                with('the show permissions', 'result 2')
              model.find(parameters)
            end

            it "returns the results" do
              model.find(parameters).should == ['result 1', 'result 2']
            end

          end

        end

      end

    end

    describe ".unrestricted_find" do

      before do
        manager.instance_eval do
          def without_query_restriction
            result = yield
            yielded(result)
            result
          end
          def yielded(result); end
        end
        model.stub(:find).and_return('find results')
      end

      it "opens a .without_query_restriction block" do
        manager.should_receive(:without_query_restriction)
        model.unrestricted_find
      end

      it "calls .find with the arguments provided" do
        model.should_receive(:find).with('the arguments')
        model.unrestricted_find('the arguments')
      end

      it "calls .find from within the block" do
        manager.should_receive(:yielded).with('find results')
        model.unrestricted_find
      end

      it "returns whatever find has returned" do
        model.stub(:find).and_return('find results')
        model.unrestricted_find.should == 'find results'
      end

    end

    describe "#valid?" do

      # Validation should happen without query restriction.

      let(:base) do
        Class.new do
          def valid?
            called_from_base
          end
        end
      end
      let(:instance) { model.new }

      before do
        instance.stub(:called_from_base).and_return('validation result')
        manager.instance_eval do
          def without_query_restriction
            result = yield
            yielded(result)
            result
          end
          def yielded(result); end
        end
      end

      it "opens a .without_query_restriction block" do
        manager.should_receive(:without_query_restriction)
        instance.valid?
      end

      it "calls #valid? of the base class" do
        instance.should_receive(:called_from_base)
        instance.valid?
      end

      it "calls #valid? from within the block" do
        manager.should_receive(:yielded).with('validation result')
        instance.valid?
      end

      it "returns whatever base#valid? has returned" do
        instance.valid?.should == 'validation result'
      end

    end

  end
end
