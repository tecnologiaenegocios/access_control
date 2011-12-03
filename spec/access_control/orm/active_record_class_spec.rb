require 'access_control/orm'

module AccessControl
  module ORM
    describe ActiveRecordClass do

      let(:model) do
        m = stub('model', {
          :name              => 'ModelName',
          :quoted_table_name => "`table_name`",
          :primary_key       => "pk",

          :reflections       => reflections,

          :connection => connection,
        })
        m.stub(:scoped) do |options|
          scope_with(options)
        end
        m
      end

      let(:connection) do
        c = stub('connection', :select_values => 'result')
        c.stub(:quote) do |value|
          "Quoted: #{value.inspect}"
        end
        c
      end

      let(:reflected)   { Class.new }
      let(:reflections) { { :association => stub(:klass => reflected) } }

      def scope_with(options)
        scoped = stub('scoped with args', :options => options)
        scoped.stub(:to_sql) do
          "Scoped SQL: #{options.inspect}"
        end
        scoped
      end

      let(:orm) { ActiveRecordClass.new(model) }

      describe "#name" do
        subject { orm.name }
        it { should == 'ModelName' }
      end

      describe "#full_pk" do
        subject { orm.full_pk }
        it { should == "`table_name`.pk" }
      end

      describe "#quote_values" do
        context "empty array" do
          subject { orm.quote_values([]) }
          it { should == "Quoted: nil" }
        end
        context "non-empty array" do
          subject { orm.quote_values([1, 2]) }
          it { should == "Quoted: 1,Quoted: 2" }
        end
      end

      describe "#associated_class" do
        subject { orm.associated_class(:association) }

        it "adapts the associated class from the association given" do
          ORM.should_receive(:adapt_class).with(reflected)
          subject
        end

        it { should be_a(ActiveRecordClass) }
      end

      describe "#primary_keys" do
        context "without join association" do
          subject { orm.primary_keys('Some SQL') }

          it "issues a query using the connection" do
            connection.should_receive(:select_values).with(
              "Scoped SQL: #{{
                :select     => "`table_name`.pk",
                :conditions => 'Some SQL',
                :joins      => nil
              }.inspect}"
            )
            subject
          end

          it { should == 'result' }
        end

        context "with join association" do
          subject { orm.primary_keys('Some SQL', :association) }

          it "issues a query using the connection" do
            connection.should_receive(:select_values).with(
              "Scoped SQL: #{{
                :select     => "`table_name`.pk",
                :conditions => 'Some SQL',
                :joins      => :association
              }.inspect}"
            )
            subject
          end

          it { should == 'result' }
        end
      end

      describe "#foreign_keys" do
        let(:reflected_orm) { stub('reflected orm', :full_pk => 'full.pk') }
        subject { orm.foreign_keys(:association) }

        before do
          orm.stub(:associated_class).and_return(reflected_orm)
        end

        it "issues a query using the connection" do
          connection.should_receive(:select_values).with(
            "Scoped SQL: #{{
              :select => "full.pk",
              :joins  => :association,
            }.inspect}"
          )
          subject
        end

        it { should == 'result' }
      end

    end
  end
end
