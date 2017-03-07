require Amnesia
use Amnesia

alias Piranha.{Boat, Slot}
alias Amnesia.Selection

# Piranha.Database module utilizes the built-in Mnesia database to store 
# Time Slot Appointment entries and Boat Vessel entries

# Rather than making many different tables, fields, indexes, we put more of the 
# complexity into the Boat and Slot abstractions and allow the tables to store 
# these blobs while providing simple access and update routines..

defdatabase Piranha.Database do


  # Define Appointment table which fetches and stores Slot.t terms
  deftable Appointment, [:id, :date, :slot], index: [:date], type: :set do 
		@type t :: %Appointment{id: String.t, date: String.t, slot: Slot.t}    


    # CREATE
    
    @doc """
    Add new appointment entry information, returning new time slot
    """
    @spec add(integer, integer) :: Slot.t
    def add(start_time, duration)
    when is_integer(start_time) and is_integer(duration) do
            
      slot = %Slot{} = Slot.new(start_time, duration)
            
      entry = %Appointment{id: slot.id, date: slot.interval.date, slot: slot} 
      appt = %Appointment{} = entry |> Appointment.write
      
      appt.slot
    end


    # READ

    @doc "Retrieve all time slots associated with date"
    @spec lookup(atom, String.t) :: list
    def lookup(:date, date) when is_binary(date) do

      # read_at uses the secondary index :date
      list = Appointment.read_at(date, :date)

      # get Slot dump version for each slot
      _slots = Enum.map(list, fn %Appointment{slot: %Slot{} = slot} -> slot end)      
    end


    @doc "Retrieve time slot by id"
    @spec lookup(atom, String.t) :: Slot.t
    def lookup(:id, id) when is_binary(id) do

      # uses the primary key index
      appt = %Appointment{} = Appointment.read(id) 

      appt.slot
    end
    

    @doc "Retrieve time slots by ids"
    @spec lookup(atom, list) :: map
    def lookup(:ids, ids) when is_list(ids) do

      # return map of slots from slot_ids list
      _slots = 
        Enum.reduce(ids, %{}, fn id, acc ->
          slot = %Slot{} = lookup(:id, id)
          Map.put(acc, id, slot)
        end)      
    end


    # UPDATE

    @doc "Update with updated Slot"
    @spec update(atom, Slot.t) :: :ok
    def update(:slot, %Slot{} = slot) do

      entry = %Appointment{id: slot.id, date: slot.interval.date, slot: slot}
      %Appointment{} = entry |> Appointment.write

      :ok
    end


    @doc "Update calendar with map of updated Slots"
    @spec update(atom, map) :: :ok
    def update(:slots, %{} = slots) do
      
      # Map, updating each slot value
      
      Enum.map(slots, fn {_k, %Slot{} = v} ->
        :ok = update(:slot, v) # Invoke single update function
      end)

      :ok
    end
    

  end


  # Define Vessel table which fetches and stores Boat.t terms

  deftable Vessel, [:id, :boat], type: :set do
    @type t :: %Vessel{id: String.t, boat: Boat.t}


    # CREATE

    @doc "Add new boat entry, returning new boat"
    @spec add(String.t, integer) :: Boat.t
    def add(name, capacity)
    when is_binary(name) and is_integer(capacity) do
      
      boat = %Boat{} = Boat.new(name, capacity)

      entry = %Vessel{id: boat.id, boat: boat}
      vessel = %Vessel{} = entry |> Vessel.write

      vessel.boat
    end


    # READ

    @doc "Retrieve boat given boat id"
    @spec lookup(atom, String.t) :: Boat.t
    def lookup(:id, id) when is_binary(id) do

      # uses the primary key index
      vessel = %Vessel{} = Vessel.read(id) 

      vessel.boat
    end


    @doc "Retrieve boats given boats id list"
    @spec lookup(atom, list) :: map
    def lookup(:ids, ids) when is_list(ids) do
      
      # return map of boats from boat_ids list
      _boats =
        Enum.reduce(ids, %{}, fn id, acc ->
          boat = %Boat{} = lookup(:id, id)
          Map.put(acc, id, boat)
        end)
    end
    

    @doc "Return all boat values"
    @spec list() :: list
    def list() do
      
      # we have an empty guard clause, and only select the boat field (#2)
      query = Vessel.select([{{Vessel, :'$1', :'$2'}, [], [:'$2']}])
	    Selection.values(query)
    end

    
    @doc "Update with updated boat"
    @spec update(atom, Boat.t) :: :ok
    def update(:boat, %Boat{} = boat) do

      entry = %Vessel{id: boat.id, boat: boat}
      %Vessel{} = entry |> Vessel.write

      :ok
    end


    @doc "Update with map of updated boats"
    @spec update(atom, map) :: :ok
    def update(:boats, %{} = boats) do
      
      # Map updating each boat value
      Enum.map(boats, fn {_k, %Boat{} = v} ->
        :ok = update(:boat, v) # Invoke single update function
      end)

      :ok
    end

  end # End deftable
end # End defdatabase


defmodule Mix.Tasks.Install do
  use Mix.Task
  use Piranha.Database

  def run(_) do
    Amnesia.Schema.create
    Amnesia.start
    Piranha.Database.create(disk: [node])
    Piranha.Database.wait
  end
end

defmodule Mix.Tasks.Uninstall do
  use Mix.Task
  use Piranha.Database

  def run(_) do
    Amnesia.start
    Piranha.Database.destroy
    Amnesia.stop
    Amnesia.Schema.destroy
  end
end
