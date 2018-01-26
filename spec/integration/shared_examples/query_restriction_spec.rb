shared_examples_for "query restriction" do
  # These examples require the definition of three levels of STI model
  # (ActiveRecord) classes for the `sti_records' table, without special
  # permissions (permissions will be associated when needed in this
  # file):
  #
  #   `record_class' ->
  #     `specialized_record_class' ->
  #       `super_specialized_record_class'
  #
  # It is implicitly assumed that a user (`user') is currently logged in and
  # has some role (`role') associated (globally or in a parent record, it
  # doesn't matter, but you should consider testing both kinds).
  #
  # Finally, the records themselves must be early created using `let!', within
  # these names: `record', `specialized_record' and `super_specialized_record'.

  allowed = :listable
  disallowed = 'lack of permission'
  mismatch = 'type mismatch'
  expectations_summary = [
    # query on class of          with permission to list       record       specialized_record   super_specialized_record
    [:record,                    [:record],                    allowed,     disallowed,          disallowed],
    [:record,                    [:specialized_record],        disallowed,  allowed,             disallowed],
    [:record,                    [:super_specialized_record],  disallowed,  disallowed,          allowed],
    [:record,                    [:record,
                                  :specialized_record],        allowed,     allowed,             disallowed],
    [:record,                    [:record,
                                  :super_specialized_record],  allowed,     disallowed,          allowed],
    [:record,                    [:specialized_record,
                                  :super_specialized_record],  disallowed,  allowed,             allowed],
    [:record,                    [:record,
                                  :specialized_record,
                                  :super_specialized_record],  allowed,     allowed,             allowed],
    [:specialized_record,        [:record],                    mismatch,    disallowed,          disallowed],
    [:specialized_record,        [:specialized_record],        mismatch,    allowed,             disallowed],
    [:specialized_record,        [:super_specialized_record],  mismatch,    disallowed,          allowed],
    [:specialized_record,        [:record,
                                  :specialized_record],        mismatch,    allowed,             disallowed],
    [:specialized_record,        [:record,
                                  :super_specialized_record],  mismatch,    disallowed,          allowed],
    [:specialized_record,        [:specialized_record,
                                  :super_specialized_record],  mismatch,    allowed,             allowed],
    [:specialized_record,        [:record,
                                  :specialized_record,
                                  :super_specialized_record],  mismatch,    allowed,             allowed],
    [:super_specialized_record,  [:record],                    mismatch,    mismatch,            disallowed],
    [:super_specialized_record,  [:specialized_record],        mismatch,    mismatch,            disallowed],
    [:super_specialized_record,  [:super_specialized_record],  mismatch,    mismatch,            allowed],
    [:super_specialized_record,  [:record,
                                  :specialized_record],        mismatch,    mismatch,            disallowed],
    [:super_specialized_record,  [:record,
                                  :super_specialized_record],  mismatch,    mismatch,            allowed],
    [:super_specialized_record,  [:specialized_record,
                                  :super_specialized_record],  mismatch,    mismatch,            allowed],
    [:super_specialized_record,  [:record,
                                  :specialized_record,
                                  :super_specialized_record],  mismatch,    mismatch,            allowed],
  ]

  let(:list_record_permission) do
    AccessControl.registry.store('list_record')
  end

  let(:show_record_permission) do
    AccessControl.registry.store('show_record')
  end

  let(:list_specialized_record_permission) do
    AccessControl.registry.store('list_specialized_record')
  end

  let(:show_specialized_record_permission) do
    AccessControl.registry.store('show_specialized_record')
  end

  let(:list_super_specialized_record_permission) do
    AccessControl.registry.store('list_super_specialized_record')
  end

  let(:show_super_specialized_record_permission) do
    AccessControl.registry.store('show_super_specialized_record')
  end

  before do
    record_class.class_eval do
      list_requires 'list_record'
      show_requires 'show_record'
    end

    specialized_record_class.class_eval do
      list_requires 'list_specialized_record'
      show_requires 'show_specialized_record'
    end

    super_specialized_record_class.class_eval do
      list_requires 'list_super_specialized_record'
      show_requires 'show_super_specialized_record'
    end
  end

  expectations_summary.group_by { |q, *| q }.each do |query_on, specs|
    context "querying on #{query_on}'s class" do
      specs.each do |(_, permissions, *outcomes)|
        results = %i(record specialized_record super_specialized_record).zip(outcomes).to_h
        context "when user has permission to #{permissions.map { |r| "'show_#{r}'" }.join(', ')}" do
          before do
            role.add_permissions(permissions.map { |r| send(:"show_#{r}_permission") })
          end

          results.each do |(r, result)|
            if result == allowed
              it "can show '#{r}'" do
                id = send(r).id
                send(:"#{query_on}_class").find(id).should == send(r)
              end
            elsif result == disallowed
              it "cannot show '#{r}' due to lack of permission" do
                id = send(r).id
                -> { send(:"#{query_on}_class").find(id) }.should raise_error(AccessControl::Unauthorized)
              end
            else
              it "cannot show '#{r}' due to type mismatch" do
                id = send(r).id
                -> { send(:"#{query_on}_class").find(id) }.should raise_error(ActiveRecord::RecordNotFound)
              end
            end
          end
        end

        context "when user has permission to #{permissions.map { |r| "'list_#{r}'" }.join(', ')}" do
          before do
            role.add_permissions(permissions.map { |r| send(:"list_#{r}_permission") })
          end

          results.each do |(r, result)|
            if result == allowed
              it "can list '#{r}'" do
                send(:"#{query_on}_class").all.should include(send(r))
              end

              context "safe condition" do
                it "can list '#{r}' using a hash condition on id" do
                  id = send(r).id
                  send(:"#{query_on}_class").all(conditions: { id: id }).should include(send(r))
                end

                it "can list '#{r}' using a hash condition on a column which is not id" do
                  name = send(r).name
                  send(:"#{query_on}_class").all(conditions: { name: name }).should include(send(r))
                end

                it "can list '#{r}' using a string condition" do
                  id = send(r).id
                  send(:"#{query_on}_class").all(conditions: ["id = ?", id]).should include(send(r))
                end
              end
            else
              it "cannot list '#{r}' due to #{result}" do
                send(:"#{query_on}_class").all.should_not include(send(r))
              end
            end
          end
        end
      end
    end
  end
end
