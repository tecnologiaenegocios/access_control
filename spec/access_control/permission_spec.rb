require 'access_control/permission'

module AccessControl
  describe Permission do

    describe "initialization" do
      it "is done by passing a name" do
        permission = Permission.new("permission")
        permission.name.should == "permission"
      end

      it "it default to an empty name when none is provided" do
        permission = Permission.new
        permission.name.should == ""
      end
    end

  end
end
