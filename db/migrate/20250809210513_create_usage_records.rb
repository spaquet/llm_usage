class CreateUsageRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :usage_records do |t|
      t.references :provider, null: false, foreign_key: true
      t.integer :user_id
      t.integer :request_count
      t.datetime :timestamp

      t.timestamps
    end

    add_index :usage_records, :provider_id, name: "index_usage_records_on_provider_id"
  end
end
