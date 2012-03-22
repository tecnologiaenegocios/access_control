require 'access_control/principal'

module AccessControl
  class NullManager
    def use_anonymous?
      false
    end

    def use_anonymous!
    end

    def do_not_use_anonymous!
    end

    def current_subjects= ignored
    end

    def current_principals= ignored
    end

    def current_principals
      Set.new
    end

    def principals
      [UnrestrictablePrincipal.instance]
    end

    def can!(permissions, nodes)
    end

    def can?(permissions, nodes)
      true
    end

    def restrict_queries?
      false
    end

    def without_query_restriction
      yield
    end

    def trust
      previous_trust_status = inside_trusted_block?
      @inside_trusted_block = true
      without_query_restriction { yield }
    ensure
      @inside_trusted_block = previous_trust_status
    end

    def inside_trusted_block?
      !!@inside_trusted_block
    end
  end
end
