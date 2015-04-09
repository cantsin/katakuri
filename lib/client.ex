defmodule Client do
  @behaviour :websocket_client_handler

  def init(state, socket) do
    {:ok, state}
  end

  def websocket_handle({:text, message}, _connection, state) do
    IO.puts message
    {:ok, state}
  end

  def websocket_handle({:ping, data}, _connection, state) do
    {:reply, {:pong, data}, state}
  end

  def websocket_info(:start, _connection, state) do
    {:ok, state}
  end

  def websocket_terminate(reason, _connection, state) do
    :ok
  end
end
