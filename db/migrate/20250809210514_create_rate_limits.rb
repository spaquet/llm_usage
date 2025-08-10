class CreateRateLimits < ActiveRecord::Migration[8.0]
  def change
    create_table :rate_limits do |t|
      t.references :provider, null: false, foreign_key: true
      t.integer :limit
      t.integer :remaining
      t.datetime :reset_at

      t.timestamps
    end

    # add_index :rate_limits, :provider_id, name: "index_rate_limits_on_provider_id"
  end
end
