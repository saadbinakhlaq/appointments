# Intro

Algorithm that returns the availabilities of a calendar depending on openings and the scheduled events.
The methods takes a start date and looks for availabilities over the next 7 days.

There are 2 kinds of events
Opening events: These are either for a specific day or a weekly recurring
Appointment events: These are the times when the doctor is already booked

```
Testing

$ ruby test/events_test.rb
```