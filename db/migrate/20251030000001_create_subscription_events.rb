class CreateSubscriptionEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :subscription_events, id: :uuid do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid
      t.references :subscription, foreign_key: true, type: :uuid
      t.string :event_type, null: false
      t.jsonb :event_data, default: {}
      t.datetime :occurred_at, null: false, default: -> { "CURRENT_TIMESTAMP" }

      t.timestamps
    end

    add_index :subscription_events, :event_type
    add_index :subscription_events, :occurred_at
    add_index :subscription_events, [ :family_id, :event_type ]
  end
end
