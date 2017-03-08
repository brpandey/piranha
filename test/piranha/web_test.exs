defmodule Piranha.Web.Test do
  use ExUnit.Case
  alias Piranha.Test.Helper

  # Unix timestamp start values

  @two_pm    1406037600
#  @three_pm  1406041200
  @six_pm    1406052000


  # UIDs

  @slot_2pm_to_3_30pm   "3Yey3pafll"  
#  @slot_3pm_to_4pm      "2lnywEMUpx"
  @slot_6pm_to_8pm      "abj3DjVtjZ"


  @amazon_express_10    "yxUbWubduKNclzUE2uOBTzFbVfawh78cqlS12HZkHJ8"
  @amazon_speedy_6      "EWiLmuZ5slOfE3I27teRs2FvOfDpIBOTR4CmYSOz"
#  @amazon_yacht_12      "1zHrluMQSENTa1I7oudnF7FQvhRwiYzhVkIyz"


  setup_all do
    {:ok, _} = :application.ensure_all_started(:piranha)

    # We also need to start HTTPoison
    HTTPoison.start

    :ok
  end



  # curl -H "Content-Type: application/json" -X POST -d '{timeslot: { "start_time": "1406052000", "duration": "120" }}' http://localhost:3000/api/timeslots/ 
  
  # Returns created timeslot, e.g.
  # { id: abc123, start_time: 1406052000, duration: 120, availability: 0, customer_count: 0, boats: [] }

  test "create timeslot" do

    response = Helper.create_rest_timeslot(@six_pm, 120)

    assert %{id: @slot_6pm_to_8pm} = response.body
    assert %{start_time: @six_pm} = response.body
    assert %{duration: 120} = response.body
    assert %{availability: 0} = response.body
    assert %{customer_count: 0} = response.body
    assert %{boats: []} = response.body
  end



  test "create timeslot that is less than a half hour" do

    response = Helper.create_rest_timeslot(@six_pm, 29)

    assert "Piranha Web, Error %Maru.Exceptions.Validation{option: 30..1440, param: :duration, validator: :values, value: 29}" = response.body

  end



  test "create two timeslots" do

    response = Helper.create_rest_timeslot(@two_pm, 90)

    assert %{id: @slot_2pm_to_3_30pm} = response.body
    assert %{start_time: @two_pm} = response.body
    assert %{duration: 90} = response.body
    assert %{availability: 0} = response.body
    assert %{customer_count: 0} = response.body
    assert %{boats: []} = response.body


    response = Helper.create_rest_timeslot(@six_pm, 120)

    assert %{id: @slot_6pm_to_8pm} = response.body
    assert %{start_time: @six_pm} = response.body
    assert %{duration: 120} = response.body
    assert %{availability: 0} = response.body
    assert %{customer_count: 0} = response.body
    assert %{boats: []} = response.body
  end



  # curl -H "Accept: application/json" -X GET http://localhost:3000/api/timeslots?date=2014-07-22
  
  # Returns timeslot list, e.g.
  # [{ id: abc123, start_time: 1406052000, duration: 120, availability: 4, customer_count: 4, boats: ['def456', ...] }, ...

  test "get timeslots" do


    _response = Helper.create_rest_timeslot(@six_pm, 120)
    _response = Helper.create_rest_timeslot(@two_pm, 90)

    response = Helper.get!("/api/timeslots/", [], params: %{date: "2014-07-22"})

    map = response.body |> List.last

    assert %{id: @slot_6pm_to_8pm} = map
    assert %{start_time: @six_pm} = map
    assert %{duration: 120} = map
    assert %{availability: 0} = map
    assert %{customer_count: 0} = map
    assert %{boats: []} = map

  end


  # curl -H "Accept: application/json" -X GET http://localhost:3000/api/timeslots?date=2014-07-22
  
  # Returns timeslot list, e.g.
  # [{ id: abc123, start_time: 1406052000, duration: 120, availability: 4, customer_count: 4, boats: ['def456', ...] }, ...

  test "get timeslots, invalid key" do

    _response = Helper.create_rest_timeslot(@six_pm, 120)

    response = Helper.get!("/api/timeslots/", [], params: %{date: "2014-7-22"})

    assert "Piranha Web, Error %Maru.Exceptions.Validation{option: ~r/^(\\d){4}\\-(\\d){2}\\-(\\d){2}$/, param: :date, validator: :regexp, value: \"2014-7-22\"}" = response.body

  end



  # curl -H "Content-Type: application/json" -X POST -d '{"boat": { "capacity": "8", "name":"Amazon Express" }}' http://localhost:3000/api/boats/ 
  # Returns created boat, e.g. { id: def456, capacity: 8, name: "Amazon Express" }
  

  test "create a normal boat" do
    response = Helper.create_rest_boat("Amazon Express", 10)

    assert %{id: @amazon_express_10} = response.body
    assert %{capacity: 10} = response.body
    assert %{name: "Amazon Express"} = response.body
  end


  test "create a boat that is too small" do
    response = Helper.create_rest_boat("Amazon Express", 1)
    assert "Piranha Web, Error %Maru.Exceptions.Validation{option: 2..200, param: :capacity, validator: :values, value: 1}" = response.body
  end
 

  # curl -X GET http://localhost:3000/api/boats/ 
  # Returns boat list, e.g. [{ id: def456, capacity: 8, name: "Amazon Express"}, ...]

  test "list boats" do

    response = Helper.create_rest_boat("Amazon Express", 10)

    boat1 = response.body

    response = Helper.create_rest_boat("Amazon Speedy", 6)

    boat2 = response.body

    response = Helper.get!("/api/boats/", [], [])


    # inject response into a MapSet so that order of boats doesn't matter

    set = response.body |> MapSet.new

    assert true = MapSet.member?(set, boat1)

    assert %{id: @amazon_express_10} = boat1
    assert %{capacity: 10} = boat1
    assert %{name: "Amazon Express"} = boat1

    assert true = MapSet.member?(set, boat2)

    assert %{id: @amazon_speedy_6} = boat2
    assert %{capacity: 6} = boat2
    assert %{name: "Amazon Speedy"} = boat2

  end



    # curl -H "Content-Type: application/json" -X POST -d '{"assignment": { "timeslot_id": "abc123", "boat_id":"def456" }}' http://localhost:3000/api/assignments/ 
    # Returns none

  test "assign boat to timeslot" do

    boat_resp = Helper.create_rest_boat("Amazon Express", 10)
    slot_resp = Helper.create_rest_timeslot(@six_pm, 120)

    boat_id = boat_resp.body.id
    slot_id = slot_resp.body.id

    response = Helper.create_rest_assignment(slot_id, boat_id)

    assert response.body == ""
  end



    # curl -H "Content-Type: application/json" -X POST -d '{ "booking": { "timeslot_id": "abc123", "size":"6" }}' http://localhost:3000/api/bookings/ 
  # Returns none


  test "make a booking" do

    boat_resp = Helper.create_rest_boat("Amazon Express", 10)
    slot_resp = Helper.create_rest_timeslot(@six_pm, 120)

    boat_id = boat_resp.body.id
    slot_id = slot_resp.body.id

    _response = Helper.create_rest_assignment(slot_id, boat_id)

    response = Helper.create_rest_booking(slot_id, 7)

    assert response.body == ""
  end



  test "make an empty booking" do

    boat_resp = Helper.create_rest_boat("Amazon Express", 10)
    slot_resp = Helper.create_rest_timeslot(@six_pm, 120)

    boat_id = boat_resp.body.id
    slot_id = slot_resp.body.id

    _response = Helper.create_rest_assignment(slot_id, boat_id)

    response = Helper.create_rest_booking(slot_id, 0)

    assert response.body == "Piranha Web, Error %Maru.Exceptions.Validation{option: 1..200, param: :size, validator: :values, value: 0}"
  end


end

