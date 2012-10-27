shared_examples_for "any AccessControl object associated with an ActiveRecord::Base" do
  subject { ar_object_class.new }

  after { AccessControl::ActiveRecordAssociator.clear }

  describe "create" do
    before { include_needed_modules(ar_object_class) }

    it "associates an AC object for a given active record object" do
      ac_object_from_ar_object(subject).should be_a(ac_object_class)
    end

    specify "once the AC object is computed, it is cached" do
      old_result = ac_object_from_ar_object(subject)
      new_result = ac_object_from_ar_object(subject)
      old_result.should be new_result
    end

    it "persists the record" do
      subject.save!
      subject.reload.id.should_not be_nil
    end

    it "persists the AC object when the record is created" do
      ac_object = ac_object_from_ar_object(subject)
      subject.save!
      ac_object.should be_persisted
    end

    it "doesn't persist the AC object if a before_create callback returns false" do
      subject.class.class_eval do
        before_create { |record| false }
      end
      ac_object = ac_object_from_ar_object(subject)
      subject.save
      ac_object.should_not be_persisted
    end

    it "doesn't persist the AC object if a before_create callback returns false" do
      subject.class.class_eval do
        after_create { |record| raise "error" }
      end
      ac_object = ac_object_from_ar_object(subject)
      subject.save rescue nil
      ac_object.should_not be_persisted
    end

    it "doesn't persist the AC object in case of validation error" do
      subject.class.class_eval do
        validate { |record| record.errors.add(:foo, :bar) }
      end
      ac_object = ac_object_from_ar_object(subject)
      subject.save
      ac_object.should_not be_persisted
    end

    it "accepts the validation flag on #save" do
      ac_object = ac_object_from_ar_object(subject)
      subject.save(false)
      ac_object.should be_persisted
    end

    it "returns the result on regular successful #save call" do
      subject.save.should be_true
    end

    it "returns the result on regular unsuccessful #save call" do
      subject.class.class_eval do
        validate { |record| record.errors.add(:foo, :bar) }
      end
      subject.save.should be_false
    end

    specify "the AC object is saved with correct attributes" do
      subject.save!
      ac_object = ac_object_from_ar_object(subject)
      ac_object.send(ac_object_type_attr).should == ar_object_class.name
      ac_object.send(ac_object_id_attr).should   == subject.id
    end

    it "rollsback the record state if the AC object cannot be persisted" do
      ac_object = ac_object_from_ar_object(subject)
      ac_object.stub(:persist!).and_raise(AccessControl::Unauthorized)

      subject.save! rescue nil

      subject.id.should be_nil
      subject.should be_new_record
    end
  end

  describe "update" do
    let(:ac_object) { ac_object_from_ar_object(subject) }

    context "the record already has an AC object" do
      before do
        include_needed_modules(ar_object_class)
        subject.save!
        ac_object.persist!
      end

      it "updates the record" do
        subject.name = 'foo'
        subject.save!
        subject.reload.name.should == 'foo'
      end

      it "forces an update in the AC object by calling #persist!" do
        ac_object.should_receive(:persist!)
        subject.save!
      end

      it "doesn't persist the AC object if a before_update callback returns false" do
        subject.class.class_eval do
          before_update { |record| false }
        end
        ac_object.should_not_receive(:persist!)
        subject.save
      end

      it "doesn't persist the AC object if an after_update callback breaks" do
        subject.class.class_eval do
          after_update { |record| raise "error" }
        end
        ac_object.should_not_receive(:persist!)
        subject.save rescue nil
      end

      it "doesn't persist the AC object in case of validation error" do
        subject.class.class_eval do
          validate { |record| record.errors.add(:foo, :bar) }
        end
        ac_object.should_not_receive(:persist!)
        subject.save
      end

      it "returns the result on regular successful #save call" do
        subject.save.should be_true
      end

      it "returns the result on regular unsuccessful #save call" do
        subject.class.class_eval do
          validate { |record| record.errors.add(:foo, :bar) }
        end
        subject.save.should be_false
      end

      it "rollsback the record state if the AC object cannot be persisted" do
        ac_object.stub(:persist!).and_raise(AccessControl::Unauthorized)

        subject.name = 'foo'
        subject.save! rescue nil

        subject.class.find(subject.id).name.should be_nil
      end
    end

    context "the record has no AC object yet" do
      before do
        subject.save! # Save before adding association
        include_needed_modules(ar_object_class)
      end

      it "updates the record" do
        subject.name = 'foo'
        subject.save!
        subject.reload.name.should == 'foo'
      end

      it "persists the AC object" do
        record = ar_object_class.first
        ac_object = ac_object_from_ar_object(record)
        record.save!
        ac_object.should be_persisted
      end

      specify "the AC object is saved with correct attributes" do
        record = ar_object_class.first
        record.save!
        ac_object.send(ac_object_type_attr).should == ar_object_class.name
        ac_object.send(ac_object_id_attr).should   == record.id
      end
    end
  end

  describe "destroy" do
    let(:ac_object) { ac_object_from_ar_object(subject) }

    before do
      include_needed_modules(ar_object_class)
      subject.save!
    end

    it "destroys the record" do
      subject.destroy
      subject.should be_destroyed
    end

    it "destroys the AC object when the record is destroyed" do
      ac_object.should_receive(:destroy)
      subject.destroy
    end

    it "doesn't destroy the node if a before_destroy callback returns false" do
      subject.class.class_eval do
        before_destroy { |record| false }
      end
      ac_object.should_not_receive(:destroy)
      subject.destroy
    end

    it "rollsback the record destruction if the AC object cannot be destroyed" do
      ac_object.stub(:destroy).and_raise(AccessControl::Unauthorized)

      subject.destroy rescue nil

      subject.class.find(subject.id).should == subject
    end
  end

  describe "in subclasses" do
    let_constant(:ar_object_subclass) { new_class(:SubClass, ar_object_class) }

    subject { ar_object_subclass.new }

    describe "create" do
      before { include_needed_modules(ar_object_class) }

      it "associates an AC object for a given active record object" do
        ac_object_from_ar_object(subject).should be_a(ac_object_class)
      end

      specify "once the AC object is computed, it is cached" do
        old_result = ac_object_from_ar_object(subject)
        new_result = ac_object_from_ar_object(subject)
        old_result.should be new_result
      end

      it "persists the AC object when the record is created" do
        ac_object = ac_object_from_ar_object(subject)
        subject.save!
        ac_object.should be_persisted
      end

      specify "the AC object is saved with correct attributes" do
        subject.save!
        ac_object = ac_object_from_ar_object(subject)
        ac_object.send(ac_object_type_attr).should == ar_object_subclass.name
        ac_object.send(ac_object_id_attr).should   == subject.id
      end
    end

    describe "update" do
      let(:ac_object) { ac_object_from_ar_object(subject) }

      context "the record already has an AC object" do
        before do
          include_needed_modules(ar_object_subclass)
          subject.save!
          ac_object.persist!
        end

        it "forces an update in the AC object by calling #persist!" do
          ac_object.should_receive(:persist!)
          subject.save!
        end
      end

      context "the record has no AC object yet" do
        before do
          subject.save! # Save before adding association
          include_needed_modules(ar_object_class)
        end

        it "persists the AC object" do
          record = ar_object_class.first
          ac_object = ac_object_from_ar_object(record)
          record.save!
          ac_object.should be_persisted
        end

        specify "the AC object is saved with correct attributes" do
          record = ar_object_class.first
          record.save!
          ac_object.send(ac_object_type_attr).should == ar_object_subclass.name
          ac_object.send(ac_object_id_attr).should   == record.id
        end
      end
    end

    describe "destroy" do
      before { include_needed_modules(ar_object_class) }

      it "destroys the AC object when the record is destroyed" do
        subject.save!
        ac_object = ac_object_from_ar_object(subject)
        ac_object.should_receive(:destroy)
        subject.destroy
      end
    end
  end
end
