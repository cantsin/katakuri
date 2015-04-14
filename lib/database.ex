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

  def write_message(message) do
    GenServer.cast(:database, {:write_message, message})
  end

  def subscribe_happiness(username, subscribed) do
    GenServer.cast(:database, {:subscribe_happiness, [username, subscribed]})
  end

  def handle_call(_what, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast({:write_message, message}, state) do
    Postgrex.Connection.query!(state.db_pid, "INSERT INTO messages(message) VALUES($1)", [message])
    {:noreply, state}
  end

  def handle_cast({:subscribe_happiness, data}, state) do
    [username, subscribed] = data
    result = Postgrex.Connection.query!(state.db_pid, "SELECT id FROM happiness WHERE username = $1", [username])
    command = if result.num_rows == 0 do
                "INSERT INTO happiness(username, subscribe) VALUES($1, $2)"
              else
                "UPDATE happiness SET subscribed = $2 WHERE username = $1"
              end
    Postgrex.Connection.query!(state.db_pid, command, [username, subscribed])
    {:noreply, state}
  end

  def init(:ok) do
    {:ok, pid} = Postgrex.Connection.start_link(extensions: [{Extensions.JSON, library: Poison}],
                                                hostname: @db_hostname,
                                                username: @db_username,
                                                password: @db_password,
                                                database: @db_database)
    Postgrex.Connection.query!(pid, "CREATE TABLE IF NOT EXISTS messages(id serial PRIMARY KEY, message JSON)", [])
    Postgrex.Connection.query!(pid, "CREATE TABLE IF NOT EXISTS happiness(id serial PRIMARY KEY, username CHARACTER(10), subscribed BOOLEAN)", [])
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
