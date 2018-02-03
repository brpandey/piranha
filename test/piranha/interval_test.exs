defmodule Piranha.Interval.Test do
  use ExUnit.Case, async: true

  alias Piranha.{Interval}

  # Times for 2014-07-22
  @two_pm 1_406_037_600
  @three_pm 1_406_041_200
  @six_pm 1_406_052_000

  describe "bucket keys" do
    test "Given a slot interval whose start time is aligned and end time is aligned" do
      # 2:00 - 3:00
      i = Interval.new(@two_pm, 60)

      assert ["2014-07-22 14:00", "2014-07-22 14:30"] = Interval.bucket_keys(i)
    end

    test "Given a slot interval whose start time is aligned and end time is not aligned" do
      # 2:00 - 3:16
      i = Interval.new(@two_pm, 76)

      assert ["2014-07-22 14:00", "2014-07-22 14:30", "2014-07-22 15:00"] =
               Interval.bucket_keys(i)
    end

    test "Given a slot interval whose start time is not aligned and end time is aligned" do
      # 2:11 - 3:00
      i = Interval.new(@two_pm + 660, 49)

      assert ["2014-07-22 14:00", "2014-07-22 14:30"] = Interval.bucket_keys(i)
    end

    test "Given a slot interval whose start time is not aligned and end time is not aligned" do
      # 2:11 - 3:11
      i = Interval.new(@two_pm + 660, 60)

      assert ["2014-07-22 14:00", "2014-07-22 14:30", "2014-07-22 15:00"] =
               Interval.bucket_keys(i)
    end
  end

  describe "overlaps" do
    test "first time slot starts earlier than second" do
      # 2:00 - 3:15
      s1 = Interval.new(@two_pm, 75)
      # 3:00 - 3:40
      s2 = Interval.new(@three_pm, 40)

      assert true == Interval.overlap?(s1, s2)
    end

    test "first time slot starts after second" do
      # 3:00 - 3:40
      s1 = Interval.new(@three_pm, 40)
      # 2:00 - 3:15
      s2 = Interval.new(@two_pm, 75)

      assert true == Interval.overlap?(s1, s2)
    end

    test "first time slot starts and ends within second" do
      # 3:00 - 3:40
      s1 = Interval.new(@three_pm, 40)
      # 2:00 - 4:20
      s2 = Interval.new(@two_pm, 140)

      assert true == Interval.overlap?(s1, s2)
    end

    test "second time slot starts and ends within first" do
      # 2:00 - 4:20
      s1 = Interval.new(@two_pm, 140)
      # 3:00 - 3:40
      s2 = Interval.new(@three_pm, 40)

      assert true == Interval.overlap?(s1, s2)
    end

    test "non-overlapping time slots" do
      # 3:00 - 3:40
      s1 = Interval.new(@three_pm, 40)
      # 2:00 - 2:40
      s2 = Interval.new(@two_pm, 40)
      # 6:00 - 7:20
      s3 = Interval.new(@six_pm, 80)

      assert false == Interval.overlap?(s1, s2)
      assert false == Interval.overlap?(s2, s3)
      assert false == Interval.overlap?(s3, s1)
    end
  end
end
