defmodule BotModule do
  use Behaviour
  use GenEvent

  @doc "Description."
  defcallback doc() :: String

  @doc "Startup."
  defcallback start

  @doc "Processes a given message."
  defcallback process_message(message :: Client.Message)

  # Eventually...
  # @doc "Processes a given event."
  # defcallback process_event(event :: Event)

  @doc "Cleanup, if applicable."
  defcallback stop(reason :: String)
end

defmodule BotModule.DB do
  use Behaviour

  @doc "Create database tables."
  defcallback create()
end

defmodule BotModuleWorker do
  use GenServer
  require Logger

  def start_link([botmodule]) do
    GenServer.start_link(__MODULE__, [botmodule], name: botmodule)
  end

  def init([botmodule]) do
    {:ok, %{botmodule: botmodule}}
  end

  def handle_cast({:client_start, []}, state) do
    state.botmodule.start
    {:noreply, state}
  end

  def handle_cast({:client_message, [message]}, state) do
    state.botmodule.process_message message
    {:noreply, state}
  end

  def handle_cast({:client_stop, [reason]}, state) do
    state.botmodule.stop reason
    {:noreply, state}
  end
end

defmodule BotModuleManager do
  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    {:ok, _} = GenEvent.start_link(name: Event)
    children = Enum.map(Katakuri.modules, fn m ->
      worker(BotModuleWorker, [[m]], id: m)
    end)
    supervise(children, strategy: :one_for_one)
  end

  def start do
    Enum.map(Katakuri.modules, fn m -> GenServer.cast(m, {:client_start, []}) end)
  end

  def process_message(message) do
    Enum.map(Katakuri.modules, fn m -> GenServer.cast(m, {:client_message, [message]}) end)
  end

  def stop(reason) do
    Enum.map(Katakuri.modules, fn m -> GenServer.cast(m, {:client_stop, [reason]}) end)
  end
end
