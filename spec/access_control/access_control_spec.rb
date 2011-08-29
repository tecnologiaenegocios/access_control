require 'spec_helper'
require 'access_control'

describe AccessControl do

  it "has a manager" do
    AccessControl.manager.should be_a(AccessControl::Manager)
  end

  it "instantiates the manager only once" do
    first = AccessControl.manager
    second = AccessControl.manager
    first.should equal(second)
  end

  it "stores the manager in the current thread" do
    current_manager = AccessControl.manager
    thr_manager = nil
    Thread.new { thr_manager = AccessControl.manager }
    current_manager.should_not equal(thr_manager)
  end

  after do
    # Clear the instantiated manager.
    AccessControl.no_manager
  end

end
