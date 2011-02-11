module AccessControl

  class Configuration
    attr_accessor :default_query_permissions

    def initialize
      @default_query_permissions = ['view']
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
