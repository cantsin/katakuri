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

  def timestamp_to_calendar(ts) do
    {{ts.year, ts.month, ts.day}, {ts.hour, ts.min, ts.sec}}
  end

  def write!(query, args \\ []) do
    GenServer.cast(:database, {:write!, [query, args]})
  end

  def query?(query, args \\ []) do
    GenServer.call(:database, {:query?, [query, args]})
  end

  def handle_cast({:write!, [query, args]}, state) do
    Postgrex.Connection.query!(state.db_pid, query, args)
    {:noreply, state}
  end

  def handle_call({:query?, [query, args]}, _from, state) do
    result = Postgrex.Connection.query!(state.db_pid, query, args)
    {:reply, result, state}
  end

  def init(:ok) do
    {:ok, pid} = Postgrex.Connection.start_link(extensions: [{Extensions.JSON, library: Poison}],
                                                hostname: @db_hostname,
                                                username: @db_username,
                                                password: @db_password,
                                                database: @db_database)
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
