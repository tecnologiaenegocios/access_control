shared_examples_for "an ORM adapter" do
  # These examples are based on the records and sti_records tables in
  # spec/app/db/schema.rb.  The model names are supposed to be 'Record' and
  # 'STIRecord' respectively.

  specify { orm.name.should == 'Record' }
  specify { orm.pk_name.should == :id }
  specify { orm.table_name.should == :records }
  specify { orm.column_names.should == [:id, :field, :name, :record_id] }

  describe "#[](pk)" do
    let(:record) { orm.new.tap { |r| orm.persist(r) } }
    specify      { orm[record.send(orm.pk_name)].should == record }
    specify      { orm['invalid key'].should be_nil }
  end

  describe ".values_at(*pks)" do
    let(:record1) { orm.new.tap { |r| orm.persist(r) } }
    let(:record2) { orm.new.tap { |r| orm.persist(r) } }
    let(:record3) { orm.new.tap { |r| orm.persist(r) } }
    let(:records) { [record1, record2, record3] }
    let(:pks)     { records.map { |r| r.send(orm.pk_name) } }
    specify       { orm.values_at(*pks).to_a.should == records }
  end

  describe ".include?(pk)" do
    let(:record) { orm.new.tap { |r| orm.persist(r) } }
    subject { orm }
    it { should     include(record.send(orm.pk_name)) }
    it { should_not include('invalid key') }
  end

  describe ".size" do
    let!(:record1) { orm.new.tap { |r| orm.persist(r) } }
    let!(:record2) { orm.new.tap { |r| orm.persist(r) } }
    let!(:record3) { orm.new.tap { |r| orm.persist(r) } }
    specify { orm.size.should == 3 }
  end

  describe ".values" do
    let(:record1)  { orm.new.tap { |r| orm.persist(r) } }
    let(:record2)  { orm.new.tap { |r| orm.persist(r) } }
    let(:record3)  { orm.new.tap { |r| orm.persist(r) } }
    let!(:records) { [record1, record2, record3] }
    specify { orm.values.to_a.should == records }
  end

  describe ".sti_subquery" do
    context "when the model has no STI" do
      let(:record1)     { orm.new.tap { |r| orm.persist(r) } }
      let(:record2)     { orm.new.tap { |r| orm.persist(r) } }
      let(:record3)     { orm.new.tap { |r| orm.persist(r) } }
      let!(:record_ids) { [record1.id, record2.id, record3.id] }

      specify do
        orm.execute(orm.sti_subquery).map do |r|
          r[0]
        end.should include_only(*record_ids)
      end
    end

    context "when the model has STI" do
      let(:record1) { stiorm.new.tap { |r| stiorm.persist(r) } }
      let(:record2) { stiorm.new.tap { |r| stiorm.persist(r) } }
      let(:record3) { sub_stiorm.new.tap { |r| sub_stiorm.persist(r) } }
      let(:record4) { sub_stiorm.new.tap { |r| sub_stiorm.persist(r) } }

      let!(:record_ids)     { [record1.id, record2.id] }
      let!(:sub_record_ids) { [record3.id, record4.id] }

      specify do
        stiorm.execute(stiorm.sti_subquery).map do |r|
          r[0]
        end.should include_only(*record_ids)
      end

      specify do
        sub_stiorm.execute(sub_stiorm.sti_subquery).map do |r|
          r[0]
        end.should include_only(*sub_record_ids)
      end
    end
  end

  describe ".new" do
    # This method only need to return an ordinary instance, which must respond
    # to readers and writers corresponding to the column names.
    specify { orm.new.should be_a(model) }
  end

  describe ".subset(subset_name, *args)" do
    # By calling this method the caller expects to get a subset of the whole
    # set of objects, and will want to iterate over it.  This method should not
    # be abused as a general way to send calls to the underlying ORM class.
    it "forwards to the underlying model" do
      p1, p2 = stub, stub
      returned_value = stub
      model.stub(:some_dataset).with(p1, p2).and_return(returned_value)
      orm.subset(:some_dataset, p1, p2).should be returned_value
    end
  end

  describe ".instance_eql?(instance, other)" do
    context "when instances are equal" do
      let!(:record) { orm.new(:name => 'a').tap { |r| orm.persist(r) } }
      specify { orm.instance_eql?(record, record).should be_true }
    end

    context "when instances aren't equal" do
      let!(:record1) { orm.new(:name => 'a').tap { |r| orm.persist(r) } }
      let!(:record2) { orm.new(:name => 'b').tap { |r| orm.persist(r) } }
      specify { orm.instance_eql?(record1, record2).should be_false }
    end
  end

  describe ".persisted?(instance)" do
    context "when the instance isn't a new record" do
      let(:record) { orm.new.tap { |r| orm.persist(r) } }
      specify { orm.persisted?(record).should be_true }
    end

    context "when the instance is a new record" do
      let(:record) { orm.new }
      specify { orm.persisted?(record).should be_false }
    end
  end

  describe ".delete(instance)" do
    let!(:record)    { orm.new.tap { |r| orm.persist(r) } }
    let!(:record_id) { record.send(orm.pk_name) }
    it "destroys the instance" do
      orm.delete(record)
      orm[record_id].should be_nil
    end
  end
end
