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
      (0..6).each_with_object({}) do |index, hash|
        hash[(start_date + index).to_s] = open_slots_per_day
      end
    end

    private

    def open_slots_per_day
      event = Event.first

      if event
        event.slots
      else
        []
      end
    end
  end

  def slots
    slots = []
    temp = starts_at

    while temp < ends_at
      slots << temp.strftime('%-H:%M')
      temp += 30.minutes
    end
    slots
  end
end