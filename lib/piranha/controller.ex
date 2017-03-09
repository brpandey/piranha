defmodule Piranha.Controller do
  @moduledoc """
  Map requests to appropriate Amnesia transaction

  Could be further split up into separate
  controllers: Boat, Slot, Assignment, Booking
  but for simplicity kept as one.
  """

  require Amnesia

  use Amnesia
  use Piranha.Database

  alias Piranha.{Database.Appointment, Database.Vessel, Slot, Boat}



  @doc "Create and return new boat"
  @spec create(atom, String.t, integer) :: map
  def create(:boat, name, capacity)
  when is_binary(name) and is_integer(capacity) do
    
    boat = %Boat{} = Amnesia.transaction do
      Vessel.add(name, capacity)
    end

    # return boat
    Boat.dump(boat)
  end
 


  @doc "Create and return new time slot"
  @spec create(atom, integer, integer) :: map
  def create(:timeslot, start_time, duration)
  when is_integer(start_time) and is_integer(duration) do

    slot = %Slot{} = Amnesia.transaction do
      Appointment.add(start_time, duration)
    end

    # return slot
    Slot.dump(slot)
  end


  @doc "Retrieve list of boat inventory"
  @spec get(atom) :: list
  def get(:boats) do

    boats = Amnesia.transaction do
      Vessel.list()
    end

    # get Boat dump version for each boat
    Enum.map(boats, fn b -> Boat.dump(b) end)
  end



  @doc "Retrieve time slots by date key"
  @spec get(atom, String.t) :: list
  def get(:timeslots, date) when is_binary(date) do

    slots = Amnesia.transaction do
      Appointment.lookup(:date, date)
    end

    # get Slot dump version for each slot
    Enum.map(slots, fn %Slot{} = s -> Slot.dump(s) end)
  end



  @doc "Register boat for timeslot interval period"
  def register(:boat_timeslot, timeslot_id, boat_id)
  when is_binary(timeslot_id) and is_binary(boat_id) do

    Amnesia.transaction do
      slot = %Slot{} = Appointment.lookup(:id, timeslot_id)
      boat = %Boat{} = Vessel.lookup(:id, boat_id)

      case Slot.register(slot, boat) do
        {:ok, slot, boat} ->

          Appointment.update(:slot, slot)
          Vessel.update(:boat, boat)
          :ok

        :unavailable -> :unavailable
      end
    end

  end



  @doc "Make new booking"
  @spec make(atom, String.t, integer) :: atom
  def make(:booking, timeslot_id, size)
  when is_binary(timeslot_id) and is_integer(size) do

    Amnesia.transaction do
      # Part 1: Make booking (e.g. Slot.reserve)

      # retrieve slot from timeslot_id
      slot = %Slot{} = Appointment.lookup(:id, timeslot_id)
      
      # retrieve boat ids from timeslot
      boat_ids = Slot.boats(slot)
      
      # return a subset map of just these boat ids
      # these contain the possible actual boats that could be booked
      boats = %{} = Vessel.lookup(:ids, boat_ids)

      # make the booking
      result = Slot.reserve(slot, boats, size)

      # update db with the updated boats
      # update the slot in the db now that we've made the reservation
      :ok = Vessel.update(:boats, elem(result, 2)) # extract boats from pos 2, 0 based tuple
      :ok = Appointment.update(:slot, elem(result, 1)) # extract slot from pos 1, 0 based tuple
      

      case result do
        {code, _slot, _boats} when code in [:none, :unavailable] -> code
        {code, _slot, _boats, exclude_pairs} when code in [:ok] -> 
          handle_exclusion(exclude_pairs)
          code
      end
        
    end # transaction end

  end


  # Helper to reconcile excluded slots 
  # MUST be called within a transaction
  @spec handle_exclusion(list) :: :ok
  defp handle_exclusion(exclude_pairs) when is_list(exclude_pairs) do

      # Conditional Part 2: Reconcile excluded slots properly

      # Now start the process of reconciling the excluded slots with 
      # the fact that they no longer have one of their boats available
      
      # retrieve slot_ids list from slot_ids - boat_ids tuple pairs list
      # handles empty list with returning two "unzipped" empty lists

      if(Enum.count(exclude_pairs) > 0) do

        {slot_ids, _boat_ids}  = Enum.unzip(exclude_pairs)
      
        # retrieve map of slots from slot_ids list
        exc_slots = Appointment.lookup(:ids, slot_ids)
        
        # update the excluded slots so that they have accurate
        # info now on the just reserved boat's non-availability
        
        exc_slots = Slot.reconcile(%Slot{}, :exclusion, exc_slots, exclude_pairs)
        
        # update the now reconciled excluded slots into the Appointments table
        :ok = Appointment.update(:slots, exc_slots)
      end
    
      :ok
  end

end
