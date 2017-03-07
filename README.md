Piranha
==========

Piranha View Tours keeps a number of different river boats, and does tours at various times in the day.  We want to create a system that answers a simple question: "What is my availability today?"

## Assumptions

* Piranha View's customers book their tour against timeslots, which have a start time and a duration.
* Piranha View owns a number of boats, each of which can hold a different number of customers.
* Zero or more boats can be assigned to any given timeslot at any time.
* In order for customers to book a timeslot, there must be that number of available spots on a boat assigned to that timeslot.
* A booking consists of a group of one or more customers doing a Piranha View tour during a particular timeslot.
* A booking group cannot be split across different boats.
* A boat can only be used for a single timeslot at any given time.

## API specification

####POST /api/timeslots - create a timeslot
* Parameters:
  * timeslot[start_time]
    * Start time of the timeslot, expressed as a Unix timestamp
    * Example: 1406052000
  * timeslot[duration]
    * Length of the timeslots in minutes
    * Example: 120
* Output:
  * The created timeslot in JSON format, with the fields above, plus a unique ID, a customer count, an availability count, and a list of associated boat IDs
    * On a new timeslot, the availability and customer count will necessarily be 0, and the boats will be an empty list
  * Example: `{ id: abc123, start_time: 1406052000, duration: 120, availability: 0, customer_count: 0, boats: [] }`

####GET /api/timeslots - list timeslots
* Parameters:
  * date
    * Date in YYYY-MM-DD format for which to return timeslots
    * Example: 2014-07-22
* Output:
  * An array of timeslots in JSON format, in the same format as above
  * Example: `[{ id: abc123, start_time: 1406052000, duration: 120, availability: 4, customer_count: 4, boats: ['def456',...] }, ...]`
  * The customer count is the total number of customers booked for this timeslot.
  * The availability is the maximum booking size of any new booking on this timeslot. (See case 1 below)

####POST /api/boats - create a boat
* Parameters:
  * boat[capacity]
    * The number of passengers the boat can carry
    * Example: 8
  * boat[name]
    * The name of the boat
    * Example: "Amazon Express"
* Output:
  * The created boat in JSON format, with the fields above plus a unique ID
  * Example: `{ id: def456, capacity: 8, name: "Amazon Express" }`

####GET /api/boats - list boats
* Parameters:
  * none
* Output:
  * An array of boats in JSON format, in the same format as above
  * Example: `[{ id: def456, capacity: 8, name: "Amazon Express" }, ...]`

####POST /api/assignments - assign boat to timeslot
* Parameters:
  * assignment[timeslot_id]
    * A valid timeslot id
    * Example: abc123
  * assignment[boat_id]
    * A valid boat id
    * Example: def456
* Output:
  * none

####POST /api/bookings - create a booking
* Parameters:
  * booking[timeslot_id]
    * A valid timeslot id
    * Example: abc123
  * booking[size]
    * The size of the booking party
    * Example: 4
* Output:
  * none

##Test Cases
This repository contains a client with which you can construct and visualize test cases.  To get you started, here are a couple basic cases you'll want to handle:

####Case 1:
* POST /api/timeslots, params=`{ start_time: 1406052000, duration: 120 }`
* POST /api/boats, params=`{ capacity: 8, name: "Amazon Express" }`
* POST /api/boats, params=`{ capacity: 4, name: "Amazon Express Mini" }`
* POST /api/assignments, params=`{ timeslot_id: <timeslot-1-id>, boat_id: <boat-1-id> }`
* POST /api/assignments, params=`{ timeslot_id: <timeslot-1-id>, boat_id: <boat-2-id> }`
* GET /api/timeslots, params=`{ date: '2014-07-22' }`
    * correct response is:

        ```
        [
          {
            id:  <timeslot-1-id>,
            start_time: 1406052000,
            duration: 120,
            availability: 8,
            customer_count: 0,
            boats: [<boat-1-id>, <boat-2-id>]
          }
        ]
        ```

* POST /api/bookings, params=`{ timeslot_id: <timeslot-1-id>, size: 6 }`
* GET /api/timeslots, params=`{ date: "2014-07-22" }`
    * correct response is:

        ```
        [
          {
            id:  <timeslot-1-id>,
            start_time: 1406052000,
            duration: 120,
            availability: 4,
            customer_count: 6,
            boats: [<boat-1-id>, <boat-2-id>]
          }
        ]
        ```

* Explanation: The first party of six goes on the Amazon Express, leaving 2 slots on that boat and 4 on the other.  The max party you can now handle is four.

####Case 2:
* POST /api/timeslots, params=`{ start_time: 1406052000, duration: 120 }`
* POST /api/timeslots, params=`{ start_time: 1406055600, duration: 120 }`
* POST /api/boats, params=`{ capacity: 8, name: "Amazon Express" }`
* POST /api/assignments, params=`{ timeslot_id: <timeslot-1-id>, boat_id: <boat-1-id> }`
* POST /api/assignments, params=`{ timeslot_id: <timeslot-2-id>, boat_id: <boat-1-id> }`
* GET /api/timeslots, params=`{ date: '2014-07-22' }`
    * correct response is:

        ```
        [
          {
            id:  <timeslot-1-id>,
            start_time: 1406052000,
            duration: 120,
            availability: 8,
            customer_count: 0,
            boats: [<boat-1-id>]
          },
          {
            id:  <timeslot-2-id>,
            start_time: 1406055600,
            duration: 120,
            availability: 8,
            customer_count: 0,
            boats: [<boat-1-id>]
          }
        ]
        ```

* POST /api/bookings, params=`{ timeslot_id: <timeslot-2-id>, size: 2 }`
* GET /api/timeslots, params=`{ date: '2014-07-22' }`
  * correct response is:

      ```
      [
        {
          id:  <timeslot-1-id>,
          start_time: 1406052000,
          duration: 120,
          availability: 0,
          customer_count: 0,
          boats: [<boat-1-id>]
        },
        {
          id:  <timeslot-2-id>,
          start_time: 1406055600,
          duration: 120,
          availability: 6,
          customer_count: 2,
          boats: [<boat-1-id>]
        }
      ]
      ```

* Explanation: Once you book against the second timeslot, it is now using the boat.  It gets the boat's remaining capacity, leaving the other timeslot without a boat and unbookable.





## Implementation Details

These details correspond to `Case 2` from above

```elixir

  # Unix Timestamps

  @six_pm               1406052000
  @seven_pm             1406055600

  # UIDs

  @slot_6pm_to_8pm      "abj3DjVtjZ"
  @slot_7pm_to_9pm      "abj3GAGijZ"

  @amazon_express_8     "GMCQLu1VInVfLyhRDUdoFlFG2fXwu7lcKNh2mT8WFzO"

  slot1_resp = Helper.create_rest_timeslot(@six_pm, 120)
  slot2_resp = Helper.create_rest_timeslot(@seven_pm, 120)

  boat1_resp = Helper.create_rest_boat("Amazon Express", 8)

  Helper.create_rest_assignment(@slot_6pm_to_8pm, @amazon_express_8)
  Helper.create_rest_assignment(@slot_7pm_to_9pm, @amazon_express_8)

  _response = Helper.create_rest_booking(@slot_7pm_to_9pm, 2)
```


### Data Structure Output

```elixir

%Piranha.Boat{
        # Max boat capacity
        capacity: 8,
        # We keep a map of slot ids that have successfully made a reservation booking
        confirmation: %{"abj3GAGijZ" => true},   
        # We keep a map of slot ids that have been excluded because an overlapping time slot id has already made a booking
        exclusion: %{"abj3DjVtjZ" => true},      
        # Boat id string
        id: "GMCQLu1VInVfLyhRDUdoFlFG2fXwu7lcKNh2mT8WFzO", 
        # Boat name
        name: "Amazon Express", 		
        # Appointments map, indexed by half hour (doesn't guarentee boat use but registers boat)
        # Implemented via hash tables (substitutes for an interval search tree)
        requests_by_time: %{			
                        "2014-07-22 18:00" => #MapSet<[
                                    %Piranha.Interval{date: "2014-07-22", duration: 120, finish: #<DateTime(2014-07-22T20:00:00Z Etc/UTC)>, id: "abj3DjVtjZ", start: #<DateTime(2014-07-22T18:00:00Z Etc/UTC)>, unix_finish: 1406059200, unix_start: 1406052000}]>, 
                        "2014-07-22 18:30" => #MapSet<[
                                    %Piranha.Interval{date: "2014-07-22", duration: 120, finish: #<DateTime(2014-07-22T20:00:00Z Etc/UTC)>, id: "abj3DjVtjZ", start: #<DateTime(2014-07-22T18:00:00Z Etc/UTC)>, unix_finish: 1406059200, unix_start: 1406052000}]>, 
                        "2014-07-22 19:00" => #MapSet<[
                                    %Piranha.Interval{date: "2014-07-22", duration: 120, finish: #<DateTime(2014-07-22T20:00:00Z Etc/UTC)>, id: "abj3DjVtjZ", start: #<DateTime(2014-07-22T18:00:00Z Etc/UTC)>, unix_finish: 1406059200, unix_start: 1406052000}, 
                                    %Piranha.Interval{date: "2014-07-22", duration: 120, finish: #<DateTime(2014-07-22T21:00:00Z Etc/UTC)>, id: "abj3GAGijZ", start: #<DateTime(2014-07-22T19:00:00Z Etc/UTC)>, unix_finish: 1406062800, unix_start: 1406055600}]>, 
                        "2014-07-22 19:30" => #MapSet<[
                                    %Piranha.Interval{date: "2014-07-22", duration: 120, finish: #<DateTime(2014-07-22T20:00:00Z Etc/UTC)>, id: "abj3DjVtjZ", start: #<DateTime(2014-07-22T18:00:00Z Etc/UTC)>, unix_finish: 1406059200, unix_start: 1406052000}, 
                                    %Piranha.Interval{date: "2014-07-22", duration: 120, finish: #<DateTime(2014-07-22T21:00:00Z Etc/UTC)>, id: "abj3GAGijZ", start: #<DateTime(2014-07-22T19:00:00Z Etc/UTC)>, unix_finish: 1406062800, unix_start: 1406055600}]>, 
                        "2014-07-22 20:00" => #MapSet<[
                                    %Piranha.Interval{date: "2014-07-22", duration: 120, finish: #<DateTime(2014-07-22T21:00:00Z Etc/UTC)>, id: "abj3GAGijZ", start: #<DateTime(2014-07-22T19:00:00Z Etc/UTC)>, unix_finish: 1406062800, unix_start: 1406055600}]>, 
                        "2014-07-22 20:30" => #MapSet<[
                                    %Piranha.Interval{date: "2014-07-22", duration: 120, finish: #<DateTime(2014-07-22T21:00:00Z Etc/UTC)>, id: "abj3GAGijZ", start: #<DateTime(2014-07-22T19:00:00Z Etc/UTC)>, unix_finish: 1406062800, unix_start: 1406055600}]>
                           }
} 

```

```elixir
%Piranha.Slot{
        # Time slot available spots so far
        available: 6, 				
        # Boat ids list of currently registered boats
        boat_ids: ["GMCQLu1VInVfLyhRDUdoFlFG2fXwu7lcKNh2mT8WFzO"],  
        # Sorted set by boat status availability, implemented through :gb_sets -- O(log N) to retrieve boat which matches requested size
        boat_statuses_by_avail: {1, {%Piranha.Boat.Status{available: 6, customer_count: 2, id: "GMCQLu1VInVfLyhRDUdoFlFG2fXwu7lcKNh2mT8WFzO"}, nil, nil}},
        # Map to directly index into boat status availability -- O(1)
        boat_statuses_by_id: %{"GMCQLu1VInVfLyhRDUdoFlFG2fXwu7lcKNh2mT8WFzO" => %Piranha.Boat.Status{available: 6, customer_count: 2, id: "GMCQLu1VInVfLyhRDUdoFlFG2fXwu7lcKNh2mT8WFzO"}},  
        # Customers booked hence far
        customer_count: 2, 			
        # Slot id
        id: "abj3GAGijZ", 			
        # Interval time period associated with this time slot
        interval: %Piranha.Interval{date: "2014-07-22", duration: 120, finish: #<DateTime(2014-07-22T21:00:00Z Etc/UTC)>, id: "abj3GAGijZ", start: #<DateTime(2014-07-22T19:00:00Z Etc/UTC)>, unix_finish: 1406062800, unix_start: 1406055600}
}  


%Piranha.Slot{
        # Time slot available spots so far
        available: 0, 				
        # Boat ids list of currently registered boats
        boat_ids: ["GMCQLu1VInVfLyhRDUdoFlFG2fXwu7lcKNh2mT8WFzO"],  
        # Sorted set by boat status availability, implemented through :gb_sets -- O(log N) to retrieve boat which matches requested size
        boat_statuses_by_avail: {1, {%Piranha.Boat.Status{available: 0, customer_count: 0, id: "GMCQLu1VInVfLyhRDUdoFlFG2fXwu7lcKNh2mT8WFzO"}, nil, nil}},   
        # Map to directly index into boat status availability -- O(1)
        boat_statuses_by_id: %{"GMCQLu1VInVfLyhRDUdoFlFG2fXwu7lcKNh2mT8WFzO" => %Piranha.Boat.Status{available: 0, customer_count: 0, id: "GMCQLu1VInVfLyhRDUdoFlFG2fXwu7lcKNh2mT8WFzO"}},     
        # Customers booked hence far
        customer_count: 0, 			
        # Slot id
        id: "abj3DjVtjZ", 			
        # Interval time period associated with this time slot
        interval: %Piranha.Interval{date: "2014-07-22", duration: 120, finish: #<DateTime(2014-07-22T20:00:00Z Etc/UTC)>, id: "abj3DjVtjZ", start: #<DateTime(2014-07-22T18:00:00Z Etc/UTC)>, unix_finish: 1406059200, unix_start: 1406052000}
}  
```



## NOTES

The Piranha project has the following abstractions:

* Boat
  * Manages an appointments list of slots requesting to use the boat given their time interval
  * Its slots are just pointers (ids) to the real time slots
  * Keeps track of slots that have been confirmed or excluded via a successful booking reservation
* Slot (Time Slot)
  * Keeps track of the boat status availabilities of its boats
  * Tracks availabilities left and customers booked so far
  * Its boats are just pointers (ids) to the real boats
* Interval (Time Interval)
  * Determines whether a time interval overlaps another
* Web (Web Router)
  * Implements REST routing layer via the Maru REST micro-framework 
    (choosen here for its simplicity, e.g. 1 file)
* Controller
  * Maps request to appropriate application / db logic
* Worker
  * Serves as a basic GenServer to illustrate queueing / synchronization (should really be a pool) and 
    to potentially provide overflow handling
* Database
  * Implemented via built-in Mnesia using the Amnesia Elixir wrapper
  * Defines two tables: Appointment and Vessel
  * The Appointment table has a secondary index on the :date field
  * Mnesia apparently is one of the building blocks along with "Unicorn blood" to make Riak
  * To fully scale this solution, you would want to replicate this data to other nodes
    which Mnesia can do though (usually up to 10) and it has issues with netsplits in some cases
    (something Riak can handle provided you specify the callbacks).
    The point being, keeping db logic simpler and using tables as put / get stores for 
    more complicated aggregate data structures w/ transactions or explicit conflict resolution 
    would work well to scale without having to encounter some of the scalability concerns 
    of traditional relational stores
  * Complications would arise depending on how many conflicts happen.  Given this project
    our two entities are slots and boats.  E.g.  How many time slots
    overlap and involving what degree of the same boats?  We mainly write to the DB upon 
    assignment registration and boat reservation and more so when we have made the reservation booking but 
    have hence excluded a number of other slots for being able to use the boat.
  * Conflict resolution strategies include locking, retrying transactions, vector clock based - 
    last write wins or manual intervention


## Comments

This was quite a challenging project, but one that I couldn't ignore, and that I 
very much enjoyed writing along the way.

I was originally going to use some relational database with these relation tuples:

```elixir
Tour:  {tour_id, booking_id}
Booking:  {booking_id, time_slot_id, boat_id, size}
Timeslot: {time_slot_id, start_time, duration, available, customer_count}
Assignment: {time_slot_id, boat_id}
Boat: {id, name, capacity, available, customer_count}
```

Then after a lot of thinking, I realized that this project could be opportunity to explore a 
solution that didn't follow the conventional relational data store, something that could ultimately 
scale across other nodes in a distributed way but something that didn't necessarily do joins that well.

So I thought of basically fetching and retrieving aggregate data structures into `Mnesia` and designing
those structures with less of a need for relational joins.

I deconstructed `Boat` relation into `{id, name, capacity}` and then a new 
`Boat.Status` into `{id, available, customer_count}`

I realized that `Assignment` could be a data structure within boat (atleast a subset of all the assignments
specific to that boat's world -- so as to not have to join) and that it would need to be made quickly
searchable via a time stamp key. So I used a `Map (Hashtable) of MapSets` indexed by half hour key.  

For the time slot, all those fields were great and something I could encapsulate within a module while 
providing an efficient structure to retrieve the best matching boat availability as I decided on a sorted set.
Erlang has some cool functional data structures, `:gb_sets` is one of them!

If you look at `Slot`, it has a subset of the boat availability info, but only as it pertains to that Slot.
This also eliminated any need for joins, helpful in NoSQL world.

I wanted my call relationships to follow a DAG. So `Slot -> Boat` as opposed to `Slot <-> Boat`.
As I thought this would be harder to decouple and easier to reason about

Before I decided on the `Amnesia` solution, I stubbed it out with an `Agent` which contained a map consisting of
a Calendar and Fleet abstraction, storing slots and boats respectively.  These were glorified maps mostly.  

At one point `Slot` took in a `Calendar` abstraction and `Fleet` abstraction, but I removed this coupling and 
only allowed a map of `Slots` or `Boats` in and figured this extra data could be generated at a higher
level in the stack at the `Controller` level when wrapped inside the `Amnesia` transaction to get
the supplementary data.

Once this worked, I substituted in the Mnesia version which is sweet (minus the netsplits).

I ended up scrapping the `Tour` relation and reflected the `Booking` relation status within the Boat via a confirmation map.


## Lastly on Usage

If you want to blow away the database, just type mix uninstall and you can test out a fresh new state
when you run iex -S mix again. The mix uninstall task is defined in database.ex




Thanks!
Bibek