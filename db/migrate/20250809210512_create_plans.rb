class CreatePlans < ActiveRecord::Migration[8.0]
  def change
    create_table :plans do |t|
      t.references :provider, null: false, foreign_key: true
      t.string :name
      t.jsonb :details

      t.timestamps
    end

    # add_index :plans, :provider_id, name: "index_plans_on_provider_id"
  end
end
