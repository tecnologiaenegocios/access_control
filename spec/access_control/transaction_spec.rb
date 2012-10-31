require 'spec_helper'
require 'access_control/transaction'

module AccessControl
  describe Transaction do
    after      { AccessControl.no_manager }

    subject    { Transaction.new }
    let(:code) { stub }

    def new_task
      task = stub
      task.stub(:run) { yield }
      task
    end

    describe "#run" do
      it "executes the given block" do
        code.should_receive(:executed)
        subject.run { code.executed }
      end

      it "returns the result of the block" do
        subject.run { 'result' }.should == 'result'
      end

      it "postpones added task until the end of the transaction" do
        task = new_task { code.task_executed }

        code.should_receive(:block_executed).ordered
        code.should_receive(:task_executed).ordered

        subject.add(task)
        subject.run { code.block_executed }
      end

      it "doesn't run added task inside a trusted block" do
        task = new_task do
          AccessControl.manager.should_not be_inside_trusted_block
        end
        subject.add(task)
        subject.run { }
      end

      describe "nested transactions" do
        it "executes all tasks after block code" do
          task          = new_task { code.task_executed }
          subtask       = new_task { code.subtask_executed }
          other_subtask = new_task { code.other_subtask_executed }

          code.should_receive(:first_block_execution).ordered
          code.should_receive(:second_block_execution).ordered
          code.should_receive(:task_executed).ordered
          code.should_receive(:subtask_executed).ordered
          code.should_receive(:other_subtask_executed).ordered

          subject.run do
            code.first_block_execution

            subject.add(task)

            subject.run do
              subject.add(subtask)
            end

            subject.run do
              subject.run do
                code.second_block_execution
              end
            end

            subject.run do
              subject.add(other_subtask)
            end
          end
        end

        it "runs all but the first task inside a trusted block" do
          first_task = new_task do
            AccessControl.manager.should_not be_inside_trusted_block
          end
          second_task = new_task do
            AccessControl.manager.should be_inside_trusted_block
          end

          subject.add(first_task)
          subject.add(second_task)
          subject.run { }
        end
      end
    end

    describe "#commit" do
      it "executes added tasks" do
        task1 = new_task { code.task1_executed }
        task2 = new_task { code.task2_executed }

        subject.add(task1)
        subject.add(task2)

        code.should_receive(:task1_executed).ordered
        code.should_receive(:task2_executed).ordered

        subject.commit
      end

      context "when more tasks are added" do
        let(:task)          { new_task { code.task_executed } }
        let(:one_more_task) { new_task { code.one_more_task_executed } }

        before do
          code.stub(:task_executed)
          subject.add(task)
          subject.commit
          subject.add(one_more_task)
        end

        it "executes the remaining tasks" do
          code.should_not_receive(:task_executed)
          code.should_receive(:one_more_task_executed)

          subject.commit
        end
      end
    end

    describe "#rollback" do
      it "forgets added tasks" do
        task          = new_task { code.task_executed }
        other_task    = new_task { code.other_task_executed }
        one_more_task = new_task { code.one_more_task_executed }

        subject.add(task)
        subject.add(other_task)

        subject.rollback
        subject.add(one_more_task)

        code.should_not_receive(:task_executed)
        code.should_not_receive(:other_task_executed)
        code.should_receive(:one_more_task_executed)

        subject.commit
      end
    end

    describe "after run" do
      let(:task) { code.task_executed }
      before     { code.stub(:task_executed) }

      it "clears all tasks" do
        subject.add(task)
        subject.run { }

        code.should_not_receive(:task_executed)

        subject.run { }
      end
    end

    describe ".current" do
      it "is a Transaction object" do
        Transaction.current.is_a?(Transaction)
      end

      it "is unique for each thread" do
        from_thread1 = nil
        from_thread2 = nil
        from_thread3 = nil

        Thread.new do
          from_thread1 = Transaction.current
          Thread.new do
            from_thread2 = Transaction.current
          end
        end

        Thread.new do
          from_thread3 = Transaction.current
        end

        from_thread1.should_not be_equal(from_thread2)
        from_thread2.should_not be_equal(from_thread3)
        from_thread3.should_not be_equal(from_thread1)
      end
    end
  end
end
