module AccessControl
  class Transaction
    THREAD_KEY = :__ac_transaction__

    def initialize
      @counter = 0
    end

    def run
      increment
      AccessControl.manager.trust { yield }.tap do |_|
        commit if @counter == 1
      end
    ensure
      decrement
      clear if @counter == 0
    end

    def add(task)
      tasks << task
    end

    def commit
      first = tasks.shift
      first.run if first
      AccessControl.manager.trust do
        while tasks.any?
          tasks.shift.run
        end
      end
    end

    def rollback
      @tasks = []
    end

  private

    def tasks
      @tasks ||= []
    end

    def increment
      @counter += 1
    end

    def decrement
      @counter -= 1
    end

    def clear
      @tasks = []
    end

    class << self
      def current
        Thread.current[THREAD_KEY] ||= new
      end
    end
  end
end
