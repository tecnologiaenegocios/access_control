module AccessControl
  def self.logger
    AccessControl::Logger.new
  end

  class Logger
    class ColorizedOutput
      def initialize(message)
        @message = message
      end
      def to_s
        ActiveRecord::Base.colorize_logging ? colorized_to_s : @message
      end
      def colorized_to_s
        raise NotImplementedError
      end
    end

    class AlertOutput < ColorizedOutput
      def colorized_to_s
        "\e[31;1m#{@message}\e[0m"
      end
    end

    class TraceOutput < ColorizedOutput
      def colorized_to_s
        "\e[31;2m#{@message}\e[0m"
      end
    end

    class Message
      def initialize(output, indentation_level=0)
        @output    = output
        @formatter = Formatter.new(indentation_level)
      end
    end

    class UnauthorizedMessage < Message
      def format(missing_permissions, roles, nodes, principals)
        message = "UNAUTHORIZED Missing #{
          @formatter.sentence(missing_permissions.map(&:name))
        } (principals: #{
          @formatter.sentence_with_inspect(principals)
        }, nodes: #{
          @formatter.sentence_with_inspect(nodes)
        }, roles: #{
          @formatter.sentence(roles.map(&:name))
        })"

        @output.new(@formatter.indent(message))
      end
    end

    class TraceMessage < Message
      def format(trace)
        trace = Rails.respond_to?(:backtrace_cleaner) ?
          Rails.backtrace_cleaner.clean(trace) :
          trace

        @output.new(trace.map { |line| @formatter.indent(line) }.join("\n")).to_s
      end
    end

    class UnregisteredPermissionMessage < Message
      def format(permission)
        message = "Permission #{permission.inspect} is not registered"
        @output.new(message).to_s
      end
    end

    class Formatter
      def initialize(indentation_level)
        @indentation = ' ' * indentation_level
      end

      def sentence_with_inspect(collection)
        sentence(collection.map(&:inspect))
      end

      def sentence(collection)
        collection.to_sentence(:locale => 'en')
      end

      def indent(line)
        @indentation + line
      end
    end

    def unauthorized(requirements, current, roles, nodes, principals, trace)
      log_unauthorized(
        Util.make_set_from_args(requirements),
        Util.make_set_from_args(current),
        Util.make_set_from_args(roles),
        Util.make_set_from_args(nodes),
        Util.make_set_from_args(principals),
        trace
      )
    end

    def unregistered_permission(permission)
      message = UnregisteredPermissionMessage.new(AlertOutput).format(permission)
      Rails.logger.info(message)
    end

  private

    def log_unauthorized requirements, current, roles, nodes, principals, trace
      missing = requirements - current
      Rails.logger.info("#{
        UnauthorizedMessage.new(AlertOutput).format(missing, roles, nodes, principals)
      }\n#{
        TraceMessage.new(TraceOutput, 2).format(trace)
      }")
    end
  end
end
