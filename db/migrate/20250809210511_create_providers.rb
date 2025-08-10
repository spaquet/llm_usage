class CreateProviders < ActiveRecord::Migration[8.0]
  def change
    create_table :providers do |t|
      t.string :name, null: false
      t.string :api_key, null: false
      t.string :api_secret, null: false
      t.string :api_url, null: false
      t.string :api_version
      t.integer :status, null: false, default: 0
      t.string :description
      t.string :provider_type

      t.timestamps
    end

    # add_index :providers, :api_key, unique: true, name: "index_providers_on_api_key"
    # add_index :providers, :status, name: "index_providers_on_status"
    # add_index :providers, :provider_type, name: "index_providers_on_provider_type"  # Add this line
  end
end
