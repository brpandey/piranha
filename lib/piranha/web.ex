defmodule Piranha.Web do
  @moduledoc """
  Implements simple Web routing layer through Maru
  """

  use Maru.Router

  alias Piranha.Worker

  plug Plug.Parsers,
    pass: ["*/*"],
    json_decoder: Poison,
    parsers: [:urlencoded, :json, :multipart]

  prefix :api

  namespace :timeslots do

    # curl -H "Content-Type: application/json" -X POST -d '{ "start_time": "1406052000", "duration": "120" }' http://localhost:3000/api/timeslots/ 

    # Returns created timeslot, e.g.
    # { id: abc123, start_time: 1406052000, duration: 120, availability: 0, customer_count: 0, boats: [] }
    


    desc "Create a timeslot"
    params do
      requires :start_time, type: Integer # unix timestamp e.g. 1406052000
      requires :duration, type: Integer, values: 30..720 # 30 mins to 12 hours
    end
    post do
      json(conn, Worker.create(:timeslot, params[:start_time], params[:duration]))
    end    

    
    # curl -H "Accept: application/json" -X GET http://localhost:3000/api/timeslots?date=2014-07-22

    # Returns timeslot list, e.g.
    # [{ id: abc123, start_time: 1406052000, duration: 120, availability: 4, customer_count: 4, boats: ['def456', ...] }, ...]
    
    desc "List timeslots"
    params do
      requires :date, type: String, regexp: ~r/^(\d){4}\-(\d){2}\-(\d){2}$/ # simple match YYYY-MM-DD
                                                                            # More complex:
                                                                            # ~r/^(19|20)\d\d-(0[1-9]|1[012])-(0[1-9]|[12][0-9]|3[01])$ 
    end
    get do
      json(conn, Worker.get(:timeslots, params[:date]))
    end
    
  end


  namespace :boats do

    # curl -H "Content-Type: application/json" -X POST -d '{ "capacity": "8", "name":"Amazon Express" }' http://localhost:3000/api/boats/ 
    # Returns created boat, e.g. { id: def456, capacity: 8, name: "Amazon Express" }
        
    desc "Create a boat"
    params do
      requires :capacity, type: Integer, values: 2..200
      requires :name, type: String
    end

    
    post do
      json(conn, Worker.create(:boat, params[:name], params[:capacity]))
    end
    
    # curl -X GET http://localhost:3000/api/boats/ 
    # Returns boat list, e.g. [{ id: def456, capacity: 8, name: "Amazon Express"}, ...]
           
    desc "List boats"
    get do
      json(conn, Worker.get(:boats))
    end

  end

  namespace :assignments do

    # curl -H "Content-Type: application/json" -X POST -d '{ "timeslot_id": "abc123", "boat_id":"def456" }' http://localhost:3000/api/assignments/ 
    # Returns none

    desc "Assign boat to timeslot through register request"
    params do
      requires :timeslot_id, type: String
      requires :boat_id, type: String
    end
    post do
      json(conn, 
           Worker.register(:boat_timeslot,
                         params[:timeslot_id], params[:boat_id]
      ))
    end

  end

  namespace :bookings do

    # curl -H "Content-Type: application/json" -X POST -d '{ "timeslot_id": "abc123", "size":"6" }' http://localhost:3000/api/bookings/ 
  # Returns none

    desc "Make a booking"
    params do
      requires :timeslot_id, type: String
      requires :size, type: Integer, values: 2..200
    end

    post do
      json(conn, Worker.make(:booking, 
                                 params[:timeslot_id], params[:size]))
    end

  end



  rescue_from :all, as: e do
    e |> IO.inspect
    
    conn 
    |> put_status(500)
    |> text("Piranha Web, Not found #{inspect e}")
  end
  

end
