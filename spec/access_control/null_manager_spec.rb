require 'spec_helper'
require 'access_control/null_manager'

module AccessControl
  describe NullManager do
    subject { NullManager.new }

    its(:use_anonymous?) { should be_false }

    describe "#use_anonymous!" do
      it "does nothing" do
        subject.use_anonymous!.should be_nil
      end
    end

    describe "#do_not_use_anonymous!" do
      it "does nothing" do
        subject.do_not_use_anonymous!.should be_nil
      end
    end

    describe "#current_subjects=" do
      it "does nothing" do
        result = subject.public_send(:current_subjects=, 'ignored')
        result.should be_nil
      end
    end

    describe "#current_principals=" do
      it "does nothing" do
        result = subject.public_send(:current_principals=, 'ignored')
        result.should be_nil
      end
    end

    its(:current_principals) { should == Set.new }
    its(:principals) { should == [UnrestrictablePrincipal.instance] }

    describe "#can?" do
      it "returns true" do
        subject.can?('ignored', 'ignored').should be_true
      end
    end

    describe "#can!" do
      it "does nothing" do
        subject.can!.should be_nil
      end
    end

    its(:restrict_queries?) { should be_false }

    describe "#without_query_restriction" do
      it "yields to its block and return its result" do
        result = subject.without_query_restriction do
          'return value'
        end
        result.should == 'return value'
      end
    end

    describe "#trust" do
      it "yields to its block and return its result" do
        result = subject.trust do
          'return value'
        end
        result.should == 'return value'
      end

      it "signalizes when inside a trusted block" do
        result = subject.trust do
          subject.inside_trusted_block?
        end
        result.should be_true
      end

      it "signalizes when outside a trusted block" do
        subject.should_not be_inside_trusted_block
      end

      it "signalizes out of a trusted block if the block has raised" do
        begin
          subject.trust { raise StandardError }
        rescue StandardError
          # pass
        end

        subject.should_not be_inside_trusted_block
      end

      it "bubbles the exception raised in the block" do
        exception = Class.new(StandardError)
        lambda {
          subject.trust { raise exception }
        }.should raise_exception(exception)
      end

      context "when already inside a trusted block" do
        it "signalizes accordingly" do
          result = subject.trust do
            subject.trust do
              subject.inside_trusted_block?
            end
          end
          result.should be_true
        end

        it "keeps the flag after the innermost block has ended" do
          result = subject.trust do
            subject.trust { }
            subject.inside_trusted_block?
          end

          result.should be_true
        end

        it "correctly unsets the flag when the outermost block has ended" do
          subject.trust do
            subject.trust {}
          end
          subject.should_not be_inside_trusted_block
        end
      end
    end
  end
end
