module AccessControl::Model
  class Principal < ActiveRecord::Base
    set_table_name :ac_principals
    belongs_to :subject, :polymorphic => true
    def securable?
      false
    end
  end
end
