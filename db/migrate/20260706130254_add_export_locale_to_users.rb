class AddExportLocaleToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :export_locale, :string, null: true
  end
end
