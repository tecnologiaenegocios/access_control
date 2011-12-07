require 'access_control/util'

module AccessControl
  describe Util do

    describe ".flat_set" do
      context "when it doesn't receive a block" do
        it "returns a flat set from a non-Set argument" do
          set_collection = [Set[1], Set[2], Set[3,4]]
          Util.flat_set(set_collection).should == Set[1,2,3,4]
        end

        it "returns a flat set from a Set argument" do
          set = Set[ Set[1], Set[2,3], Set[4] ]
          Util.flat_set(set).should == Set[1,2,3,4]
        end

        it "has no problems if the collection isn't made of Sets" do
          collection = Set[ [1,2,3], Set[3,4], 5, 6 ]
          Util.flat_set(collection).should == Set[1,2,3,4,5,6]
        end
      end

      context "when it does receive a block" do
        it "creates a flat Set from the elements yielded by the block" do
          collection = [1, 2, 3, 4, 5]

          returned_set = Util.flat_set(collection) do |item|
            Set[item.to_s]
          end

          returned_set.should == Set["1", "2", "3", "4", "5"]
        end

        it "works well if the block returns non-Enumerable objects" do
          collection = [1, 2, 3, 4, 5]
          returned_set = Util.flat_set(collection) { |n| n * 2 }

          returned_set.should == Set[2, 4, 6, 8, 10]
        end
      end

    end
  end
end
