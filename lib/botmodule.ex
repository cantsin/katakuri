defmodule BotModule do
  use Behaviour

  @doc "Description."
  defcallback doc() :: String

  @doc "Startup."
  defcallback start()

  @doc "Processes a given message."
  defcallback process(message :: Client.Message)

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
