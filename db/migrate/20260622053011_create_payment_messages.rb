class CreatePaymentMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_messages do |t|
      t.string :stripe_payment_intent_id, null: false
      t.string :customer_name, null: false
      t.integer :amount, null: false
      t.text :message, null: false

      t.timestamps
    end

    add_index :payment_messages, :stripe_payment_intent_id, unique: true
  end
end
