module AccessControl

  class Configuration

    attr_accessor :default_query_permissions
    attr_accessor :default_view_permissions
    attr_accessor :tree_creation

    def initialize
      @default_query_permissions = ['query']
      @default_view_permissions = ['view']
      @tree_creation = true
    end

  end

  def self.configure
    @config = Configuration.new
    yield @config
  end

  def self.config
    @config ||= Configuration.new
  end

end
