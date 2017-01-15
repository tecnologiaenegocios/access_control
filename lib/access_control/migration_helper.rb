module AccessControl
  module MigrationHelper
    def default_options
      use_inno_db_and_set_charset? ?
        { :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8' } : {}
    end

    def id_to_limit_8(table)
      case adapter
      when 'mysql', 'mysql2'
        execute(
          "ALTER TABLE `#{table}` CHANGE COLUMN `id` "\
            "`id` BIGINT NOT NULL AUTO_INCREMENT"
        )
      end
    end

    def add_constraints(table, options)
      defaults = {
        :key       => :id,
        :on_update => :cascade,
        :on_delete => :restrict
      }

      case adapter
      when 'mysql', 'mysql2'
        options.each do |key, suboptions|
          unless suboptions.is_a?(Hash)
            suboptions = { :parent => suboptions }
          end

          suboptions = defaults.merge(suboptions)

          parent     = suboptions[:parent]
          on_update  = suboptions[:on_update].to_s.upcase
          on_delete  = suboptions[:on_delete].to_s.upcase
          parent_key = suboptions[:key]
          name       = suboptions[:name] || "constraint_#{table}_on_#{key}"

          execute(
            "ALTER TABLE `#{table}` "\
              "ADD CONSTRAINT `#{name}` "\
              "FOREIGN KEY (`#{key}`) "\
              "REFERENCES `#{parent}`(`#{parent_key}`) "\
              "ON UPDATE #{on_update} "\
              "ON DELETE #{on_delete}"
          )
        end
      end
    end

  private

    def use_inno_db_and_set_charset?
      adapter == 'mysql' || adapter == 'mysql2'
    end

    def adapter
      ActiveRecord::Base.configurations[Rails.env]['adapter']
    end
  end
end
