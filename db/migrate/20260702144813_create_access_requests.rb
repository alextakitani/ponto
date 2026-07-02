class CreateAccessRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :access_requests do |t|
      # Pré-conta: NÃO tem user_id (fica fora do isolamento por usuário — Q24).
      t.string :email, null: false
      t.string :name
      t.text :note
      t.string :status, null: false, default: "pending"

      t.timestamps
    end

    add_index :access_requests, :email
  end
end
