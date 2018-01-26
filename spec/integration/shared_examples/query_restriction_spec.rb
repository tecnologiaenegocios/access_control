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

  listable = 'is listable'
  unlistable = 'lacks permission'
  mismatch = 'type mismatch'
  expectations_summary = [
    # query on class of          with permission to list       record       specialized_record   super_specialized_record
    [:record,                    [:record],                    listable,    unlistable,          unlistable],
    [:record,                    [:specialized_record],        unlistable,  listable,            unlistable],
    [:record,                    [:super_specialized_record],  unlistable,  unlistable,          listable],
    [:record,                    [:record,
                                  :specialized_record],        listable,    listable,            unlistable],
    [:record,                    [:record,
                                  :super_specialized_record],  listable,    unlistable,          listable],
    [:record,                    [:specialized_record,
                                  :super_specialized_record],  unlistable,  listable,            listable],
    [:record,                    [:record,
                                  :specialized_record,
                                  :super_specialized_record],  listable,    listable,            listable],
    [:specialized_record,        [:record],                    mismatch,    unlistable,          unlistable],
    [:specialized_record,        [:specialized_record],        mismatch,    listable,            unlistable],
    [:specialized_record,        [:super_specialized_record],  mismatch,    unlistable,          listable],
    [:specialized_record,        [:record,
                                  :specialized_record],        mismatch,    listable,            unlistable],
    [:specialized_record,        [:record,
                                  :super_specialized_record],  mismatch,    unlistable,          listable],
    [:specialized_record,        [:specialized_record,
                                  :super_specialized_record],  mismatch,    listable,            listable],
    [:specialized_record,        [:record,
                                  :specialized_record,
                                  :super_specialized_record],  mismatch,    listable,            listable],
    [:super_specialized_record,  [:record],                    mismatch,    mismatch,            unlistable],
    [:super_specialized_record,  [:specialized_record],        mismatch,    mismatch,            unlistable],
    [:super_specialized_record,  [:super_specialized_record],  mismatch,    mismatch,            listable],
    [:super_specialized_record,  [:record,
                                  :specialized_record],        mismatch,    mismatch,            unlistable],
    [:super_specialized_record,  [:record,
                                  :super_specialized_record],  mismatch,    mismatch,            listable],
    [:super_specialized_record,  [:specialized_record,
                                  :super_specialized_record],  mismatch,    mismatch,            listable],
    [:super_specialized_record,  [:record,
                                  :specialized_record,
                                  :super_specialized_record],  mismatch,    mismatch,            listable],
  ]

  let(:list_record_permission) do
    AccessControl.registry.store('list_record')
  end

  let(:list_specialized_record_permission) do
    AccessControl.registry.store('list_specialized_record')
  end

  let(:list_super_specialized_record_permission) do
    AccessControl.registry.store('list_super_specialized_record')
  end

  before do
    record_class.class_eval do
      list_requires 'list_record'
    end

    specialized_record_class.class_eval do
      list_requires 'list_specialized_record'
    end

    super_specialized_record_class.class_eval do
      list_requires 'list_super_specialized_record'
    end
  end

  expectations_summary.group_by { |q, *| q }.each do |query_on, specs|
    context "querying on #{query_on}'s class" do
      specs.each do |(_, permissions, *outcomes)|
        results = %i(record specialized_record super_specialized_record).zip(outcomes).to_h
        context "when user has permission to #{permissions.map { |r| "'list_#{r}'" }.join(', ')}" do
          before do
            role.add_permissions(permissions.map { |r| send(:"list_#{r}_permission") })
          end

          results.each do |(r, result)|
            if result == listable
              it "can list '#{r}'" do
                send(:"#{query_on}_class").all.should include(send(r))
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
