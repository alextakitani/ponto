class CreateAhoyTables < ActiveRecord::Migration[8.1]
  def change
    create_table :ahoy_visits do |t|
      t.string :visit_token, null: false
      t.string :visitor_token, null: false
      t.bigint :user_id
      t.string :ip
      t.text :user_agent
      t.text :referrer
      t.string :referring_domain
      t.text :landing_page
      t.string :browser
      t.string :os
      t.string :device_type
      t.string :city
      t.string :region
      t.string :country
      t.decimal :latitude, precision: 10, scale: 8
      t.decimal :longitude, precision: 10, scale: 8
      t.string :utm_source
      t.string :utm_medium
      t.string :utm_term
      t.string :utm_content
      t.string :utm_campaign
      t.string :app_version
      t.datetime :started_at
    end

    add_index :ahoy_visits, :user_id
    add_index :ahoy_visits, :visit_token, unique: true
    add_index :ahoy_visits, :visitor_token

    create_table :ahoy_events do |t|
      t.bigint :visit_id
      t.bigint :user_id
      t.string :name, null: false
      t.text :properties
      t.datetime :time, null: false
    end

    add_index :ahoy_events, :visit_id
    add_index :ahoy_events, :user_id
    add_index :ahoy_events, [ :name, :time ]
    add_index :ahoy_events, [ :visit_id, :name ]
  end
end
