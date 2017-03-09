defmodule Piranha.Web do
  @moduledoc """
  Implements simple Web routing layer through Maru
  """

  use Maru.Router
  alias Piranha.Worker

  # Handle CORS
  plug Corsica, origins: "*"

  plug Plug.Parsers,
    pass: ["*/*"],
    parsers: [:urlencoded, :json, :multipart],
    json_decoder: Poison

  prefix :api

  namespace :timeslots do

    # curl -H "Content-Type: application/json" -X POST -d '{ "timeslot" : { "start_time": "1406052000", "duration": "120" }}' http://localhost:3000/api/timeslots/

    # Returns created timeslot, e.g.
    # { id: abc123, start_time: 1406052000, duration: 120, availability: 0, customer_count: 0, boats: [] }
    

    desc "Create a timeslot"
    params do
      group :timeslot, type: Map do
        requires :start_time, type: Integer # unix timestamp e.g. 1406052000
        requires :duration, type: Integer, values: 30..1440 # 30 mins to 24 hours
      end
    end
    post do
      result = Worker.create(:timeslot, params.timeslot.start_time, params.timeslot.duration)
      json(conn, result)
    end    

    
    # curl -H "Accept: application/json" -X GET http://localhost:3000/api/timeslots?date=2014-07-22

    # Returns timeslot list, e.g.
    # [{ id: abc123, start_time: 1406052000, duration: 120, availability: 4, customer_count: 4, boats: ['def456', ...] }, ...]
    
    desc "List timeslots"
    params do # simple date match YYYY-MM-DD, more complex is ~r/^(19|20)\d\d-(0[1-9]|1[012])-(0[1-9]|[12][0-9]|3[01])$ 
      requires :date, type: String, regexp: ~r/^(\d){4}\-(\d){2}\-(\d){2}$/ 
    end
    get do
      json(conn, Worker.get(:timeslots, params[:date]))
    end
    
  end


  namespace :boats do

    # curl -H "Content-Type: application/json" -X POST -d '{ "boat": { "capacity": "8", "name":"Amazon Express" }}' http://localhost:3000/api/boats/ 
    # Returns created boat, e.g. { id: def456, capacity: 8, name: "Amazon Express" }
        
    desc "Create a boat"
    params do
      group :boat, type: Map do
        requires :capacity, type: Integer, values: 2..200
        requires :name, type: String
      end
    end    
    post do
      result = Worker.create(:boat, params.boat.name, params.boat.capacity)
      json(conn, result)
    end
    
    # curl -X GET http://localhost:3000/api/boats/ 
    # Returns boat list, e.g. [{ id: def456, capacity: 8, name: "Amazon Express"}, ...]
           
    desc "List boats"
    get do
      json(conn, Worker.get(:boats))
    end

  end

  namespace :assignments do

    # curl -H "Content-Type: application/json" -X POST -d '{ "assignment": { "timeslot_id": "abc123", "boat_id":"def456" }}' http://localhost:3000/api/assignments/ 
    # Returns none

    desc "Assign boat to timeslot through register request"
    params do
      group :assignment, type: Map do
        requires :timeslot_id, type: String
        requires :boat_id, type: String
      end
    end
    post do
      Worker.register(:boat_timeslot, params.assignment.timeslot_id, params.assignment.boat_id)
      json(conn |> put_status(201), "")
    end

  end

  namespace :bookings do

    # curl -H "Content-Type: application/json" -X POST -d '{ "booking": { "timeslot_id": "abc123", "size":"6" }}' http://localhost:3000/api/bookings/ 
  # Returns none

    desc "Make a booking"
    params do
      group :booking, type: Map do
        requires :timeslot_id, type: String
        requires :size, type: Integer, values: 1..200
      end
    end
    post do
      Worker.make(:booking, params.booking.timeslot_id, params.booking.size)
      json(conn |> put_status(201), "")
    end

  end


  rescue_from :all, as: e do
    e |> IO.inspect
    
    conn 
    |> put_status(500)
    |> text("Piranha Web, Error #{inspect e}")
  end
  

end
