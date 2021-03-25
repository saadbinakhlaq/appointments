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
  enum kind: { opening: 'opening', appointment: 'appointment' }
  WEEK = 7.days

  scope :within, ->(starts_at, ends_at) { where("(starts_at BETWEEN ? AND ?) OR (kind = 'opening' AND weekly_recurring = ?)", starts_at, ends_at, true) }
  scope :ordered, -> { order(:starts_at) }

  class << self
    def availabilities(start_date)
      end_date = start_date + WEEK

      events = Event.within(start_date.at_beginning_of_day, end_date.at_end_of_day).ordered.group_by(&:kind)

      (0..6).each_with_object({}) do |index, hash|
        date = start_date + index
        hash[(start_date + index).to_s] = open_slots_per_day(events, date)
      end
    end

    private

    def open_slots_per_day(events, date)
      openings = events.fetch(Event.kinds[:opening], []).map do |event|
        event.slots
      end.flatten
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