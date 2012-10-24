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

    it "persists the AC object when the record is created" do
      ac_object = ac_object_from_ar_object(subject)
      subject.save!
      ac_object.should be_persisted
    end

    specify "the AC object is saved with correct attributes" do
      subject.save!
      ac_object = ac_object_from_ar_object(subject)
      ac_object.send(ac_object_type_attr).should == ar_object_class.name
      ac_object.send(ac_object_id_attr).should   == subject.id
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
        ac_object = ac_object_from_ar_object(subject)
        ac_object.send(ac_object_type_attr).should == ar_object_class.name
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
          ac_object = ac_object_from_ar_object(subject)
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
