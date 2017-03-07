defmodule Piranha.SlotBoat.Test do
  use ExUnit.Case, async: true

  alias Piranha.{Slot, Boat}

  # Unix timestamp start values

  @two_pm    1406037600
  @three_pm  1406041200
  @six_pm    1406052000


  # UIDs

  @slot_2pm_to_3_30pm   "3Yey3pafll"  
  @slot_3pm_to_4pm      "2lnywEMUpx"
  @slot_6pm_to_8pm      "abj3DjVtjZ"


  @amazon_express_10    "yxUbWubduKNclzUE2uOBTzFbVfawh78cqlS12HZkHJ8"
  @amazon_speedy_6      "EWiLmuZ5slOfE3I27teRs2FvOfDpIBOTR4CmYSOz"
  @amazon_yacht_12      "1zHrluMQSENTa1I7oudnF7FQvhRwiYzhVkIyz"


  # Run before all tests
#  setup_all do
    
#    Application.stop(:piranha)
#    IO.puts "Piranha Slot Test"
    
#  end


  describe "one slot no boats" do

    setup :one_slot_no_boat

    test "correct date key", %{slot: slot} do
      assert "2014-07-22" = Slot.date(slot)
    end

    test "correct slot dump", %{slot: slot} do
      assert %{availability: 0, boats: [], customer_count: 0, duration: 120,
               id: @slot_6pm_to_8pm, start_time: @six_pm} 
      = Slot.dump(slot)
    end

  end


  describe "1 slot 1 boat" do

    setup :one_slot_one_boat


    test "1 slot 1 boat, correct dump", %{slot: slot, boat: _boat} do

      assert %{availability: 10,
              boats: [@amazon_express_10],
              customer_count: 0, duration: 120, id: @slot_6pm_to_8pm,
              start_time: @six_pm}
      = Slot.dump(slot)      
    end


    test "1 slot 1 boat, reserve no availability", %{slot: slot, boat: boat} do

      assert 10 = Boat.capacity(boat)

      over_size = 12

      fleet = %{boat.id => boat}

      # request for size above 10 e.g. 12
      assert {:none, slot, _} = Slot.reserve(slot, fleet, over_size)
      assert %{availability: 10,
              boats: [@amazon_express_10],
              customer_count: 0, duration: 120, id: @slot_6pm_to_8pm,
              start_time: @six_pm} 
      = Slot.dump(slot)
    end


    test "1 slot 1 boat, reserve success, same size", %{slot: slot, boat: boat} do

      assert 10 = Boat.capacity(boat)

      equal_size = 10

      fleet = %{boat.id => boat}

      # request for size above 10 e.g. 12
      assert {:ok, slot, _, []} = Slot.reserve(slot, fleet, equal_size)
      assert %{availability: 0,
              boats: [@amazon_express_10],
              customer_count: 10, duration: 120, id: @slot_6pm_to_8pm,
              start_time: @six_pm}
      = Slot.dump(slot)
    end


    test "1 slot 1 boat, reserve success, under size", %{slot: slot, boat: boat} do

      assert 10 = Boat.capacity(boat)

      under_size = 8
      fleet = %{boat.id => boat}

      # request for size above 10 e.g. 12
      assert {:ok, slot, _, []} = Slot.reserve(slot, fleet, under_size)
      assert %{availability: 2,
              boats: [@amazon_express_10],
              customer_count: 8, duration: 120, id: @slot_6pm_to_8pm,
              start_time: @six_pm}
      = Slot.dump(slot)
    end

  end



  describe "1 slot 2 boats" do

    setup :one_slot_two_boat

    
    test "requested size in middle of boat availability", 
    %{slot: slot, boats: {b1, b2}} do

      assert 10 = Boat.capacity(b1)
      assert 6 = Boat.capacity(b2)

      size = 8       # request for size in middle of 6 and 10
      fleet = %{b1.id => b1, b2.id => b2}

      assert {:ok, slot, _, []} = Slot.reserve(slot, fleet, size)
      assert %{availability: 6,
              boats: [@amazon_speedy_6,
                      @amazon_express_10],
              customer_count: 8, duration: 120, id: @slot_6pm_to_8pm,
              start_time: @six_pm} 
      = Slot.dump(slot)

    end


    test "requested size below min of boat availability", 
    %{slot: slot, boats: {b1, b2}} do

      assert 10 = Boat.capacity(b1)
      assert 6 = Boat.capacity(b2)

      size = 4       # request for size lower than 6 and 10
      fleet = %{b1.id => b1, b2.id => b2}

      assert {:ok, slot, _, []} = Slot.reserve(slot, fleet, size)
      assert %{availability: 10,
              boats: [@amazon_speedy_6, @amazon_express_10],
              customer_count: 4, duration: 120, id: @slot_6pm_to_8pm,
              start_time: @six_pm} 
      = Slot.dump(slot)

    end


    test "multiple bookings, repeatedly switching between the two boats",
    %{slot: slot, boats: {b1, b2}} do

      assert 10 = Boat.capacity(b1)
      assert 6 = Boat.capacity(b2)

      size = 3       # request for size lower than 6 and 10
      fleet = %{b1.id => b1, b2.id => b2}

      # NOTE: we don't account for any conflicts, since there is only one slot
      # hence empty list [] for exclusion pairs

      # pass 1, slot grabs 3 from speedy6, leaving speedy6: 3, express10: 10
      assert {:ok, slot, fleet, []} = Slot.reserve(slot, fleet, size)

      assert %{availability: 10,
              boats: [@amazon_speedy_6, @amazon_express_10],
              customer_count: 3, duration: 120, id: @slot_6pm_to_8pm,
              start_time: @six_pm} 
      = Slot.dump(slot)

      new_size = 4

      # pass 2, slot grabs 4 from express10, leaving speedy6: 3, express10: 6
      assert {:ok, slot, fleet, []} = Slot.reserve(slot, fleet, new_size)
      assert %{availability: 6,
              boats: [@amazon_speedy_6, @amazon_express_10],
              customer_count: 7, duration: 120, id: @slot_6pm_to_8pm,
              start_time: @six_pm} 
      = Slot.dump(slot)


      # pass 3, slot grabs 4 from express10, leaving speedy6: 3, express10: 2
      assert {:ok, slot, fleet, []} = Slot.reserve(slot, fleet, new_size)
      assert %{availability: 3,
              boats: [@amazon_speedy_6, @amazon_express_10],
              customer_count: 11, duration: 120, id: @slot_6pm_to_8pm,
              start_time: @six_pm} 
      = Slot.dump(slot)

      new_size = 3

      # pass 4, slot grabs 3 from speedy6, leaving speedy6: 0, express10: 2
      assert {:ok, slot, fleet, []} = Slot.reserve(slot, fleet, new_size)
      assert %{availability: 2,
              boats: [@amazon_speedy_6, @amazon_express_10],
              customer_count: 14, duration: 120, id: @slot_6pm_to_8pm,
              start_time: @six_pm} 
      = Slot.dump(slot)


      # pass 5, slot grabs 2 from express10, leaving speedy6: 0, express10: 0

      new_size = 2

      assert {:ok, slot, fleet, []} = Slot.reserve(slot, fleet, new_size)
      assert %{availability: 0,
              boats: [@amazon_speedy_6, @amazon_express_10],
              customer_count: 16, duration: 120, id: @slot_6pm_to_8pm,
              start_time: @six_pm} 
      = Slot.dump(slot)

      # pass 6, slot grabs none

      assert {:none, slot, _fleet} = Slot.reserve(slot, fleet, new_size)
      assert %{availability: 0,
              boats: [@amazon_speedy_6, @amazon_express_10],
              customer_count: 16, duration: 120, id: @slot_6pm_to_8pm,
              start_time: @six_pm} 
      = Slot.dump(slot)


    end


    
    test "no availability, size above max availability", 
    %{slot: slot, boats: {b1, b2}} do

      assert 10 = Boat.capacity(b1)
      assert 6 = Boat.capacity(b2)

      size = 12       # request for size greater than 6 and 10
      fleet = %{b1.id => b1, b2.id => b2}

      assert {:none, slot, _}  = Slot.reserve(slot, fleet, size)
      assert %{availability: 10,
              boats: [@amazon_speedy_6, @amazon_express_10],
              customer_count: 0, duration: 120, id: @slot_6pm_to_8pm,
              start_time: @six_pm} 
      = Slot.dump(slot)
    end

  end




  describe "2 slots 1 boat, non-overlapping" do

    setup :two_slot_one_boat_non_overlapping


    test "medium requested size", %{slots: {s1, s2}, boat: boat} do

      assert 10 = Boat.capacity(boat)

      size = 8

      fleet = %{boat.id => boat}

      assert {:ok, s1, fleet, []} = Slot.reserve(s1, fleet, size)

      assert %{availability: 2,
              boats: [@amazon_express_10],
              customer_count: 8, duration: 120, id: @slot_6pm_to_8pm,
              start_time: @six_pm} 
      = Slot.dump(s1)


      assert {:ok, s2, _fleet, []} = Slot.reserve(s2, fleet, size)

      assert %{availability: 2,
              boats: [@amazon_express_10],
              customer_count: 8, duration: 90, id: @slot_2pm_to_3_30pm,
              start_time: @two_pm} 
      = Slot.dump(s2)
      
    end

  end




  describe "2 slots 1 boat, overlapping" do

    setup :two_slot_one_boat_overlapping


    test "boat already reserved by first slot",
    %{slots: {s1, s2}, boat: boat} do

      {:ok, s1, boat} = Slot.register(s1, boat)
      {:ok, s2, boat} = Slot.register(s2, boat)


      assert 10 = Boat.capacity(boat)

      fleet = %{boat.id => boat}

      size = 7       # request for size below 10

      assert {:ok, s1, fleet, exclude_pairs} = Slot.reserve(s1, fleet, size)

      map = Slot.reconcile(s1, :exclusion, %{s2.id => s2}, exclude_pairs)

      s2 = Map.get(map, s2.id)


      assert %{availability: 3,
              boats: [@amazon_express_10],
              customer_count: 7, duration: 60, id: @slot_3pm_to_4pm,
              start_time: @three_pm} 
      = Slot.dump(s1)


      assert %{availability: 0,
              boats: [@amazon_express_10],
              customer_count: 0, duration: 90, id: @slot_2pm_to_3_30pm,
              start_time: @two_pm} 
      = Slot.dump(s2)


      new_size = 3

      assert {:none, s2, _fleet} = Slot.reserve(s2, fleet, new_size)

      assert %{availability: 0,
              boats: [@amazon_express_10],
              customer_count: 0, duration: 90, id: @slot_2pm_to_3_30pm,
              start_time: @two_pm} 
      = Slot.dump(s2)

    end


    test "boat already reserved by second slot",
    %{slots: {s1, s2}, boat: boat} do

      {:ok, s1, boat} = Slot.register(s1, boat)
      {:ok, s2, boat} = Slot.register(s2, boat)


      assert 10 = Boat.capacity(boat)
      fleet = %{boat.id => boat}

      size = 7       # request for size below 10

      assert {:ok, s2, fleet, exclude_pairs} = Slot.reserve(s2, fleet, size)

      s1 = 
        Slot.reconcile(s2, :exclusion, %{s1.id => s1}, exclude_pairs) 
        |> Map.get(s1.id)


      assert %{availability: 3,
              boats: [@amazon_express_10],
              customer_count: 7, duration: 90, id: @slot_2pm_to_3_30pm,
              start_time: @two_pm} 
      = Slot.dump(s2)


      assert %{availability: 0,
              boats: [@amazon_express_10],
              customer_count: 0, duration: 60, id: @slot_3pm_to_4pm,
              start_time: @three_pm} 
      = Slot.dump(s1)


      new_size = 3

      assert {:none, s1, _fleet} = Slot.reserve(s1, fleet, new_size)

      assert %{availability: 0,
              boats: [@amazon_express_10],
              customer_count: 0, duration: 60, id: @slot_3pm_to_4pm,
              start_time: @three_pm} 
      = Slot.dump(s1)

    end


    test "first slot registered and reserved, second attempts to register", 
    %{slots: {s1, s2}, boat: boat} do
    
      # slot 1 registers
      {:ok, s1, boat} = Slot.register(s1, boat)

      assert 10 = Boat.capacity(boat)

      fleet = %{boat.id => boat}

      size = 7

      # slot 1 reserves
      assert {:ok, s1, fleet, exclude_pairs} = Slot.reserve(s1, fleet, size)


      # we reconcile the new boat reservation booking with the other slot
      # so it can update its view of the boat status availability

      s2_new = 
        Slot.reconcile(s1, :exclusion, %{s2.id => s2}, exclude_pairs) 
        |> Map.get(s2.id)


      assert %{availability: 3,
              boats: [@amazon_express_10],
              customer_count: 7, duration: 60, id: @slot_3pm_to_4pm,
              start_time: @three_pm} 
      = Slot.dump(s1)

      
      # slot s2 through the reconciliation already has the updated state
      assert %{availability: 0, 
               boats: [], 
               customer_count: 0, 
               duration: 90,
               id: @slot_2pm_to_3_30pm, 
               start_time: @two_pm}
      = Slot.dump(s2_new)

      # slot 2 tries to register for same boat
      boat = %Boat{} = Map.get(fleet, boat.id)

      # make sure that even with the old s2, it will still determine the boat is unavailable
      assert :unavailable = Slot.register(s2, boat)
    end


  end



  describe "2 slots 2 boats, non-overlapping" do

    setup :two_slot_two_boat_non_overlapping


    test "medium requested size",
    %{slots: {s1, s2}, boats: {b1, b2}} do

      assert 10 = Boat.capacity(b1)
      assert 6 = Boat.capacity(b2)

      size = 8       # request for size below 6 and 10
      fleet = %{b1.id => b1, b2.id => b2}

      assert {:ok, s1, fleet, []} = Slot.reserve(s1, fleet, size)

      assert %{availability: 6,
              boats: [@amazon_speedy_6, @amazon_express_10],
              customer_count: 8, duration: 120, id: @slot_6pm_to_8pm,
              start_time: @six_pm} 
      = Slot.dump(s1)


      assert {:ok, s2, _fleet, []} = Slot.reserve(s2, fleet, size)

      assert %{availability: 6,
              boats: [@amazon_speedy_6, 
                      @amazon_express_10],
              customer_count: 8, duration: 90, id: @slot_2pm_to_3_30pm,
              start_time: @two_pm} 
      = Slot.dump(s2)
      
    end

  end




  describe "2 slots 2 boats, overlapping" do

    setup :two_slot_two_boat_overlapping


    test "2 slot reserve successes",
    %{slots: {s1, s2}, boats: {b1, b2}} do

      fleet = %{b1.id => b1, b2.id => b2}

      size = 7 # request for size below 10

      assert 10 = Boat.capacity(b1)
      assert 12 = Boat.capacity(b2)

      assert {:ok, s1, fleet, _exclude_pairs} = Slot.reserve(s1, fleet, size)

      # don't reconcile s2 now, let it happen naturally once s2 makes reservation

      # we have grabbed the 10 capacity boat to put our 7 into
      assert %{availability: 12,
        boats: [@amazon_yacht_12, @amazon_express_10],
        customer_count: 7, duration: 60, id: @slot_3pm_to_4pm,
        start_time: @three_pm}
      = Slot.dump(s1)


      assert {:ok, s2, _fleet, exclude_pairs} = Slot.reserve(s2, fleet, size)

      # reconcile for slot 1 (it should not have 12 available spots anymore)
      s1 = 
        Slot.reconcile(s2, :exclusion, %{s1.id => s1}, exclude_pairs) 
      |> Map.get(s1.id)

      # s1 no longer has the amazon yacht 12 boat available, 
      # so its availability is based on the remaining slots from the 
      # express 10 boat, of which it already has 7, leaving only 3 spots left
      
      assert %{availability: 3,
               boats: [@amazon_yacht_12, @amazon_express_10],
               customer_count: 7, duration: 60, id: @slot_3pm_to_4pm,
               start_time: @three_pm}
      = Slot.dump(s1)


      assert %{availability: 5, 
              boats: [@amazon_yacht_12, @amazon_express_10],
              customer_count: 7, duration: 90, id: @slot_2pm_to_3_30pm,
              start_time: @two_pm}
      = Slot.dump(s2)
      

    end


    test "multiple booking passes over the 2 boats",
    %{slots: {s1, s2}, boats: {b1, b2}} do

      fleet = %{b1.id => b1, b2.id => b2}

      size = 7 # request for size below 10

      assert 10 = Boat.capacity(b1)
      assert 12 = Boat.capacity(b2)

      # pass #1, first slot tries for 7 (gets amazon_express_10)

      # NOTE: we are not explicitly reconciling since the alternate
      # slot makes a reserve attempt on the next pass and thus
      # automatically reconciles

      assert {:ok, s1, fleet, _} = Slot.reserve(s1, fleet, size)
      
      # we have grabbed the 10 capacity boat to put our 7 into
      assert %{availability: 12,
        boats: [@amazon_yacht_12, @amazon_express_10],
        customer_count: 7, duration: 60, id: @slot_3pm_to_4pm,
        start_time: @three_pm}
      = Slot.dump(s1)


      # pass #2, second slot tries for 7 (gets amazon_yacht_12) 
      assert {:ok, s2, fleet, _} = Slot.reserve(s2, fleet, size)

      assert %{availability: 5, 
              boats: [@amazon_yacht_12, @amazon_express_10],
              customer_count: 7, duration: 90, id: @slot_2pm_to_3_30pm,
              start_time: @two_pm}
      = Slot.dump(s2)

      
      # pass #3, first slot tries for 7 (as earlier availability was 12)
      # doesn't get anything since second slot already grabbed @amazon_yacht_12
      assert {:none, s1, fleet} = Slot.reserve(s1, fleet, size)
      
      assert %{availability: 3,
               boats: [@amazon_yacht_12, @amazon_express_10],
               customer_count: 7, duration: 60, id: @slot_3pm_to_4pm,
               start_time: @three_pm}
      = Slot.dump(s1)


      # pass #4, second slot tries for 5 (gets amazon_yacht_12) 
      # this still adheres to the rule 
      # "a boat can only be used for a single timeslot at any given time"

      new_size = 5

      assert {:ok, s2, _fleet, _} = Slot.reserve(s2, fleet, new_size)

      assert %{availability: 0, 
              boats: [@amazon_yacht_12, @amazon_express_10],
              customer_count: 12, duration: 90, id: @slot_2pm_to_3_30pm,
              start_time: @two_pm}
      = Slot.dump(s2)

      
    end


  end


  describe "3 slots 1 boat, 2 slots overlapping" do

    setup :three_slot_one_boat_two_slots_overlapping


    test "reserve success from overlap slot, reserve fail from other overlap, reserve success from non-overlap",
    %{overlaps: {s1, s2}, non_overlap: s3, boat: boat} do
      
      fleet = %{boat.id => boat}
      
      size = 4 # request for size below 10
      
      assert 10 = Boat.capacity(boat)
      
      # pass #1, first slot tries for 4 (gets amazon_express_10)
      assert {:ok, s1, fleet, exclude_pair} = Slot.reserve(s1, fleet, size)


      # we reconcile the new boat reservation booking with the other slot
      # so it can update its view of the boat status availability

      s2 = 
        Slot.reconcile(s1, :exclusion, %{s2.id => s2}, exclude_pair) 
        |> Map.get(s2.id)

      # we have grabbed the 10 capacity boat to put our 4 into
      assert %{availability: 6,
               boats: [@amazon_express_10],
               customer_count: 4, duration: 60, id: @slot_3pm_to_4pm,
               start_time: @three_pm}
      = Slot.dump(s1)


      assert %{availability: 0, 
               boats: [@amazon_express_10],
               customer_count: 0, duration: 90, id: @slot_2pm_to_3_30pm,
               start_time: @two_pm}
      = Slot.dump(s2)
      
      
      # pass #2, second overlap slot tries for 4 doesn't get it
      assert {:none, _s2, fleet} = Slot.reserve(s2, fleet, size)
      
      # pass #3, non overlap slot three tries for 7 and gets it
      new_size = 7

      assert {:ok, s3, _fleet, []} = Slot.reserve(s3, fleet, new_size)
      
      assert %{availability: 3, 
               boats: [@amazon_express_10],
               customer_count: 7, duration: 120, id: @slot_6pm_to_8pm,
               start_time: @six_pm}
      = Slot.dump(s3)
      
    end

  end


  def one_slot_no_boat _context do

    slot = Slot.new(@six_pm, 120)

    [slot: slot]
  end

  

  def one_slot_one_boat _context do

    slot = Slot.new(@six_pm, 120)

    boat = Boat.new("Amazon Express", 10)

    {:ok, slot, boat} = Slot.register(slot, boat)

    [slot: slot, boat: boat]
  end



  def one_slot_two_boat _context do

    slot = Slot.new(@six_pm, 120)

    boat1 = Boat.new("Amazon Express", 10)
    boat2 = Boat.new("Amazon Speedy", 6)

    {:ok, slot, boat1} = Slot.register(slot, boat1)
    {:ok, slot, boat2} = Slot.register(slot, boat2)

    [slot: slot, boats: {boat1, boat2}]
  end



  def two_slot_one_boat_non_overlapping _context do

    slot1 = Slot.new(@six_pm, 120)
    slot2 = Slot.new(@two_pm, 90)


    boat = Boat.new("Amazon Express", 10)

    {:ok, slot1, boat} = Slot.register(slot1, boat)
    {:ok, slot2, boat} = Slot.register(slot2, boat)


    [slots: {slot1, slot2}, boat: boat]
  end


  def two_slot_one_boat_overlapping _context do

    slot1 = Slot.new(@three_pm, 60)
    slot2 = Slot.new(@two_pm, 90)

    boat = Boat.new("Amazon Express", 10)

    [slots: {slot1, slot2}, boat: boat]
  end




  def two_slot_two_boat_non_overlapping _context do

    slot1 = Slot.new(@six_pm, 120)
    slot2 = Slot.new(@two_pm, 90)

    boat1 = Boat.new("Amazon Express", 10)
    boat2 = Boat.new("Amazon Speedy", 6)

    {:ok, slot1, boat1} = Slot.register(slot1, boat1)
    {:ok, slot1, boat2} = Slot.register(slot1, boat2)

    {:ok, slot2, boat1} = Slot.register(slot2, boat1)
    {:ok, slot2, boat2} = Slot.register(slot2, boat2)

    [slots: {slot1, slot2}, boats: {boat1, boat2}]
  end



  def two_slot_two_boat_overlapping _context do

    slot1 = Slot.new(@three_pm, 60)
    slot2 = Slot.new(@two_pm, 90)

    boat1 = Boat.new("Amazon Express", 10)
    boat2 = Boat.new("Amazon Yacht", 12)

    {:ok, slot1, boat1} = Slot.register(slot1, boat1)
    {:ok, slot1, boat2} = Slot.register(slot1, boat2)

    {:ok, slot2, boat1} = Slot.register(slot2, boat1)
    {:ok, slot2, boat2} = Slot.register(slot2, boat2)

    [slots: {slot1, slot2}, boats: {boat1, boat2}]
  end


  def three_slot_one_boat_two_slots_overlapping _context do

    # overlaps
    slot1 = Slot.new(@three_pm, 60)
    slot2 = Slot.new(@two_pm, 90)

    # non-overlap
    slot3 = Slot.new(@six_pm, 120)

    boat = Boat.new("Amazon Express", 10)

    {:ok, slot1, boat} = Slot.register(slot1, boat)
    {:ok, slot2, boat} = Slot.register(slot2, boat)
    {:ok, slot3, boat} = Slot.register(slot3, boat)

    [overlaps: {slot1, slot2}, non_overlap: slot3, boat: boat]
  end



end
