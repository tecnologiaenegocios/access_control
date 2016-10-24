class OqgraphDataStructureUndone < ActiveRecord::Migration
  def self.up
    drop_table :ac_paths
    drop_table :ac_reversed_paths
  end

  def self.down
    execute(
      "CREATE TABLE ac_paths ("\
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
      "data_table='ac_parents' origid='parent_id' destid='child_id'"
    )

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
end
