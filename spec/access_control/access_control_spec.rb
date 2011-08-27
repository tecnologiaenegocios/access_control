require 'spec_helper'
require 'access_control'

describe AccessControl do

  it "has a security manager" do
    AccessControl.security_manager.should be_a(AccessControl::SecurityManager)
  end

  it "instantiates the security manager only once" do
    first = AccessControl.security_manager
    second = AccessControl.security_manager
    first.should equal(second)
  end

  it "stores the security manager in the current thread" do
    current_security_manager = AccessControl.security_manager
    thr_security_manager = nil
    Thread.new { thr_security_manager = AccessControl.security_manager }
    current_security_manager.should_not equal(thr_security_manager)
  end

  after do
    # Clear the instantiated security manager.
    AccessControl.no_security_manager
  end

end
