require 'spec_helper'

module AccessControl
  describe Logger do
    subject { Logger.new }

    let(:rails_logger) { stub }
    let(:buffer)       { '' }
    let(:named_factory) do
      Class.new(String) do
        def name
          self
        end
      end
    end

    def named(name)
      named_factory.new(name)
    end

    def with_buffer
      yield
      result = buffer.dup
      buffer.gsub!(/.*/, '')
      result
    end

    before do
      ActiveRecord::Base.stub(:colorize_logging).and_return(false)
      Rails.stub(:logger).and_return(rails_logger)
      rails_logger.stub(:info) { |message| buffer << message }
    end

    describe "#unauthorized" do
      let(:requirements) { [named('permission 1'),
                            named('permission 2'),
                            named('permission 3')] }
      let(:current)      { [named('permission 1')] }

      let(:roles)      { [named('role 1'), named('role 2')] }
      let(:nodes)      { [stub('node 1',      :inspect => 'node 1'),
                          stub('node 2',      :inspect => 'node 2')] }
      let(:principals) { [stub('principal 1', :inspect => 'principal 1'),
                          stub('principal 2', :inspect => 'principal 2')] }

      def output
        with_buffer do
          subject.unauthorized(requirements,
                               current,
                               roles,
                               nodes,
                               principals,
                               ['backtrace line'])
        end
      end

      it "clealy states that an access is unauthorized" do
        output.should match(/^UNAUTHORIZED\b/)
      end

      it "tells which permissions where missing" do
        output.should match(/\bpermission 2\b/)
        output.should match(/\bpermission 3\b/)
      end

      it "tells which roles the principals had in the occurrence" do
        output.should match(/\brole 1\b/)
        output.should match(/\brole 2\b/)
      end

      it "tells which nodes the checking was made against" do
        output.should match(/\bnode 1\b/)
        output.should match(/\bnode 2\b/)
      end

      it "tells which principals participated in the occurrence" do
        output.should match(/\bprincipal 1\b/)
        output.should match(/\bprincipal 2\b/)
      end

      it "prints each line of the traceback" do
        output.should match(/^\s*backtrace line$/)
      end
    end

    describe "#unregistered_permission" do
      def output
        with_buffer do
          subject.unregistered_permission('some permission')
        end
      end

      it "logs the permission" do
        output.should == 'Permission "some permission" is not registered'
      end
    end
  end
end
