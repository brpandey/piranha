defmodule Piranha.Slot do
  @moduledoc """
  Implements slot abstraction

  Manages a sorted set of boat availability statuses
  Boat statuses correspond to requested boats for this specific time slot

  Efficiently is able to match the best boat given the requested size

  Keeps time interval abstraction as well to keep track
  of time slot particulars

  Handles explicit reconciliation where slots need to be notified
  that an overlapping other time slot has already claimed the same boat

  Module only keeps track of boat ids, not the boat structures 
  themselves in the interest of decoupling
  """

  alias Piranha.{Slot, Interval, Boat, Boat.Status}

  @type t :: %__MODULE__{}

  defstruct id: nil, 
  interval: nil, # time interval (which is "detachable", and has same id value as the slot_id)
  available: 0, customer_count: 0, # availability related
  boat_statuses_by_avail: :gb_sets.new, boat_statuses_by_id: %{}, # availability related
  boat_ids: [] # boat id retrievals


  @doc "Creates new Slot abstraction given unix start time and minutes duration"
  @spec new(integer, integer) :: t
  def new(start, duration)
  when is_integer(start) and is_integer(duration) and duration > 0 do
    time = Interval.new(start, duration)
    %Slot{id: time.id, interval: time}
  end


  @doc "Fetch date key in String YYYY-MM-DD format"
  @spec date(t) :: String.t
  def date(%Slot{interval: time}), do: time.date

  
  @doc "Returns registered boat ids"
  @spec boats(t) :: list
  def boats(%Slot{boat_ids: ids}), do: ids


  @doc "Returns succinct map of slot data"
  @spec dump(t) :: map
  def dump(%Slot{} = s) do
    
    # Grab boat ids from boat availability sorted set
    ids = 
      :gb_sets.to_list(s.boat_statuses_by_avail) 
      |> Enum.map(fn %Boat.Status{id: boat_id} -> boat_id end)
      |> Enum.sort # sort boat ids so that they are alphabetical
    
    # Create generic map
    %{id: s.id, start_time: s.interval.unix_start, 
      duration: s.interval.duration,
      availability: s.available, 
      customer_count: s.customer_count,
      boats: ids}
  end

 
  @doc """
  Registers boat use for time slot.  A register request doesn't guarentee 
  boat use but notifies the boat of an interested client. It also makes it 
  possible for an eventual slot reservation down the line.  

  Assuming the boat is not already reserved at that time by an overlapping 
  slot, we can then request successfully

  Each boat that is requested is added to the inventory of potentially 
  available boats for this slot!
  """

  @spec register(t, Boat.t) :: atom | tuple
  def register(%Slot{} = slot, %Boat{id: boat_id} = boat) when is_binary(boat_id) do

    case Boat.available?(boat, slot.interval) do
      true ->
        # Request boat for slot interval
        # (we only need the interval part of the slot)
        boat = Boat.request(boat, slot.interval)

        # create boat availability status that corresponds to new boat
        # add boat status data to the sorted boat's status set
        
        # Boat can't be shared between multiple bookings or timeslots so we can grab 
        # the entire capacity as available


        boat_status = %Status{available: Boat.capacity(boat), 
                              customer_count: 0, id: boat_id}
        
        updated_avail = 
          :gb_sets.add(
            boat_status, 
            slot.boat_statuses_by_avail
          )

        # Update mapping between boat statuses and their boat ids
        updated_mapping = Map.put(slot.boat_statuses_by_id, boat_id, boat_status)

        # Compute largest available boat as of now
        %Status{available: largest_available} = :gb_sets.largest(updated_avail)

        # Prepend boat id to boat id list
        updated_ids = List.flatten([boat_id], slot.boat_ids)

        # Update slot with updated boats information
        slot = %Slot{ slot | 
                      available: largest_available,
                      boat_statuses_by_avail: updated_avail, # sorted by available spots
                      boat_statuses_by_id: updated_mapping,  # indexed by boat_id to get status
                      boat_ids: updated_ids # plain list of boat ids
                    }

        {:ok, slot, boat}

      false -> :unavailable
    end
  end




  @doc """
  Reserves (books) a boat which best matches the requested size 
  until successful.

  Given a time slot, attempts to reserve space for size number of guests

  If initial boat selected is unavailable, repeatedly tries other
  requested boats until either we have a match or until we've exhausted
  possibilities.
  """


  @spec reserve(t, map, integer) ::
  {:none, t, map} | {:ok, t, map, list}
  def reserve(slot, fleet, size), do: reserve_while(slot, fleet, size)


  @spec reserve_while(t, map, integer) :: 
  {:none, t, map} | {:ok, t, map, list}
  defp reserve_while(%Slot{} = slot, %{} = fleet, size)
  when is_integer(size) and size > 0 do
    
    init_acc = {:unavailable, slot, fleet}
    
    # We keep checking boat availability until we are able to reserve successfully
    
    Enum.reduce_while(Stream.cycle([:ok]), init_acc, fn
      _ok, {_, slot_acc, fleet_acc} ->
        
        case reserve_single(slot_acc, fleet_acc, size) do
          {:unavailable, %Slot{}, %{}} = new_acc -> {:cont, new_acc}
          {:ok, %Slot{}, %{}, _overlaps} = new_acc -> {:halt, new_acc}
          :none -> {:halt, {:none, slot_acc, fleet_acc}}
        end
    end)
  end


  # Attempts to reserve a single boat that best matches the requested size
  # Returns best matching boat based on slot's boat availability

  # Checks first to see if boat is available, if so, attempts
  # to reserve boat.  If successful, returns back tuple with first term
  # :ok.  If boat is available or not updates Slot
  # boat availability information

  # NOTE: Doesn't try to search for other available boats if unsuccessful.
  # Used as single iteration reserve method for reserve_while

  # After a boat reservation is attempted, we update the boat in the fleet 

  @spec reserve_single(t, map, integer) :: 
  :none | {atom, t, map} |  {atom, t, map, list}
  defp reserve_single(%Slot{} = slot, %{} = fleet, size)
  when is_integer(size) and size > 0 do
    
    # Grab boat based on its availability, best matching requested size
    case availability(slot, size) do
      {:ok, %Status{id: boat_id} = status} when is_binary(boat_id) -> 
        
        # Get boat from fleet
        boat = %Boat{} = Map.get(fleet, boat_id)

        # FIRST availability check        
        if Boat.available?(boat, slot.interval) do

          # SECOND availability check
          # Boat is available, now attempt to reserve boat
          case Boat.reserve(boat, slot.interval) do              

            # We tried to reserve but turns out boat is unavailable
            {:unavailable, boat} ->
              slot = update(slot, :unavailable, status)
              fleet = Map.put(fleet, boat_id, boat)
              {:unavailable, slot, fleet}
            {:ok, boat, overlap_list} ->
              slot = update(slot, :available, status, size)
              fleet = Map.put(fleet, boat_id, boat)
              {:ok, slot, fleet, overlap_list}
          end

        else
          # Boat wasn't available, no point in trying to reserve
          slot = update(slot, :unavailable, status)
          {:unavailable, slot, fleet}
        end

      # We couldn't find a boat to match the size by its availability
      :none -> :none
    end
  end
  


  @doc """
  Explicitly reconciles excluded slots with the fact that an overlapping
  slot has already taken their boat.  This would happen naturally when
  these slots attempt to reserve against the boat, but this is the explicit
  method which saves an extra call to reserve.

  It does so by notifying all the excluded overlapping slots 
  if there exists any.  Updates this group which resides in the slots map.
  """

  @spec reconcile(t, atom, map, list) :: map
  def reconcile(%Slot{}, :exclusion, %{} = slots, exclude_ids)
  when is_list(exclude_ids) do
    
    # process through the excluded list of slot_id-boat_id pair tuples,
    # notifying these overlapped slots that they have been excluded from this boat
    
    _slots =
      case exclude_ids do
        # no other slot ids were excluded, no one to notify, return original grouping
        [] -> slots

        pairs ->
          # Reduce through the list of excluded slots
          # Retrieve each of the slots that correspond to the slot ids
          # Notify these slots that they have been excluded from the boat id
          # Update the map on each pass with the updated slot
        
          Enum.reduce(pairs, slots, fn {slot_id, boat_id}, acc ->
            # retrieve slot from timeslot_id
            slot_exc = Map.get(acc, slot_id)
            
            # Assert pattern match is true (that each slot exists for its id)
            slot_id = slot_exc.id

            # Invoke notify routine to update that slot's boat_by_avail
            slot_exc = notify(slot_exc, :exclusion, boat_id)

            # update slot group with new slot exclude value (blows away old copy)
            Map.put(acc, slot_id, slot_exc)
          end)
      end
  end


  # Returns boat availability status that best matches customer size request
  # Efficiently traverses availability sorted set
  # If no matches found returns :none

  @spec availability(t, integer) :: :none | {:ok, Status.t}
  defp availability(%Slot{} = slot, size_request)
  when is_integer(size_request) and size_request >= 1 do

    # Find boat id which matches request size most closely,
    # and that is greater or equal to the request size

    # e.g. if we request for 11 seats and have boats of capacity 10, 13, 19
    # the boat with 13 should be selected
    
    # We create a find key of the Status struct 
    # with the specific available value requested

    find_key = %Status{available: size_request}

    # Returns iterator starting at value or greater than 
    # available: size request

    iterator = :gb_sets.iterator_from(find_key, slot.boat_statuses_by_avail) 
    
    case :gb_sets.next(iterator) do
      :none -> :none # no boat found that matches size request
      {%Status{} = value, _iter} -> {:ok, value} # found matching boat status
    end

  end


  # Notifies slot that boat id is no longer available as it has been
  # successfully reserved by an overlapping slot
  @spec notify(t, atom, String.t) :: t
  defp notify(%Slot{} = slot, :exclusion, boat_id) when is_binary(boat_id) do

    # Fetch boat availability status data corresponding to boat id
    status = %Status{} = Map.get(slot.boat_statuses_by_id, boat_id)

    # Mark that it is no longer available
    _slot = update(slot, :unavailable, status)
  end



  # Helper method to update slot availability data given that the boat
  # we attempted to reserve wasn't available
  @spec update(t, Status.t, atom) :: t
  defp update(%Slot{} = slot, :unavailable, %Status{id: boat_id} = status)
  when is_binary(boat_id) do
    # Remove the boat status from the sorted set of boat statuses
    updated_avail = :gb_sets.delete(status, slot.boat_statuses_by_avail)

    # Update the new boat status reflecting the unbookability
    # Meaning we set available to 0 and customer count to 0
    updated_status = %Status{status | available: 0, customer_count: 0}

    # Store status back in the sorted boat status set
    updated_avail = :gb_sets.add_element(updated_status, updated_avail)            


    # Update mapping between boat statuses and their boat ids
    updated_mapping = Map.put(slot.boat_statuses_by_id, boat_id, updated_status)


    # Compute largest available boat as of now
    %Status{available: largest_available} = :gb_sets.largest(updated_avail)
    
    # Update slot with updated boats data
    %Slot{ slot | 
           boat_statuses_by_avail: updated_avail,
           boat_statuses_by_id: updated_mapping,
           available: largest_available }    
  end


  # Helper method to update slot availability data given that the boat
  # we attempted to reserve was available and reserved successfully
  @spec update(t, Status.t, integer, atom) :: t
  defp update(%Slot{} = slot, :available, %Status{id: boat_id} = status, size)
  when is_binary(boat_id) and is_integer(size) and size > 0 do
    # Remove the previous boat status from the sorted set of boat statuses
    updated_avail = :gb_sets.delete(status, slot.boat_statuses_by_avail)
    
    # Update the new boat status reflecting the new booking
    updated_status = %Status{status | 
                             available: status.available - size, 
                             customer_count: status.customer_count + size}
    
    # Store status back in the sorted boat status set
    updated_avail = :gb_sets.add_element(updated_status, updated_avail)          

    # Update mapping between boat statuses and their boat ids
    updated_mapping = Map.put(slot.boat_statuses_by_id, boat_id, updated_status)

    # Compute largest available boat as of now
    %Status{available: largest_available} = :gb_sets.largest(updated_avail)
    
    # Update slot with updated boats data
    %Slot{ slot | 
           boat_statuses_by_avail: updated_avail, 
           boat_statuses_by_id: updated_mapping,
           available: largest_available,
           customer_count: slot.customer_count + size }    
  end

end
