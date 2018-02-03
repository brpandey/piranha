defmodule Piranha.Worker do
  @moduledoc """
  Intermediary between web and db, to queue requests as necessary

  Single point of failure here, but illustrates the need for a
  queueing and pooling layer to synchronize requests and provide scalability
  """

  use GenServer
  alias Piranha.Controller

  @doc "Start worker"
  @spec start_link :: GenServer.on_start()
  def start_link() do
    GenServer.start_link(__MODULE__, [], name: :piranha_worker)
  end

  @doc "Create and return new boat"
  @spec create(atom, String.t(), integer) :: map
  def create(:boat, name, capacity)
      when is_binary(name) and is_integer(capacity) do
    GenServer.call(:piranha_worker, {:create_boat, name, capacity})
  end

  @doc "Create and return new time slot"
  @spec create(atom, integer, integer) :: map
  def create(:timeslot, start_time, duration)
      when is_integer(start_time) and is_integer(duration) do
    GenServer.call(:piranha_worker, {:create_timeslot, start_time, duration})
  end

  @doc """
  Retrieve list of boat inventory. 
  Note: Reads don't really need to go through GenServer
  """
  @spec get(atom) :: list
  def get(:boats) do
    GenServer.call(:piranha_worker, :get_boats)
  end

  @doc """
  Retrieve time slots by date key
  Note: Reads don't really need to go through GenServer
  """

  @spec get(atom, String.t()) :: list
  def get(:timeslots, date) when is_binary(date) do
    GenServer.call(:piranha_worker, {:get_timeslots, date})
  end

  @doc "Register boat for timeslot interval period"
  def register(:boat_timeslot, timeslot_id, boat_id)
      when is_binary(timeslot_id) and is_binary(boat_id) do
    GenServer.cast(:piranha_worker, {:register_boat_timeslot, timeslot_id, boat_id})
  end

  @doc "Make new booking"
  @spec make(atom, String.t(), integer) :: atom
  def make(:booking, timeslot_id, size)
      when is_binary(timeslot_id) and is_integer(size) do
    GenServer.cast(:piranha_worker, {:make_booking, timeslot_id, size})
  end

  #####
  # GenServer implementation

  # GenServer callback to initalize server process

  @callback init(term) :: tuple
  def init([]) do
    # _ = Logger.debug "Starting Piranha Worker Server #{inspect self}"
    {:ok, []}
  end

  @callback handle_call({atom, String.t(), integer}, tuple, list) :: tuple
  def handle_call({:create_boat, name, capacity}, _from, []) do
    boat = %{} = Controller.create(:boat, name, capacity)
    {:reply, boat, []}
  end

  @callback handle_call({atom, integer, integer}, tuple, list) :: tuple
  def handle_call({:create_timeslot, start_time, duration}, _from, []) do
    slot = %{} = Controller.create(:timeslot, start_time, duration)
    {:reply, slot, []}
  end

  @callback handle_call(atom, tuple, list) :: tuple
  def handle_call(:get_boats, _from, []) do
    list = Controller.get(:boats)
    {:reply, list, []}
  end

  @callback handle_call({atom, String.t()}, tuple, list) :: tuple
  def handle_call({:get_timeslots, date}, _from, []) do
    list = Controller.get(:timeslots, date)
    {:reply, list, []}
  end

  @callback handle_cast(tuple, list) :: tuple
  def handle_cast({:register_boat_timeslot, sid, bid}, []) do
    Controller.register(:boat_timeslot, sid, bid)
    {:noreply, []}
  end

  @callback handle_cast(tuple, list) :: tuple
  def handle_cast({:make_booking, sid, size}, []) do
    Controller.make(:booking, sid, size)
    {:noreply, []}
  end
end
