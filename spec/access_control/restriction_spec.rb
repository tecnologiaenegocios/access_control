require 'spec_helper'
require 'access_control/restriction'

module AccessControl
  describe Restriction do

    let(:base)    { Class.new }
    let(:model)   { Class.new(base) }
    let(:manager) { mock('manager') }

    before do
      model.stub(:quoted_table_name => '`table`', :primary_key => 'id')
      model.send(:include, Restriction)
      AccessControl.stub(:manager).and_return(manager)
    end

    describe ".find" do

      before do
        model.stub(:permissions_required_to_index)
        model.stub(:permissions_required_to_show)
        manager.stub(:restrict_queries?).and_return(true)
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
      end

      describe "with query restriction" do

        describe "finding every" do

          # :all, :first and :last options triggers this behavior: using the
          # query permissions to filter records.

          let(:restricter)  { mock('restricter') }
          let(:subquery)    { 'the id subquery expression' }
          let(:global_node) { stub('global node') }
          let(:adapted)     { stub('adapted') }

          before do
            model.stub(:permissions_required_to_index).
              and_return('the index permissions')
            ORM.stub(:adapt_class).and_return(adapted)
            Restricter.stub(:new).with(adapted).and_return(restricter)
            AccessControl.stub(:global_node).and_return(global_node)
          end

          [:all, :first, :last].each do |option|
            context "when doing find(:#{option})" do
              before do
                restricter.stub(:sql_query_for).
                  with('the index permissions').
                  and_return(subquery)

                base.class_eval do
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

              it "runs a .with_scope with the find options from the "\
                  "restricter" do
                model.should_receive(:with_scope).
                  with(:find => {:conditions => "`table`.id IN (#{subquery})"})
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
                base.should_receive(:find).ordered
                base.should_receive(:after_yield).ordered
                model.find(option, 'find arguments')
              end
            end
          end
        end

        describe "finding one" do

          # Passing a single id causes a permission test with the record
          # returned.

          let(:single_result) { stub }
          let(:permissions)   { stub }

          before do
            model.stub(:permissions_required_to_show).
              and_return(['show permission'])
            base.stub(:find).with(23, 'options').and_return(single_result)
            manager.stub(:can!)
            AccessControl::Registry.stub(:fetch_all).
              with(['show permission']).and_return(permissions)
          end

          it "test the record returned with the manager" do
            manager.should_receive(:can!).with(permissions, single_result)
            model.find(23, 'options')
          end

          it "returns the result" do
            model.find(23, 'options').should be single_result
          end

        end

        describe "finding some" do

          # Passing a list of ids or an argument list of ids causes a
          # permission test with each record returned.  Basically it happens
          # always when the first argument is not :all, :first or :last.

          let(:result1)     { stub }
          let(:result2)     { stub }
          let(:all_results) { [result1, result2] }
          let(:permissions) { stub }

          before do
            model.stub(:permissions_required_to_show).
              and_return(['show permission'])
            base.stub(:find).with('args').and_return(all_results)
            manager.stub(:can!)
            AccessControl::Registry.stub(:fetch_all).
              with(['show permission']).and_return(permissions)
          end

          it "test each record returned with the manager" do
            manager.should_receive(:can!).with(permissions, result1)
            manager.should_receive(:can!).with(permissions, result2)
            model.find('args')
          end

          it "returns the results" do
            model.find('args').should be all_results
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
