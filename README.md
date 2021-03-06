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
        # We keep a mapset of slot ids that have successfully made a reservation booking
        confirmation: #MapSet<["abj3GAGijZ"]>,   
        # We keep a mapset of slot ids that have been excluded because an overlapping slot id has already made a booking
        exclusion: #MapSet<["abj3DjVtjZ"]>,
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
  * Its slots are simply pointers (ids) to the real time slots -- allowing for looser coupling
  * Keeps track of slots that have been confirmed via a successful booking reservation or excluded by overlapping slot use
* Slot (Time Slot)
  * Keeps track of the boat status availabilities of its boats
  * Tracks availabilities left and customers booked so far
  * Its boats are simply pointers (ids) to the real boats -- allowing for looser coupling
* Interval (Time Interval)
  * Determines whether a time interval overlaps another
* Web (Web Router)
  * Implements REST routing layer via the Maru web micro-framework 
    (choosen here for its simplicity, e.g. 1 file)
* Controller
  * Maps request to appropriate application / db logic
* Worker
  * Serves as a basic GenServer to illustrate synchronized queuing that could even provide overflow handling.
  * Ultimately should be a worker pool or pool of pools (poolboy).
* Database
  * Implemented via built-in Mnesia using the Amnesia Elixir wrapper
  * Defines two tables: Appointment and Vessel
  * The Appointment table has a secondary index on the :date field
  * Mnesia apparently is one of the building blocks along with "Unicorn blood" to make Riak
  * To fully scale this solution, you would want to replicate this data to other nodes
    which Mnesia can do though usually up to 10 nodes.  Though it has issues with netsplits 
    in some cases, something like Riak can handle this provided you specify the callbacks.
    Keeping the db logic simpler and using tables for fetch and retrieve operations of aggregate
    data structures could be a very good idea.  However, transactional locking or explicit
    conflict resolution would have to be handled but may scale better than a relational data store.
  * Complications would arise depending on how many conflicts happen.  Given this project
    our two main entities are slots and boats.  Relevant points are:
      * How many time slots overlap and involving what degree of boats? Are these boats the same?  
      * We mainly write to the DB upon assignment registration and boat reservation.
      * When we make a reservation booking which leaves a high number of excluded overlapping slots, 
        this increases the slots we need to update as well.
  * Conflict resolution strategies include locking, retrying transactions, (and in Riak world) 
    vector clock based - last write wins or manual intervention


## Comments

This was quite a challenging project, but one that I couldn't resist. 
I greatly enjoyed writing it and learned a ton.

I was originally going to use some relational database with these relation tuples:

```elixir
Tour:  {tour_id, booking_id}
Booking:  {booking_id, time_slot_id, boat_id, size}
Timeslot: {time_slot_id, start_time, duration, available, customer_count}
Assignment: {time_slot_id, boat_id}
Boat: {id, name, capacity, available, customer_count}
```

Then after a lot of thinking, I realized that this project could be an opportunity to explore a 
solution that didn't follow the conventional relational data store model.  One that could
ultimately scale across distributed nodes.

I thought of fetching and retrieving aggregate data structures into `Mnesia` and designing
those structures to be more self-sufficient with less of a need for relational joins.

I deconstructed `Boat` relation into `{id, name, capacity}` and then added a new 
`Boat.Status` relation with fields `{id, available, customer_count}`

I realized that `Assignment` could be a data structure within `Boat` (all the assignments
specific to that boat's world).  This would need to be quickly searchable via a time stamp key. 
I used a `Map (Hashtable) of MapSets` indexed by half hour key(s).

For the time slot, I needed an efficient structure to retrieve the best matching boat
 availability.  Erlang has some cool functional data structures, so I decided to use `:gb_sets` as 
my sorted set implementation. 

I modeled `Slot` to have a subset of the boat availability info, pertaining to that specific Slot.
This also eliminated any need for joins.

I wanted my call relationships to follow a DAG. So `Slot -> Boat`, Slot calling Boat as opposed to `Slot <-> Boat`.
I thought this would be better decoupling and easier to reason about

Before I decided on the `Amnesia` solution, I stubbed it out with an `Agent` consisting of
a map with a Calendar and Fleet abstraction, storing slots and boats respectively.  These were glorified maps mostly.  

At one point `Slot` took in a `Calendar` abstraction and `Fleet` abstraction, but I removed this coupling and 
only allowed a map of `Slots` or `Boats`. I figured this extra data could be generated at a higher
level in the stack.  It ended up at the `Controller` level when wrapped inside the `Amnesia` transaction to get
the Slot and Boat id:values.

Once this worked, I substituted in the Mnesia version.

I ended up scrapping the `Tour` relation and injecting the `Booking` relation fields within Boat via a confirmation set.


## Visualization
![Visualization](https://raw.githubusercontent.com/brpandey/piranha/master/priv/images/visualization.png)


## Lastly
If you want to blow away the database, just type mix db_uninstall and you can test out a fresh new state
when you run iex -S mix again. The mix db_uninstall task is defined in database.ex

Starting the app is as easy as iex -S mix in the project directory which will run the server on localhost:3000

There are a range of tests but not exhaustive in the test/piranha folder


## Thanks!

Bibek
