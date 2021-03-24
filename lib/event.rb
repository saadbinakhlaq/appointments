# frozen_string_literal: true

require 'sqlite3'
require 'active_record'

ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: ':memory:'
)

ActiveRecord::Schema.define do
  create_table :events do |t|
    t.datetime :starts_at, null: false
    t.datetime :ends_at, null: false
    t.string :kind, null: false
    t.boolean :weekly_recurring, null: false, default: false
  end
end

class Event < ActiveRecord::Base
  class << self
    def availabilities(start_date)
      # Implement your algorithm here. Create as many methods as you like, but no extra files please.
    end
  end
end