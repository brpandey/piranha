defmodule Piranha.Interval do
  @moduledoc """
  Implements time interval abstraction used in slot abstraction
  
  Uses DateTime and Timex to manage start and finish date times
  Duration is minutes integer value

  Generates "normalized" keys so that if we want to store the
  interval in a map or so, we can easily store for each of its
  consecutive half hour intervals.

  So if the interval is from 2:13 - 3:50, we can store
  it for the consecutive half hour intervals of 2:00, 2:30, 3:00, 3:30

  Also provides function to determine if two intervals overlap
  """
  
  use Timex
  alias Piranha.Interval
  
  @type t :: %__MODULE__{}

  @half_hour 30

  # used to create short, unique stringified slot interval ids
  @hash_id Hashids.new([salt: "timeslot", min_len: 5])
  
  defstruct id: nil, 
  duration: nil, date: nil, 
  start: nil, finish: nil, # timestamps in Datetime
  unix_start: nil, unix_finish: nil # unix timestamp integers
  

  @doc "Create new interval given start time and duration"
  @spec new(integer, integer) :: t
  def new(start, duration)
  when is_integer(start) and is_integer(duration) and duration > 0 do
    
    # Create id
    
    id = Hashids.encode(@hash_id, [start, duration])
    
    # Convert start time which is a unix integer timestamp into DateTime
    {:ok, start_dt} = DateTime.from_unix(start)
    
    # Add duration to the start time to get finish time in DateTime form
    # finish is used to help determine overlaps
    finish_dt = Timex.shift(start_dt, minutes: duration)
    finish_unix = DateTime.to_unix(finish_dt)

    date = start_dt |> DateTime.to_date |> Date.to_string

    %Interval{id: id, unix_start: start, unix_finish: finish_unix,
              start: start_dt, finish: finish_dt, duration: duration, date: date}
  end
      
  @doc """
  Creates list of consecutive per half hour bucket keys corresponding 
  to interval, starting on the hour or half hour bucket

  So if the interval is from 2:13 - 3:50, the start (hour) keys are
  [2:00, 2:30, 3:00, 3:30]

  Or if the interval is from 2:00 - 3:30, the start (hour) keys would be
  [2:00, 2:30, 3:00]
  """

  @spec bucket_keys(Interval.t) :: [String.t]
  def bucket_keys(%Interval{start: %DateTime{} = start, duration: duration})
  when is_integer(duration) do
    
    # Check if start minute is on the hour 00 or 30
    already_aligned =
      if(Kernel.rem(start.minute, @half_hour) == 0) do
        true
      else
        false
      end
    
    # Given a slot, generate interval start keys for the slot that 
    # reflect the the half hour increments normalized
    
    # Using half hour granularity, we
    # normalize date time to be on the hour or on the half hour
    
    # If the time slot start time is 
    
    # 2019-05-11 00:42, normalize it to the key "2019-05-11 00:30"
    # 2019-05-11 00:18, normalize it to the key "2019-05-11 00:00"
    
    # Each key's bucket then contains a half hours worth of potential time slots
    
    normalized_minute = div(start.minute, @half_hour) * @half_hour
    normalized_start = %DateTime{start | minute: normalized_minute}
    
    # For example, if the duration is for 120 minutes, here are the keys
    # (plus an extra key for overhangs provided the start time 
    # is not already aligned meaning not on the :00 or :30 minute)
    
    # ["2019-05-11 00:30", "2019-05-11 01:00", "2019-05-11 01:30", 
    # "2019-05-11 02:00", "2019-05-11 02:30"]
    
    # We set right_open to false to get the extra 5th time slot 2:30 to serve
    # as a buffer, so if we started at :42 in reality we would finish at
    # 2:42, and the extra slot from 2:30-3:00 takes care of the overhang
    
    # However if we were already aligned (starting at :00 or :30)), 
    # and say we started at :30, then we wouldn't need the overhang and would 
    # get the following interval start keys
    
    # ["2019-05-11 00:30", "2019-05-11 01:00", "2019-05-11 01:30", "2019-05-11 02:00"]
    
    _keys = 
      Timex.Interval.new(from: normalized_start, until: [minutes: duration], 
                   right_open: already_aligned)
      |> Timex.Interval.with_step([minutes: @half_hour])
      |> Enum.map(&Timex.format!(&1,  "{YYYY}-{0M}-{D} {h24}:{m}"))        
  end
      
      
      
  @doc """
  Handles all the interval overlap cases to flag with two intervals overlap.
  Note: The interval order doesn't matter, as to which timeslot is t1 or t2
  """
  @spec overlap?(t, t) :: boolean
  def overlap?(%Interval{} = t1, %Interval{} = t2) do
    
    # This handles these cases
    
    # 1)
    #     X------Y
    #         A-----B
    # 2)
    #         X------Y
    #     A-----B
    # 3)
    #        A-----B
    #     X------------Y
    # 4)
    #     X-----------Y
    #        A-----B
    #
    # 5) and non-overlapping case
    #     X------Y            M-----N
    #               A-----B
    
    # Periods that just touch each other e.g. t1.finish = 2:00
    # and t2.start = 2:00 are not considered overlapping
    
    # Thus we don't use <= but instead < or conversely, >= but instead >
    
    cond do
      (t1.unix_start < t2.unix_finish and t1.unix_finish > t2.unix_start) -> true
      true -> false 
    end    
  end
  
end
