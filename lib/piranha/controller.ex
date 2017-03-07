defmodule Piranha.Controller do
  @moduledoc """
  Map requests to appropriate Amnesia transaction

  Could be further split up into separate
  controllers: Boat, Slot, Assignment, Booking
  but for simplicity kept as one.
  """

  require Logger
  require Amnesia

  use Amnesia
  use Piranha.Database

  alias Piranha.{Database.Appointment, Database.Vessel, Slot, Boat}



  @doc "Create and return new boat"
  @spec create(atom, String.t, integer) :: map
  def create(:boat, name, capacity)
  when is_binary(name) and is_integer(capacity) do
    
    Logger.debug("Reached boat create, name #{name} capacity #{capacity}")

    boat = %Boat{} = Amnesia.transaction do
      Vessel.add(name, capacity)
    end

    Logger.debug("Finished amnesia transaction, result is #{inspect boat}")

    # return boat
    Boat.dump(boat)
  end
 


  @doc "Create and return new time slot"
  @spec create(atom, integer, integer) :: map
  def create(:timeslot, start_time, duration)
  when is_integer(start_time) and is_integer(duration) do

    Logger.debug("Reached timeslot create, start_time #{start_time} duration #{duration}")


    slot = %Slot{} = Amnesia.transaction do
      Appointment.add(start_time, duration)
    end

    Logger.debug("Finished amnesia transaction, result is #{inspect slot}")

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
    boats = Enum.map(boats, fn b -> Boat.dump(b) end)

    Logger.debug("Finished amnesia transaction, result is #{inspect boats}")

    boats
  end



  @doc "Retrieve time slots by date key"
  @spec get(atom, String.t) :: list
  def get(:timeslots, date) when is_binary(date) do


    slots = Amnesia.transaction do
      Appointment.lookup(:date, date)
    end

    slots = Enum.map(slots, fn %Slot{} = s -> Slot.dump(s) end)
    
    Logger.debug("Finished amnesia transaction, result is #{inspect slots}")

    slots
  end



  @doc "Register boat for timeslot interval period"
  def register(:boat_timeslot, timeslot_id, boat_id)
  when is_binary(timeslot_id) and is_binary(boat_id) do

    Logger.debug("Reached register, timeslot_id #{timeslot_id}, boat_id #{boat_id}")

    Amnesia.transaction do
      slot = %Slot{} = Appointment.lookup(:id, timeslot_id)
      boat = %Boat{} = Vessel.lookup(:id, boat_id)

      Logger.debug("About to register slot with boat")

      case Slot.register(slot, boat) do
        {:ok, slot, boat} ->

          Logger.debug("Registered slot with boat successfully!")

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
      {result, slot, boats, exclude_pairs} = Slot.reserve(slot, boats, size)

      # update db with the updated boats
      # update the slot in the db now that we've made the reservation
      :ok = Vessel.update(:boats, boats)
      :ok = Appointment.update(:slot, slot)


      # Part 2: Reconcile excluded slots properly

      # Now start the process of reconciling the excluded slots with 
      # the fact that they no longer have one of their boats available
      
      # retrieve slot_ids list from slot_ids - boat_ids tuple pairs list
      # handles empty list with returning two "unzipped" empty lists
      {slot_ids, _boat_ids}  = Enum.unzip(exclude_pairs)
      
      # retrieve map of slots from slot_ids list
      exc_slots = Appointment.lookup(:ids, slot_ids)
      
      # update the excluded slots so that they have accurate
      # info now on the just reserved boat's non-availability
      
      exc_slots = Slot.reconcile(slot, :exclusion, exc_slots, exclude_pairs)
      
      # update the now reconciled excluded slots into the Appointments table
      :ok = Appointment.update(:slots, exc_slots)

      Logger.debug("Finished amnesia transaction, result is #{inspect result}")

      result

    end


  end

end
