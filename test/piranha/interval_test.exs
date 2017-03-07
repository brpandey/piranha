defmodule Piranha.Interval.Test do
  use ExUnit.Case, async: true
  
  alias Piranha.{Interval}


  # Times for 2014-07-22
  @two_pm    1406037600
  @three_pm  1406041200
  @six_pm    1406052000


  describe "bucket keys" do

    test "Given a slot interval whose start time is aligned and end time is aligned" do
      i = Interval.new(@two_pm, 60) # 2:00 - 3:00

      assert ["2014-07-22 14:00", "2014-07-22 14:30"] 
      = Interval.bucket_keys(i)
    end


    test "Given a slot interval whose start time is aligned and end time is not aligned" do
      i = Interval.new(@two_pm, 76) # 2:00 - 3:16

      assert ["2014-07-22 14:00", "2014-07-22 14:30", "2014-07-22 15:00"] 
      = Interval.bucket_keys(i)
    end


    test "Given a slot interval whose start time is not aligned and end time is aligned" do
      i = Interval.new(@two_pm + 660, 49) # 2:11 - 3:00

      assert ["2014-07-22 14:00", "2014-07-22 14:30"] 
      = Interval.bucket_keys(i)
    end


    test "Given a slot interval whose start time is not aligned and end time is not aligned" do
      i = Interval.new(@two_pm + 660, 60) # 2:11 - 3:11

      assert ["2014-07-22 14:00", "2014-07-22 14:30", "2014-07-22 15:00"] 
      = Interval.bucket_keys(i)
    end


  end


  describe "overlaps" do

    test "first time slot starts earlier than second" do
      s1 = Interval.new(@two_pm, 75) # 2:00 - 3:15
      s2 = Interval.new(@three_pm, 40) # 3:00 - 3:40
      
      assert true == Interval.overlap?(s1, s2)
    end


    test "first time slot starts after second" do
      s1 = Interval.new(@three_pm, 40) # 3:00 - 3:40
      s2 = Interval.new(@two_pm, 75) # 2:00 - 3:15
      
      assert true == Interval.overlap?(s1, s2)
    end


    test "first time slot starts and ends within second" do
      s1 = Interval.new(@three_pm, 40) # 3:00 - 3:40
      s2 = Interval.new(@two_pm, 140) # 2:00 - 4:20
      
      assert true == Interval.overlap?(s1, s2)
    end


    test "second time slot starts and ends within first" do
      s1 = Interval.new(@two_pm, 140) # 2:00 - 4:20
      s2 = Interval.new(@three_pm, 40) # 3:00 - 3:40
      
      assert true == Interval.overlap?(s1, s2)
    end


    test "non-overlapping time slots" do
      s1 = Interval.new(@three_pm, 40) # 3:00 - 3:40
      s2 = Interval.new(@two_pm, 40) # 2:00 - 2:40
      s3 = Interval.new(@six_pm, 80) # 6:00 - 7:20

      assert false == Interval.overlap?(s1, s2)
      assert false == Interval.overlap?(s2, s3)
      assert false == Interval.overlap?(s3, s1)
    end

  end

end
