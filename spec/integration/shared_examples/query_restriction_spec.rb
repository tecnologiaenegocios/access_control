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
  context "with different permissions between class and subclasses" do
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

    context "when the user has only permission to list 'record'" do
      before do
        role.add_permissions([list_record_permission])
      end

      context "and the query is done through 'record'" do
        it "can list a record" do
          record_class.all.should include(record)
        end

        it "cannot list a specialized record" do
          record_class.all.should_not include(specialized_record)
        end

        it "cannot list a super specialized record" do
          record_class.all.should_not include(super_specialized_record)
        end
      end

      context "and the query is done through 'specialized_record'" do
        it "cannot list a record because type mismatch" do
          specialized_record_class.all.should_not include(record)
        end

        it "cannot list a specialized record" do
          specialized_record_class.all.should_not include(specialized_record)
        end

        it "cannot list a super specialized record" do
          record_class.all.should_not include(super_specialized_record)
        end
      end

      context "and the query is done through 'super_specialized_record'" do
        it "cannot list a record because type mismatch" do
          super_specialized_record_class.all.should_not include(record)
        end

        it "cannot list a specialized record because type mismatch" do
          super_specialized_record_class.all.should_not include(specialized_record)
        end

        it "cannot list a super specialized record" do
          super_specialized_record_class.all.should_not include(super_specialized_record)
        end
      end
    end

    context "when the user has only permission to list 'specialized_record'" do
      before do
        role.add_permissions([list_specialized_record_permission])
      end

      context "and the query is done through 'record'" do
        it "cannot list a record" do
          record_class.all.should_not include(record)
        end

        it "can list a specialized record" do
          record_class.all.should include(specialized_record)
        end

        it "cannot list a super specialized record" do
          record_class.all.should_not include(super_specialized_record)
        end
      end

      context "and the query is done through 'specialized_record'" do
        it "cannot list a record because type mismatch" do
          specialized_record_class.all.should_not include(record)
        end

        it "can list a specialized record" do
          specialized_record_class.all.should include(specialized_record)
        end

        it "cannot list a super specialized record" do
          specialized_record_class.all.should_not include(super_specialized_record)
        end
      end

      context "and the query is done through 'super_specialized_record'" do
        it "cannot list a record because type mismatch" do
          super_specialized_record_class.all.should_not include(record)
        end

        it "cannot list a specialized record because type mismatch" do
          super_specialized_record_class.all.should_not include(specialized_record)
        end

        it "cannot list a super specialized record" do
          super_specialized_record_class.all.should_not include(super_specialized_record)
        end
      end
    end

    context "when the user has only permission to list 'super_specialized_record'" do
      before do
        role.add_permissions([list_super_specialized_record_permission])
      end

      context "and the query is done through 'record'" do
        it "cannot list a record" do
          record_class.all.should_not include(record)
        end

        it "cannot list a specialized record" do
          record_class.all.should_not include(specialized_record)
        end

        it "can list a super specialized record" do
          record_class.all.should include(super_specialized_record)
        end
      end

      context "and the query is done through 'specialized_record'" do
        it "cannot list a record because type mismatch" do
          specialized_record_class.all.should_not include(record)
        end

        it "cannot list a specialized record" do
          specialized_record_class.all.should_not include(specialized_record)
        end

        it "can list a super specialized record" do
          specialized_record_class.all.should include(super_specialized_record)
        end
      end

      context "and the query is done through 'super_specialized_record'" do
        it "cannot list a record because type mismatch" do
          super_specialized_record_class.all.should_not include(record)
        end

        it "cannot list a specialized record because type mismatch" do
          super_specialized_record_class.all.should_not include(specialized_record)
        end

        it "can list a super specialized record" do
          super_specialized_record_class.all.should include(super_specialized_record)
        end
      end
    end

    context "when the user has permissions for 'record' and 'specialized_record'" do
      before do
        role.add_permissions([list_record_permission,
                              list_specialized_record_permission])
      end

      context "and the query is done through 'record'" do
        it "can list a record" do
          record_class.all.should include(record)
        end

        it "can list a specialized record" do
          record_class.all.should include(specialized_record)
        end

        it "cannot list a super specialized record" do
          record_class.all.should_not include(super_specialized_record)
        end
      end

      context "and the query is done through 'specialized_record'" do
        it "cannot list a record because type mismatch" do
          specialized_record_class.all.should_not include(record)
        end

        it "can list a specialized record" do
          specialized_record_class.all.should include(specialized_record)
        end

        it "cannot list a super specialized record" do
          specialized_record_class.all.should_not include(super_specialized_record)
        end
      end

      context "and the query is done through 'super_specialized_record'" do
        it "cannot list a record because type mismatch" do
          super_specialized_record_class.all.should_not include(record)
        end

        it "cannot list a specialized record because type mismatch" do
          super_specialized_record_class.all.should_not include(specialized_record)
        end

        it "cannot list a super specialized record" do
          super_specialized_record_class.all.should_not include(super_specialized_record)
        end
      end
    end

    context "when the user has permissions for 'specialized_record' and 'super_specialized_record'" do
      before do
        role.add_permissions([list_specialized_record_permission,
                              list_super_specialized_record_permission])
      end

      context "and the query is done through 'record'" do
        it "cannot list a record" do
          record_class.all.should_not include(record)
        end

        it "can list a specialized record" do
          record_class.all.should include(specialized_record)
        end

        it "can list a super specialized record" do
          record_class.all.should include(super_specialized_record)
        end
      end

      context "and the query is done through 'specialized_record'" do
        it "cannot list a record because type mismatch" do
          specialized_record_class.all.should_not include(record)
        end

        it "can list a specialized record" do
          specialized_record_class.all.should include(specialized_record)
        end

        it "can list a super specialized record" do
          specialized_record_class.all.should include(super_specialized_record)
        end
      end

      context "and the query is done through 'super_specialized_record'" do
        it "cannot list a record because it's not of the same class" do
          super_specialized_record_class.all.should_not include(record)
        end

        it "cannot list a specialized record because type mismatch" do
          super_specialized_record_class.all.should_not include(specialized_record)
        end

        it "can list a super specialized record" do
          super_specialized_record_class.all.should include(super_specialized_record)
        end
      end
    end

    context "when the user has permissions for listing all types" do
      before do
        role.add_permissions([list_record_permission,
                              list_specialized_record_permission,
                              list_super_specialized_record_permission])
      end

      context "and the query is done through 'record'" do
        it "can list a record" do
          record_class.all.should include(record)
        end

        it "can list a specialized record" do
          record_class.all.should include(specialized_record)
        end

        it "can list a super specialized record" do
          record_class.all.should include(super_specialized_record)
        end
      end

      context "and the query is done through 'specialized_record'" do
        it "cannot list a record because type mismatch" do
          specialized_record_class.all.should_not include(record)
        end

        it "can list a specialized record" do
          specialized_record_class.all.should include(specialized_record)
        end

        it "can list a super specialized record" do
          specialized_record_class.all.should include(super_specialized_record)
        end
      end

      context "and the query is done through 'super_specialized_record'" do
        it "cannot list a record because it's not of the same class" do
          super_specialized_record_class.all.should_not include(record)
        end

        it "cannot list a specialized record because type mismatch" do
          super_specialized_record_class.all.should_not include(specialized_record)
        end

        it "can list a super specialized record" do
          super_specialized_record_class.all.should include(super_specialized_record)
        end
      end
    end
  end
end
