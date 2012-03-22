require 'access_control/null_restriction'

module AccessControl
  describe NullRestriction do
    let(:base) do
      Class.new do
        def self.find(*args)
          yield
        end

        def self.scoped(*args)
        end
      end
    end

    let(:model) { Class.new(base) }

    before do
      model.class_eval do
        include NullRestriction
      end
    end

    describe ".listable" do
      it "returns an empty scope" do
        base.stub(:scoped).with({}).and_return('empty scoped')

        model.listable.should == 'empty scoped'
      end
    end

    describe ".unrestricted_find" do
      it "delegates to super's find" do
        base.stub(:find).with('the args').and_return('find result')

        model.unrestricted_find('the args').should == 'find result'
      end

      it "passes the block to super's find" do
        testpoint = stub
        testpoint.should_receive(:block_called!)

        model.unrestricted_find do
          testpoint.block_called!
        end
      end
    end
  end
end
