defmodule Piranha do
  @moduledoc """
  Sets up Piranha application
  """

  use Application 


  def start(_type, _args) do
    import Supervisor.Spec, warn: false 


    # Database init routines if not already started
    install_db()

    # Define worker and start under this now defined Supervisor
    children = [worker(Piranha.Worker, [])] 
    opts = [strategy: :one_for_one, name: Piranha.Supervisor] 
    
    Supervisor.start_link(children, opts) 
  end

  
  def install_db() do # if db already created, then defaults to that
    Amnesia.Schema.create
    Amnesia.start
    Piranha.Database.create(disk: [node()])
    Piranha.Database.wait
  end


end 
