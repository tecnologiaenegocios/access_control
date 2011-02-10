module AccessControl
  class Configuration
    attr_accessor :default_access_permission

    def initialize
      @default_access_permission = 'view'
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
