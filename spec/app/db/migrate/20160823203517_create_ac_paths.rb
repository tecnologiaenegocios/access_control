class CreateAcPaths < ActiveRecord::Migration
  def self.up
    # The definition below must match the format provided in
    # https://mariadb.com/kb/en/mariadb/oqgraph-overview/
    # execute("INSTALL SONAME 'ha_oqgraph'")
    # execute(
    #   "CREATE TABLE ac_paths ("\
    #     "latch VARCHAR(32) NULL, "\
    #     "origid BIGINT UNSIGNED NULL, "\
    #     "destid BIGINT UNSIGNED NULL, "\
    #     "weight DOUBLE NULL, "\
    #     "seq BIGINT UNSIGNED NULL, "\
    #     "linkid BIGINT UNSIGNED NULL, "\
    #     "KEY (latch, origid, destid) USING HASH, "\
    #     "KEY (latch, destid, origid) USING HASH"\
    #   ") "\
    #   "ENGINE=OQGRAPH "\
    #   "data_table='ac_parents' origid='parent_id' destid='child_id'"
    # )
  end

  def self.down
    # drop_table :ac_paths;
  end
end
