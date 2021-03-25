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
      (0..6).each_with_object({}) do |index, hash|
        hash[(start_date + index).to_s] = open_slots_per_day
      end
    end

    private

    def open_slots_per_day
      events = Event.all

      if events.present?
        events.map(&:slots).flatten
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