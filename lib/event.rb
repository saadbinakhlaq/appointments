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

class AvailabilityService
  def initialize(events:)
    @events = events
  end

  def open_slots_for_date(date:)
    openings = events.fetch(Event.kinds[:opening], []).filter_map do |event|
      event.slots if event.opening_valid_for_date?(date)
    end.flatten

    appointments = events.fetch(Event.kinds[:appointment], []).filter_map do |event|
      event.slots if event.appointment_valid_for_date?(date)
    end.flatten

    (Set.new(openings) - Set.new(appointments)).
      to_a.
      sort_by { |time| DateTime.parse(time) }
  end

  private

  attr_reader :events

  def openings_for_date(date)
    openings = events.fetch(Event.kinds[:opening], []).filter_map do |event|
      event.slots if event.opening_valid_for_date?(date)
    end.flatten

    appointments = events.fetch(Event.kinds[:appointment], []).filter_map do |event|
      event.slots if event.appointment_valid_for_date?(date)
    end.flatten

    (Set.new(openings) - Set.new(appointments)).to_a
  end
end

class Event < ActiveRecord::Base
  enum kind: { opening: 'opening', appointment: 'appointment' }
  WEEK = 7.days

  # ---- scopes ----- #
  scope :within, ->(starts_at, ends_at) { where("(starts_at BETWEEN ? AND ?) OR (kind = 'opening' AND weekly_recurring = ?)", starts_at, ends_at, true) }
  scope :ordered, -> { order(:starts_at) }
  # ---- scopes ----- #

  # ---- validations ----- #
  validates :kind, :starts_at, :ends_at, presence: true
  validate :weekly_recurring_by_kind
  validate :starts_at_before_ends_at, if: Proc.new { |event| !event.ends_at.nil? && !event.starts_at.nil? }
  validate :starts_and_ends_on_same_day, if: Proc.new { |event| !event.ends_at.nil? && !event.starts_at.nil? }
  validate :check_appointment_when_slots_available
  validate :is_30_min_slot, if: Proc.new { |event| !event.ends_at.nil? && !event.starts_at.nil? }
  # ---- validations ----- #

  class << self
    def availabilities(start_date)
      end_date = start_date + WEEK

      events = Event.within(start_date.at_beginning_of_day, end_date.at_end_of_day).ordered.group_by(&:kind)

      (0..6).each_with_object({}) do |index, hash|
        date = start_date + index
        hash[(start_date + index).to_s] = AvailabilityService.new(events: events).open_slots_for_date(date: date)
      end
    end
  end

  def opening_valid_for_date?(date)
    if opening? && weekly_recurring? && starts_at.to_date.wday == date.to_date.wday
      true
    elsif opening? && starts_at.to_date == date
      true
    else
      false
    end
  end

  def appointment_valid_for_date?(date)
    appointment? && starts_at.to_date == date ? true : false
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

  private

  # ---- validations ----- #
  def weekly_recurring_by_kind
    if appointment? && weekly_recurring?
      errors.add(:weekly_recurring, "can't be true for appointment")
    end
  end

  def starts_at_before_ends_at
    if ends_at <= starts_at
      errors.add(:ends_at, "can't be before starts_at")
    end
  end

  def starts_and_ends_on_same_day
    if ends_at.to_date != starts_at.to_date
      errors.add(:ends_at, "can't be on a different day")
    end
  end

  def check_appointment_when_slots_available
    if appointment?
      availabilities = Event.availabilities(starts_at.to_date)
      availabilities_for_date = availabilities[starts_at.to_date.to_s]
      available_slot_match = slots.to_set.subset?(availabilities_for_date.to_set)

      if !available_slot_match
        errors.add(:kind, "can't create appointment for no available slots")
      end
    end
  end

  def is_30_min_slot
    seconds_in_min = 60
    time_difference = (ends_at.to_time - starts_at.to_time)/seconds_in_min
    if !(time_difference % 30 == 0)
      errors.add(:ends_at, "is not a 30 min slot")
    end
  end
  # ---- validations ----- #
end