class Object
  def should_receive_without_query_restriction(method_name, &block)
    should_receive_without_restriction(:query, method_name, &block)
  end

  def should_receive_without_restriction(restriction_name, method_name)
    target = self

    target_events = []

    target.stub(method_name) do
      target_events << method_name
    end

    manager = stub('manager')
    AccessControl.stub(:manager).and_return(manager)

    manager.define_singleton_method(:"without_#{restriction_name}_restriction") do |&b|
      if block_given?
        target_events << :before_block
        b.call
        target_events << :after_block
      end
    end

    yield

    unless target_events == [:before_block, method_name, :after_block]
      raise Spec::Mocks::MockExpectationError,
        "#{target} expected #{method_name} inside unrestricted #{restriction_name} block"
    end
  end
end
