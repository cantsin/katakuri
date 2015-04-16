defmodule SlackDatabase do

  use GenServer

  require Logger

  @db_hostname "localhost"
  @db_username "postgres"
  @db_password "postgres"
  @db_database "katakuri"

  def start_link(_state) do
    GenServer.start_link(__MODULE__, :ok, [name: :database])
  end

  ## generic functions.
  def timestamp_to_calendar(ts) do
    {{ts.year, ts.month, ts.day}, {ts.hour, ts.min, ts.sec}}
  end

  ## logging.
  def write_message(message) do
    GenServer.cast(:database, {:write_message, message})
  end

  ## happiness.
  def save_reply(value) do
    GenServer.cast(:database, {:save_reply, [value]})
  end

  def add_notification(username, interval) do
    GenServer.cast(:database, {:add_notification, [username, interval]})
  end

  def remove_notification(username) do
    GenServer.cast(:database, {:remove_notification, [username]})
  end

  def get_notifications do
    GenServer.call(:database, {:get_notifications, []})
  end

  def get_current_notifications do
    GenServer.call(:database, {:get_current_notifications, []})
  end

  def subscribe_happiness(username, subscribed) do
    GenServer.call(:database, {:subscribe_happiness, [username, subscribed]})
  end

  def get_happiness_levels do
    GenServer.call(:database, {:get_happiness_levels, []})
  end

  def awaiting_reply?(username) do
    GenServer.call(:database, {:awaiting_reply?, [username]})
  end

  def handle_call({:subscribe_happiness, data}, _from, state) do
    [username, subscribed] = data
    result = Postgrex.Connection.query!(state.db_pid, "SELECT subscribed FROM subscriptions WHERE username = $1", [username])
    [command, retval] = if result.num_rows == 0 do
                ["INSERT INTO subscriptions(username, subscribed) VALUES($1, $2)", :ok]
              else
                {current} = List.first result.rows
                is_changed = if current != subscribed do :ok else :error end
                ["UPDATE subscriptions SET subscribed = $2 WHERE username = $1", is_changed]
              end
    Postgrex.Connection.query!(state.db_pid, command, [username, subscribed])
    {:reply, retval, state}
  end

  def handle_call({:get_happiness_levels, []}, _from, state) do
    result = Postgrex.Connection.query!(state.db_pid, "SELECT value, created FROM happiness", [])
    {:reply, result.rows, state}
  end

  def handle_call({:awaiting_reply?, [username]}, _from, state) do
    result = Postgrex.Connection.query!(state.db_pid, "SELECT date FROM notifications WHERE username = $1", [username])
    if result.num_rows == 0 do
      {:reply, nil, state}
    else
      {date} = List.first result.rows
      {:reply, date, state}
    end
  end

  def handle_call({:get_notifications, []}, _from, state) do
    result = Postgrex.Connection.query!(state.db_pid, "SELECT username, date FROM notifications", [])
    {:reply, result.rows, state}
  end

  def handle_call({:get_current_notifications, []}, _from, state) do
    result = Postgrex.Connection.query!(state.db_pid, "SELECT username, date FROM notifications WHERE date <= NOW()", [])
    {:reply, result.rows, state}
  end

  def handle_cast({:remove_notification, [username]}, state) do
    Postgrex.Connection.query!(state.db_pid, "DELETE FROM notifications WHERE username = $1", [username])
    {:noreply, state}
  end

  def handle_cast({:add_notification, [username, interval]}, state) do
    Postgrex.Connection.query!(state.db_pid, "INSERT INTO notifications(username, date) VALUES($1, NOW() + interval '$2 seconds')", [username, interval])
    {:noreply, state}
  end

  def handle_cast({:write_message, message}, state) do
    Postgrex.Connection.query!(state.db_pid, "INSERT INTO messages(message) VALUES($1)", [message])
    {:noreply, state}
  end

  def handle_cast({:save_reply, [value]}, state) do
    Postgrex.Connection.query!(state.db_pid, "INSERT INTO happiness(value) VALUES($1)", [value])
    {:noreply, state}
  end

  def init(:ok) do
    {:ok, pid} = Postgrex.Connection.start_link(extensions: [{Extensions.JSON, library: Poison}],
                                                hostname: @db_hostname,
                                                username: @db_username,
                                                password: @db_password,
                                                database: @db_database)
    Postgrex.Connection.query!(pid, "CREATE TABLE IF NOT EXISTS messages(id serial PRIMARY KEY, message JSON)", [])
    Postgrex.Connection.query!(pid, "CREATE TABLE IF NOT EXISTS subscriptions(id serial PRIMARY KEY, username CHARACTER(10), subscribed BOOLEAN)", [])
    Postgrex.Connection.query!(pid, "CREATE TABLE IF NOT EXISTS notifications(id serial PRIMARY KEY, username CHARACTER(10), date TIMESTAMPTZ)", [])
    Postgrex.Connection.query!(pid, "CREATE TABLE IF NOT EXISTS happiness(id serial PRIMARY KEY, value INTEGER, created TIMESTAMPTZ DEFAULT current_timestamp)", [])
    Logger.info "Postgrex enabled."

    state = %{db_pid: pid}
    {:ok, state}
  end
end

defmodule Extensions.JSON do
  alias Postgrex.TypeInfo

  @behaviour Postgrex.Extension
  @moduledoc "Encode and decode Elixir maps to Postgres' JSON."

  def init(_parameters, opts),
    do: Keyword.fetch!(opts, :library)

  def matching(_library),
    do: [type: "json", type: "jsonb"]

  def format(_library),
    do: :binary

  def encode(%TypeInfo{type: "json"}, map, _state, library),
    do: library.encode!(map)
  def encode(%TypeInfo{type: "jsonb"}, map, _state, library),
    do: <<1, library.encode!(map)::binary>>

  def decode(%TypeInfo{type: "json"}, json, _state, library),
    do: library.decode!(json)
  def decode(%TypeInfo{type: "jsonb"}, <<1, json::binary>>, _state, library),
    do: library.decode!(json)
end
