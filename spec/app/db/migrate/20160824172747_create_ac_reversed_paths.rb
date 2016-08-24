class CreateAcReversedPaths < ActiveRecord::Migration
  def self.up
    # The definition below must match the format provided in
    # https://mariadb.com/kb/en/mariadb/oqgraph-overview/
    execute(
      "CREATE TABLE ac_reversed_paths ("\
        "latch VARCHAR(32) NULL, "\
        "origid BIGINT UNSIGNED NULL, "\
        "destid BIGINT UNSIGNED NULL, "\
        "weight DOUBLE NULL, "\
        "seq BIGINT UNSIGNED NULL, "\
        "linkid BIGINT UNSIGNED NULL, "\
        "KEY (latch, origid, destid) USING HASH, "\
        "KEY (latch, destid, origid) USING HASH"\
      ") "\
      "ENGINE=OQGRAPH "\
      "data_table='ac_parents' origid='child_id' destid='parent_id'"
    )
  end

  def self.down
    drop_table :ac_reversed_paths;
  end
end
