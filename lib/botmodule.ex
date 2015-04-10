defmodule BotModule do
  use Behaviour

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
