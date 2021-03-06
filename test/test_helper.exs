ExUnit.start()

defmodule Piranha.Test.Helper do
  # injects methods post! and get! etc..
  use HTTPoison.Base

  @url "http://127.0.0.1:3000"

  def create_rest_boat(name, size) when is_binary(name) and is_integer(size) do
    data = %{boat: %{capacity: size, name: name}}
    response = post!("/api/boats/", data, [])

    response
  end

  def create_rest_timeslot(start, duration) when is_integer(start) and is_integer(duration) do
    data = %{timeslot: %{start_time: start, duration: duration}}
    response = post!("/api/timeslots/", data, [])

    response
  end

  def create_rest_assignment(slot_id, boat_id)
      when is_binary(slot_id) and is_binary(boat_id) do
    data = %{assignment: %{timeslot_id: slot_id, boat_id: boat_id}}
    response = post!("/api/assignments", data, [])

    response
  end

  def create_rest_booking(slot_id, size)
      when is_binary(slot_id) and is_integer(size) do
    data = %{booking: %{timeslot_id: slot_id, size: size}}
    response = post!("/api/bookings/", data, [])

    response
  end

  def process_url(url) do
    @url <> url
  end

  def process_response_body(body) do
    try do
      # Note:
      # Atoms aren't garbarge collected, 
      # so we decode keys into existing atoms only otherwise error
      # Otherwise some one could do a DoS attack

      Poison.decode!(body, keys: :atoms!)
    rescue
      _ -> body
    end
  end

  def process_request_body(body) do
    Poison.encode!(body)
  end

  def process_request_headers(headers) do
    [{"Content-Type", "application/json"} | headers]
  end
end
