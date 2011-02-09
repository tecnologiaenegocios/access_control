require 'spec_helper'

module AccessControl
  describe SecurityProxy do

    it "cannot wrap an unsecurable object" do
      lambda {
        SecurityProxy.new(Object.new)
      }.should raise_exception(CannotWrapUnsecurableObject)
    end

    describe "normal object" do
      it "is not proxied by default" do
        Object.new.security_proxied?.should be_false
      end
      it "is not securable by default" do
        Object.new.securable?.should be_false
      end
    end

    describe "proxied object" do
      let(:unproxied) { Object.new }
      let(:proxied) { SecurityProxy.new(unproxied) }
      let(:manager) { mock('manager') }

      before do
        unproxied.stub!(:securable?).and_return(true)
        unproxied.class.stub!(:permissions_for).and_return(Set.new)
        ::AccessControl.stub!(:get_security_manager).and_return(manager)
        manager.stub!(:verify_permission!)
      end

      it "is security proxied" do
        proxied.security_proxied?.should be_true
      end

      it "is not securable (prevents being re-proxied)" do
        proxied.securable?.should be_false
      end

      it "can have its target unwraped" do
        proxied.remove_security_proxy.should equal(unproxied)
      end

      describe "when a public method is called from outside the object" do

        let(:node1) { mock('node1') }
        let(:node2) { mock('node2') }

        before do
          unproxied.stub!(:foo).and_return('the foo value')
        end

        it "calls verify_access! on the manager at each method call" do
          queried_permissions = Set.new(['some permission',
                                         'other permission'])
          nodes = [node1, node2]
          unproxied.class.should_receive(:permissions_for).with('foo').
            and_return(queried_permissions)
          unproxied.should_receive(:ac_nodes).and_return(nodes)
          manager.should_receive(:verify_access!).
            with(nodes, queried_permissions)
          proxied.foo.should == 'the foo value'
        end

        it "verifies permissions when using 'send'" do
          unproxied.class.should_receive(:permissions_for).with('foo')
          proxied.send(:foo).should == 'the foo value'
        end

        it "verifies permissions when using '__send__'" do
          unproxied.class.should_receive(:permissions_for).with('foo')
          proxied.__send__(:foo).should == 'the foo value'
        end

        it "is stupid about send('send', 'foo')" do
          # This is a known way to violate the proxy protection.  Another
          # way is to use the recommended `remove_security_proxy` method.
          # We are not going to fix this by now.  Instead, we are
          # documenting if :)
          unproxied.class.should_receive(:permissions_for).with('send')
          proxied.send(:send, :foo).should == 'the foo value'
        end

        it "passes along all parameters to the target's method" do
          unproxied.should_receive(:foo).with(
            'some arguments', 'more arguments'
          )
          proxied.foo('some arguments', 'more arguments')
        end

        it "returns the value of the target's method" do
          return_value = Object.new
          unproxied.stub!(:foo).and_return(return_value)
          proxied.foo.should equal(return_value)
        end

        it "returns unproxied if the value is not securable" do
          return_value = Object.new
          unproxied.stub!(:foo).and_return(return_value)
          proxied.foo.should_not be_security_proxied
        end

        it "returns proxied if the value is securable" do
          return_value = Object.new
          return_value.instance_eval do
            def securable?
              true
            end
          end
          unproxied.stub!(:foo).and_return(return_value)
          proxied.foo.security_proxied?.should be_true
        end

      end

      describe "when public method is called from inside the object" do
        before do
          unproxied.class_eval do
            define_method(:foo) { self.bar }
            define_method(:bar) { qux }
            protected :bar
            define_method(:qux) { Object.new }
            private :qux
          end
        end

        it "passes through the proxy once until the end of method call chain" do
          unproxied.class.should_receive(:permissions_for).exactly(1).times.
            with('foo').and_return(Set.new)
          # we call foo, which calls permissions_for once, and them foo calls
          # bar, which should not call permissions_for again because it is
          # called from inside the object, and then qux is called, and again
          # permissions_for isn't called, and then the final value is returned.
          proxied.foo
        end

        after do
          unproxied.class_eval do
            undef_method(:foo)
            undef_method(:bar)
            undef_method(:qux)
          end
        end
      end

      describe "when protected method is called" do

        before do
          unproxied.class_eval do
            define_method(:foo) {}
            protected :foo
          end
        end

        after do
          unproxied.class_eval do
            undef_method(:foo)
          end
        end

        # Currently I found no way to proper implement protected method calls
        # on the proxy object.
        #
        # Basically there's no way to detect when the receiver of the method is
        # 'self' (or something of the same class of) or something else when the
        # method is called, here being 'self' the target (unproxied) object.
        # This could be done only in a level up, if we invoke set_trace_func
        # and start inspecting when a method on the proxy is called -- and then
        # verify if the caller is allowed to call it based on its class
        # (checking if its class is the same or a subclass of the target
        # object) and the type of the method.
        #
        # By now, any call to a protected method is simply blocked with an
        # exception.
        it "blocks execution with ProxyProtectedMethodError" do
          lambda {
            proxied.foo
          }.should raise_exception(ProxyProtectedMethodError)
        end

        describe "through `send`" do
          it "checks the permission for the method" do
            unproxied.class.should_receive(:permissions_for).once.
              with('foo').and_return(Set.new)
            proxied.send(:foo)
          end
        end

      end

      describe "when private method is called" do

        before do
          unproxied.class_eval do
            define_method(:foo) {}
            private :foo
          end
        end

        after do
          unproxied.class_eval do
            undef_method(:foo)
          end
        end

        it "raises NoMethodError as usually" do
          lambda { proxied.foo }.should raise_exception(NoMethodError)
        end

        describe "through `send`" do
          it "checks the permission for the method" do
            unproxied.class.should_receive(:permissions_for).once.
              with('foo').and_return(Set.new)
            proxied.send(:foo)
          end
        end

      end

    end

  end
end
