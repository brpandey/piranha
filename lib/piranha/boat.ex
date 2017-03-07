defmodule Piranha.Boat do
  @moduledoc """
  Module manages boat availability keeping track of which slots
  have declared interest in the boat and at what time(s).  

  Furthermore, the module keeps a list of which time slots have made successful
  bookings as well as those overlapping time slots that have been consequently
  blocked out.

  If there are two overlapping time slots that have a use request with
  this boat, then the first slot to reserve the boat through a booking
  receives exclusive use of the boat.

  Requested slot use is stored in a map.  This constitutes the boat's 
  half of the boat <-> slot registration.  

  The boat knows about the slots that are interested in using the boat at 
  the given slot time interval.  The use requests map is indexed by 
  per half hour timestamp key(s).

  After a request registration is made, a boat may be reserved by the 
  time slot for actual use.

  Confirmation stores confirmed time slot boat bookings for actual use.

  Exclusion contains the time slot ids that we aren't able to book,
  because the boat is in use by an overlapping time slot

  Module only keeps track of static intervals and slot/interval ids, 
  not the slot structures themselves, in the interest of decoupling
  """


  alias Piranha.{Boat, Interval}


  @type t :: %__MODULE__{}

  # used to create short, unique stringified boat ids
  @hash_id Hashids.new([salt: "boat", min_len: 5])


  defstruct id: nil, name: nil, capacity: 0, 
  requests_by_time: Map.new, exclusion: Map.new, confirmation: Map.new

  
  defmodule Status do
    @moduledoc "Helper module used to store Boat availability info"
    @type t :: %__MODULE__{}

    defstruct id: nil, available: 0, customer_count: 0
  end


  @doc "Creates new boat given boat name and capacity"
  @spec new(String.t, integer) :: t
  def new(name, capacity)
  when is_binary(name) and is_integer(capacity) and capacity > 0 do
    
    # Generate numeric id from capacity and boat name 
    token = List.flatten([capacity], String.to_charlist(name))

    # Generate short, unique, non-sequential id
    id = Hashids.encode(@hash_id, token)
    
    # Return new boat
    %Boat{id: id, name: name, capacity: capacity}
  end


  @doc "Returns boat capacity"
  @spec capacity(t) :: integer
  def capacity(%Boat{capacity: capacity}), do: capacity


  @doc "Returns succinct map of boat data"
  @spec dump(t) :: map
  def dump(%Boat{} = b) do
    %{id: b.id, capacity: b.capacity, name: b.name}
  end


  @doc """
  Simple check whether boat is available given interval.
  Based on previous booking attempts across time slots for given boat.
  """
  @spec available?(t, Interval.t) :: boolean
  def available?(%Boat{} = boat, %Interval{} = interval) do

    # Check to see if time slot is listed on the "exclusion" /
    # unbookable list 

    # Invert the value, as exclusion = true means not available :)

    excluded = Map.has_key?(boat.exclusion, interval.id)

    # if not in exclusion, look to see if interval overlaps 
    # with a slot already booked (hence not bookable)

    # (this is for the potential time slot registries
    # before they even register with the boat)

    if(true == excluded) do
      false
    else
      list = overlaps(boat, interval)
      flag = confirmed?(boat, list)

      not(flag)
    end

  end


  @doc """
  Catalogues "use request" for boat on requested time slot interval

  Does not guarantee boat will be available during interval, 
  just setups up registration association and appropriate boat state.

  If time slot A (the requestor), makes a reservation booking 
  before an already registered time slot B AND if they both happen 
  to be overlapping in time, then time slot A will exclusively 
  have the boat for that period.

  Thus, boat use is on a First Reserve First Serve Basis with
  request registration being the underlying requirement
  """
  @spec request(t, Interval.t) :: t
  def request(%Boat{} = boat, %Interval{} = time) do

    # Sanity check we don't already have this interval
    false = registered?(boat, time)

    # Get the set of normalized keys for time interval
    bucket_keys = Interval.bucket_keys(time)

    # We insert the value (the time slot) with its multiple interval keys

    # Put slot into MapSet, as we have space for multiple requests_by_time in
    # this bucket interval period
    
    appts = 
      Enum.reduce(bucket_keys, boat.requests_by_time, fn
        key, acc ->    
          # a) Just in case this value is empty on first access,
          # we specify a new MapSet as default
          
          # b) Put interval into MapSet (either empty or already populated)
          # Basically intervals that fall within the same half hour are
          # in the same set as they "overlap"
          
          # c) This makes it easier to determine which intervals to 
          # flag as unbookable later during reservation
          set = Map.get(acc, key, MapSet.new) |> MapSet.put(time)
          Map.put(acc, key, set)
      end)    

    %Boat{boat | requests_by_time: appts}
  end

  # Checks if the time slot has already been registered
  defp registered?(%Boat{} = boat, %Interval{} = time) do

    # Just grab first bucket key, to see if time interval is already registered
    first_bucket_key = Interval.bucket_keys(time) |> List.first

    case Map.get(boat.requests_by_time, first_bucket_key, nil) do
      nil -> false
      %MapSet{} = set -> MapSet.member?(set, time)
    end
  end


  @doc """
  Reserve attempts to reserve the boat for the given time slot interval.
  The time slot must already have been registered via the request method.

  Looks at any overlapping time slots compared to the passed in time slot

  If there are no overlappings, then we are free to reserve the boat. 
  If there are overlappings, check to see if any of them have already 
  been booked. If so we are unable to reserve the boat, if they haven't 
  been booked, then we can still reserve the boat for this time slot!

  Actual boat use is on a First Reserve First Serve Basis with
  registration being the underlying requirement
  """
  @spec reserve(t, Interval.t) :: {atom, t} | {atom, t, list}
  def reserve(%Boat{id: boat_id} = boat, %Interval{id: slot_id} = time) do

    # Quick assert that we have already registered 
    # this time slot id with this boat
    true = registered?(boat, time)

    # Before we reserve this boat, ensure that the overlapping time intervals
    # for this boat aren't already booked! 

    # For instance:
    # If time interval A is from 3-4:30 and time interval B is from 4-5
    # And, time slot A is already using the boat, then time slot B needs to be
    # added to the exclusion list (it is un-bookable)

    # If not, then the boat is still available

    overlap_slots = overlaps(boat, time)
    boat_already_taken = confirmed?(boat, overlap_slots)

    case boat_already_taken do
      true ->
        # Mark this time slot id as unbookable since the boat is being
        # used by an overlapping time slot -- add to exclusion 
        updated_exclusion = Map.put(boat.exclusion, slot_id, true)        

        # Update boat
        boat = Kernel.put_in(boat.exclusion, updated_exclusion)
        
        {:unavailable, boat}
      false ->
        # The boat is not already taken, so make the booking!
        updated_bookings = Map.put(boat.confirmation, slot_id, true)
        
        # Mark the other overlapping slots as unbookable now,
        # since we booked first -- add to the exclusion list!

        # Also keep track of just the exclusion overlap delta on this pass, so we can
        # pass it back for notification higher up the call stack

        # Meaning: track just these slot ids that have been overlapped 
        # on this boat because of this specific booking. Record this as 
        # a tuple {slot_id, boat_id} and store into a list

        {updated_exclusion, list_exclusion_delta} = 
          Enum.reduce(overlap_slots, {boat.exclusion, []}, fn 
            (%Interval{id: overlap_id}, {map_acc, delta_acc}) ->
              map_acc = Map.put(map_acc, overlap_id, true)
              delta_acc = List.flatten([{overlap_id, boat_id}], delta_acc)
            
              # return both accumulators
              {map_acc, delta_acc}
          end)
        
        # Update boat
        boat = %Boat{ boat | exclusion: updated_exclusion, 
                      confirmation: updated_bookings}

        {:ok, boat, list_exclusion_delta}
    end

  end

  # Generates list of overlapping time slots 
  # (without using an interval search tree but a hashtable and sets)

  # Determines what other timeslots are overlapping timeslots relative
  # to our source timeslot.  Since the timeslots are converted into 
  # per half hour keys either on the hour or half hour, we basically 
  # generate the set of all overlapping time slots which reside on the
  # same time slot half hour buckets.  We then double-check that those
  # time slots overlap
  @spec overlaps(t, Interval.t) :: list
  defp overlaps(%Boat{} = boat, %Interval{} = source) do

    bucket_keys = Interval.bucket_keys(source)

    # Given set of keys, grab the Set for each key
    # Merge sets together and do double-check to confirm which timeslots overlap

    # For example if the source time slot is from 3-4:30 we look in the 
    # boat.requests_by_time map to generate the overlapping set of timeslots

    # boat.requests_by_time
    # 3:00 -> SlotF, SlotB
    # 3:30 -> SlotB
    # 4:00 -> SlotD
    # 4:30 -> SlotD, SlotM

    # So we have a set of SlotB, SlotD, SlotF, and SlotM
    # then we run the Time Slot overlap function on all just to account
    # for boundary conditions if say SlotF ends before our Source Slot starts
    # or SlotM starts after our Source Slot finishes! 

    overlap_set = 
      Enum.reduce(bucket_keys, MapSet.new, fn key, acc ->
        # Grab all time slots for bucket, reflected by each set
        set = %MapSet{} = Map.get(boat.requests_by_time, key, MapSet.new) 
        MapSet.union(set, acc) # merge sets together
      end)

    # Don't include the original time slot in the overlap set

    overlap_set = MapSet.delete(overlap_set, source)

    # Check whether the time slots in the overlap set really overlap
    # with the passed in source time slot

    _overlaps = 
      Enum.reduce(overlap_set, [], fn %Interval{} = other, acc -> 
        case Interval.overlap?(source, other) do
          true -> List.flatten([other], acc) # add time slot to overlaps acc
          false -> acc
        end
      end)
  end


  # Helper to determine if any in interval list has already been confirmed
  @spec confirmed?(t, list) :: boolean
  defp confirmed?(%Boat{} = boat, intervals) when is_list(intervals) do
    
    case intervals do
      [] -> false
      values when is_list(values) -> 
        
        # If any of these (overlapping) timeslot intervals are 
        # booked with this boat, then we indicate that the
        # boat is already booked
        
        # So, query confirmed bookings to check if the boat 
        # has already been booked by any of these slot intervals
        
        # If it has: return true, else false!
        Enum.any?(values, fn (%Interval{id: slot_id}) -> 
          Map.has_key?(boat.confirmation, slot_id)
        end)
    end
  end
end
