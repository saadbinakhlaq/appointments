# frozen_string_literal: true

require 'minitest/autorun'
require 'date'

require_relative '../lib/event'

describe Event do
  before { Event.delete_all }

  describe 'scopes' do
    it 'returns events between set dates' do
      event_1 = Event.create(
        kind: :opening,
        starts_at: DateTime.parse('2020-01-10 11:00'),
        ends_at: DateTime.parse('2020-01-10 11:30')
      )

      event_2 = Event.create(
        kind: :appointment,
        starts_at: DateTime.parse('2020-01-10 11:00'),
        ends_at: DateTime.parse('2020-01-10 11:30')
      )

      event_3 = Event.create(
        kind: :opening,
        starts_at: DateTime.parse('2020-01-01 12:00'),
        ends_at: DateTime.parse('2020-01-01 13:30'),
        weekly_recurring: true
      )

      event_4 = Event.create(
        kind: :opening,
        starts_at: DateTime.parse('2020-01-01 11:00'),
        ends_at: DateTime.parse('2020-01-01 11:30')
      )

      events = Event.within(DateTime.parse('2020-01-09 11:00'), DateTime.parse('2020-01-20 11:00')).ordered.to_a
      _(events).must_equal([event_3, event_1, event_2])
    end
  end

  describe 'validates' do
    it 'presence of starts_at' do
      event = Event.new(
        kind: :opening,
        ends_at: DateTime.parse('2020-01-01 13:30')
      )

      _(event.valid?).must_equal(false)
      _(event.errors[:starts_at]).must_equal(["can't be blank"])
    end

    it 'presence of ends_at' do
      event = Event.new(
        kind: :opening,
        starts_at: DateTime.parse('2020-01-01 13:30')
      )

      _(event.valid?).must_equal(false)
      _(event.errors[:ends_at]).must_equal(["can't be blank"])
    end

    it 'presence of kind' do
      event = Event.new(
        starts_at: DateTime.parse('2020-01-01 13:00'),
        ends_at: DateTime.parse('2020-01-01 13:30')
      )

      _(event.valid?).must_equal(false)
      _(event.errors[:kind]).must_equal(["can't be blank"])
    end

    it 'weekly_recurring with kind' do
      event = Event.new(
        kind: :appointment,
        starts_at: DateTime.parse('2020-01-01 13:00'),
        ends_at: DateTime.parse('2020-01-01 13:30'),
        weekly_recurring: true
      )

      _(event.valid?).must_equal(false)
      _(event.errors[:weekly_recurring]).must_equal(["can't be true for appointment"])
    end

    it 'starts_at before ends_at' do
      event = Event.new(
        kind: :opening,
        starts_at: DateTime.parse('2020-01-01 14:00'),
        ends_at: DateTime.parse('2020-01-01 13:30')
      )

      _(event.valid?).must_equal(false)
      _(event.errors[:ends_at]).must_equal(["can't be before starts_at"])
    end

    it 'starts_at and ends_at on same day' do
      event = Event.new(
        kind: :opening,
        starts_at: DateTime.parse('2020-01-01 14:00'),
        ends_at: DateTime.parse('2020-01-02 14:00')
      )

      _(event.valid?).must_equal(false)
      _(event.errors[:ends_at]).must_equal(["can't be on a different day"])
    end

    it 'appointments creation if slots available 1' do
      Event.create(
        kind: :opening,
        starts_at: DateTime.parse('2020-01-01 11:00'),
        ends_at: DateTime.parse('2020-01-01 12:30')
      )

      appointment_event = Event.new(
        kind: :appointment,
        starts_at: DateTime.parse('2020-01-01 14:00'),
        ends_at: DateTime.parse('2020-01-01 14:30')
      )

      _(appointment_event.valid?).must_equal(false)
      _(appointment_event.errors[:kind]).must_equal(["can't create appointment for no available slots"])
    end

    it 'appointments creation if slots available 2' do
      Event.create(
        kind: :opening,
        starts_at: DateTime.parse('2020-01-01 11:00'),
        ends_at: DateTime.parse('2020-01-01 14:30')
      )

      appointment_event = Event.new(
        kind: :appointment,
        starts_at: DateTime.parse('2020-01-01 14:00'),
        ends_at: DateTime.parse('2020-01-01 15:00')
      )

      _(appointment_event.valid?).must_equal(false)
      _(appointment_event.errors[:kind]).must_equal(["can't create appointment for no available slots"])
    end

    it 'appointments creation if slots available 3' do
      Event.create(
        kind: :opening,
        starts_at: DateTime.parse('2020-01-01 11:00'),
        ends_at: DateTime.parse('2020-01-01 14:30')
      )

      appointment_event = Event.new(
        kind: :appointment,
        starts_at: DateTime.parse('2020-01-01 13:00'),
        ends_at: DateTime.parse('2020-01-01 14:00')
      )

      _(appointment_event.valid?).must_equal(true)
      appointment_event.save!
      start_date = appointment_event.starts_at.to_date
      available_slots = Event.availabilities(start_date)
      _(available_slots[start_date.to_s]).must_equal(['11:00', '11:30', '12:00', '12:30', '14:00'])
    end

    it 'slots which are multiple of 30 mins' do
      event = Event.new(
        kind: :opening,
        starts_at: DateTime.parse('2020-01-01 11:00'),
        ends_at: DateTime.parse('2020-01-01 14:11')
      )

      _(event.valid?).must_equal(false)
      _(event.errors[:ends_at]).must_equal(["is not a 30 min slot"])
    end
  end

  describe 'skeleton' do
    before do 
      @start_date = Date.new(2020, 1, 1)
      @availabilities = Event.availabilities(@start_date)
    end

    it 'returns a Hash' do
      _(@availabilities).must_be_instance_of(Hash)
    end

    it 'key is a date string with format YYYY-MM-DD' do
      _(@availabilities.keys.first).must_equal('2020-01-01')
    end

    it 'value is an Array' do
      _(@availabilities.values.first).must_be_instance_of(Array)
    end

    it 'returns the next seven days' do
      _(@availabilities.size).must_equal(7)
    end

    it 'full flow' do
      _(@availabilities['2020-01-01']).must_be_empty
      _(@availabilities['2020-01-02']).must_be_empty
      _(@availabilities['2020-01-03']).must_be_empty
      _(@availabilities['2020-01-04']).must_be_empty
      _(@availabilities['2020-01-05']).must_be_empty
      _(@availabilities['2020-01-06']).must_be_empty
      _(@availabilities['2020-01-07']).must_be_empty
    end
  end

  describe 'openings' do
    it 'one opening' do
      Event.create(
        kind: :opening,
        starts_at: DateTime.parse('2020-01-01 11:00'),
        ends_at: DateTime.parse('2020-01-01 11:30')
      )

      availabilities = Event.availabilities(Date.new(2020, 1, 1))

      _(availabilities['2020-01-01']).must_equal(['11:00'])
    end

    it '30 minutes slots' do
      Event.create(
        kind: :opening,
        starts_at: DateTime.parse('2020-01-01 11:00'),
        ends_at: DateTime.parse('2020-01-01 12:00')
      )

      availabilities = Event.availabilities(Date.new(2020, 1, 1))

      _(availabilities['2020-01-01']).must_equal(['11:00', '11:30'])
    end

    it 'several openings on the same day' do
      Event.create(
        kind: :opening,
        starts_at: DateTime.parse('2020-01-01 11:00'),
        ends_at: DateTime.parse('2020-01-01 12:00')
      )

      Event.create(
        kind: :opening,
        starts_at: DateTime.parse('2020-01-01 14:00'),
        ends_at: DateTime.parse('2020-01-01 15:00')
      )

      availabilities = Event.availabilities(Date.new(2020, 1, 1))

      _(availabilities['2020-01-01']).must_equal(['11:00', '11:30', '14:00', '14:30'])
    end

    it 'format' do
      Event.create(
        kind: :opening,
        starts_at: DateTime.parse('2020-01-01 09:00'),
        ends_at: DateTime.parse('2020-01-01 09:30')
      )

      Event.create(
        kind: :opening,
        starts_at: DateTime.parse('2020-01-01 14:00'),
        ends_at: DateTime.parse('2020-01-01 14:30')
      )

      availabilities = Event.availabilities(Date.new(2020, 1, 1))

      _(availabilities['2020-01-01']).must_equal(['9:00', '14:00'])
    end
  end

  describe 'appointments' do
    before do
      Event.create(
        kind: :opening,
        starts_at: DateTime.parse('2020-01-01 09:00'),
        ends_at: DateTime.parse('2020-01-01 10:00')
      )
    end

    it 'an appointment of one slot' do

      Event.create(
        kind: :appointment,
        starts_at: DateTime.parse('2020-01-01 09:00'),
        ends_at: DateTime.parse('2020-01-01 09:30')
      )

      availabilities = Event.availabilities(Date.new(2020, 1, 1))

      _(availabilities['2020-01-01']).must_equal(['9:30'])
    end

    it 'an appointment of several slots' do
      Event.create(
        kind: :appointment,
        starts_at: DateTime.parse('2020-01-01 09:00'),
        ends_at: DateTime.parse('2020-01-01 10:00')
      )

      availabilities = Event.availabilities(Date.new(2020, 1, 1))

      _(availabilities['2020-01-01']).must_be_empty
    end

    it 'several appointment on the same day' do

      Event.create(
        kind: :appointment,
        starts_at: DateTime.parse('2020-01-01 09:00'),
        ends_at: DateTime.parse('2020-01-01 09:30')
      )

      Event.create(
        kind: :appointment,
        starts_at: DateTime.parse('2020-01-01 09:30'),
        ends_at: DateTime.parse('2020-01-01 10:00')
      )

      availabilities = Event.availabilities(Date.new(2020, 1, 1))

      _(availabilities['2020-01-01']).must_be_empty
    end
  end

  describe 'weekly recurring openings' do
    it 'weekly recurring are taken into account day 1' do
      Event.create(
        kind: :opening,
        starts_at: DateTime.parse('2020-01-01 09:00'),
        ends_at: DateTime.parse('2020-01-01 09:30'),
        weekly_recurring: true
      )

      availabilities = Event.availabilities(Date.new(2020, 1, 1))

      _(availabilities['2020-01-01']).must_equal(['9:00'])
    end

    it 'weekly recurring are recurring' do
      Event.create(
        kind: :opening,
        starts_at: DateTime.parse('2020-01-01 09:00'),
        ends_at: DateTime.parse('2020-01-01 09:30'),
        weekly_recurring: true
      )

      availabilities = Event.availabilities(Date.new(2020, 1, 8))

      _(availabilities['2020-01-08']).must_equal(['9:00'])
    end

    it 'non weekly recurring are not recurring' do
      Event.create(
        kind: :opening,
        starts_at: DateTime.parse('2020-01-01 09:00'),
        ends_at: DateTime.parse('2020-01-01 09:30'),
        weekly_recurring: false
      )

      availabilities = Event.availabilities(Date.new(2020, 1, 8))

      _(availabilities['2020-01-08']).must_be_empty
    end
  end

  describe 'acceptance test' do
    it 'returns availabilities' do
      # -------------Weekly Recurring Events--------------
      Event.create(
        kind: :opening,
        starts_at: DateTime.parse('2020-01-01 09:00'),
        ends_at: DateTime.parse('2020-01-01 10:30'),
        weekly_recurring: true
      )

      Event.create(
        kind: :opening,
        starts_at: DateTime.parse('2020-01-02 09:00'),
        ends_at: DateTime.parse('2020-01-02 10:30'),
        weekly_recurring: true
      )

      Event.create(
        kind: :opening,
        starts_at: DateTime.parse('2020-01-03 09:00'),
        ends_at: DateTime.parse('2020-01-03 10:30'),
        weekly_recurring: true
      )
      # -------------Weekly Recurring Events--------------

      Event.create(
        kind: :opening,
        starts_at: DateTime.parse('2020-01-06 09:00'),
        ends_at: DateTime.parse('2020-01-06 09:30')
      )

      Event.create(
        kind: :opening,
        starts_at: DateTime.parse('2020-01-07 09:00'),
        ends_at: DateTime.parse('2020-01-07 10:30')
      )

      Event.create(
        kind: :appointment,
        starts_at: DateTime.parse('2020-01-07 09:00'),
        ends_at: DateTime.parse('2020-01-07 09:30')
      )

      Event.create(
        kind: :opening,
        starts_at: DateTime.parse('2020-01-09 09:00'),
        ends_at: DateTime.parse('2020-01-09 09:30')
      )

      Event.create(
        kind: :opening,
        starts_at: DateTime.parse('2020-01-10 09:00'),
        ends_at: DateTime.parse('2020-01-10 09:30')
      )

      Event.create(
        kind: :appointment,
        starts_at: DateTime.parse('2020-01-10 09:00'),
        ends_at: DateTime.parse('2020-01-10 09:30')
      )

      availabilities = Event.availabilities(Date.new(2020, 01, 06))
      _(availabilities['2020-01-06']).must_equal(['9:00'])
      _(availabilities['2020-01-07']).must_equal(['9:30', '10:00'])
      _(availabilities['2020-01-08']).must_equal(['9:00', '9:30', '10:00'])
      _(availabilities['2020-01-09']).must_equal(['9:00', '9:30', '10:00'])
      _(availabilities['2020-01-10']).must_equal(['9:30', '10:00'])
      _(availabilities['2020-01-11']).must_be_empty
      _(availabilities['2020-01-12']).must_be_empty
    end
  end

  describe '#slots' do
    it 'returns slots with 30 min interval' do
      event = Event.create(
        kind: :opening,
        starts_at: DateTime.parse('2020-01-01 09:00'),
        ends_at: DateTime.parse('2020-01-01 10:30'),
      )

      _(event.slots).must_equal(['9:00', '9:30', '10:00'])
    end
  end
end
