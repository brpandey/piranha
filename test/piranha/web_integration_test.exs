defmodule Piranha.Web.IntegrationTest do
  use ExUnit.Case

  alias Piranha.Test.Helper


  # Unix timestamp start values

  @six_pm    1406052000
  @seven_pm  1406055600

  # UIDs

  @slot_6pm_to_8pm      "abj3DjVtjZ"
  @slot_7pm_to_9pm      "abj3GAGijZ"

  @amazon_express_8        "GMCQLu1VInVfLyhRDUdoFlFG2fXwu7lcKNh2mT8WFzO"
  @amazon_express_mini_4   "EMFLmuZ5slOfE3I27teRs2FvqfDytBXCRMImasODuWKheFZBIzpIZ1Skq"

  setup_all do
    {:ok, _} = :application.ensure_all_started(:piranha)
    uninstall_db() # Let the per test case setup routine load/drop the db
    HTTPoison.start # We also need to start HTTPoison
    :ok
  end

  setup _context do
    install_db() # setup db for each integration test case fresh so we don't have conflicts
    on_exit fn ->
      uninstall_db() # drop db
    end
  end


  def install_db() do
    Amnesia.Schema.create
    Amnesia.start
    Piranha.Database.create(disk: [node()])
    Piranha.Database.wait
  end


  def uninstall_db() do
    Amnesia.start
    Piranha.Database.destroy
    Amnesia.stop
    Amnesia.Schema.destroy
  end



  test "case 1" do

    slot_resp = Helper.create_rest_timeslot(@six_pm, 120)
    boat1_resp = Helper.create_rest_boat("Amazon Express", 8)
    boat2_resp = Helper.create_rest_boat("Amazon Express Mini", 4)

    assert @slot_6pm_to_8pm = slot_resp.body.id

    assert @amazon_express_8 = boat1_resp.body.id
    assert @amazon_express_mini_4 = boat2_resp.body.id
    
    Helper.create_rest_assignment(@slot_6pm_to_8pm, @amazon_express_8)
    Helper.create_rest_assignment(@slot_6pm_to_8pm, @amazon_express_mini_4)

    response = Helper.get!("/api/timeslots/", [], params: %{date: "2014-07-22"})

    map = response.body |> List.first

    assert %{id: @slot_6pm_to_8pm} = map
    assert %{start_time: @six_pm} = map
    assert %{duration: 120} = map
    assert %{availability: 8} = map
    assert %{customer_count: 0} = map
    assert %{boats: [@amazon_express_mini_4, @amazon_express_8]} = map

    _response = Helper.create_rest_booking(@slot_6pm_to_8pm, 6)


    response = Helper.get!("/api/timeslots/", [], params: %{date: "2014-07-22"})

    map = response.body |> List.first

    assert %{id: @slot_6pm_to_8pm} = map
    assert %{start_time: @six_pm} = map
    assert %{duration: 120} = map
    assert %{availability: 4} = map
    assert %{customer_count: 6} = map
    assert %{boats: [@amazon_express_mini_4, @amazon_express_8]} = map

  end




  test "case 2" do

    slot1_resp = Helper.create_rest_timeslot(@six_pm, 120)
    slot2_resp = Helper.create_rest_timeslot(@seven_pm, 120)

    boat1_resp = Helper.create_rest_boat("Amazon Express", 8)


    assert @slot_6pm_to_8pm = slot1_resp.body.id
    assert @slot_7pm_to_9pm = slot2_resp.body.id

    assert @amazon_express_8 = boat1_resp.body.id
    
    Helper.create_rest_assignment(@slot_6pm_to_8pm, @amazon_express_8)
    Helper.create_rest_assignment(@slot_7pm_to_9pm, @amazon_express_8)

    response = Helper.get!("/api/timeslots/", [], params: %{date: "2014-07-22"})

    map = response.body |> List.first

    assert %{id: @slot_6pm_to_8pm} = map
    assert %{start_time: @six_pm} = map
    assert %{duration: 120} = map
    assert %{availability: 8} = map
    assert %{customer_count: 0} = map
    assert %{boats: [@amazon_express_8]} = map

    map = response.body |> List.last

    assert %{id: @slot_7pm_to_9pm} = map
    assert %{start_time: @seven_pm} = map
    assert %{duration: 120} = map
    assert %{availability: 8} = map
    assert %{customer_count: 0} = map
    assert %{boats: [@amazon_express_8]} = map


    _response = Helper.create_rest_booking(@slot_7pm_to_9pm, 2)

    response = Helper.get!("/api/timeslots/", [], params: %{date: "2014-07-22"})

    map = response.body |> List.first

    assert %{id: @slot_6pm_to_8pm} = map
    assert %{start_time: @six_pm} = map
    assert %{duration: 120} = map
    assert %{availability: 0} = map
    assert %{customer_count: 0} = map
    assert %{boats: [@amazon_express_8]} = map


    map = response.body |> List.last

    assert %{id: @slot_7pm_to_9pm} = map
    assert %{start_time: @seven_pm} = map
    assert %{duration: 120} = map
    assert %{availability: 6} = map
    assert %{customer_count: 2} = map
    assert %{boats: [@amazon_express_8]} = map

  end



end
