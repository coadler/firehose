defmodule Firehose.Nozzle.AMQP do
  use GenStage

  def start_link(_args) do
    GenStage.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    {:ok, conn} = AMQP.Connection.open "amqp://guest:guest@127.0.0.1:5672"
    {:ok, chan} = AMQP.Channel.open(conn)
    state = %{ :conn => conn, :channel => chan }
    {:consumer, state, subscribe_to: [Firehose.Pump]}
  end

  def handle_events(events, _from, state) do
    # Send the events to AMQP.
    send_events(events, state)

    # We are a consumer, so we would never emit items.
    {:noreply, [], state}
  end

  defp send_events([head | tail], state) do
    AMQP.Basic.publish(state[:channel], "", "events", :erlang.term_to_binary(head))
    send_events(tail, state)
  end

  defp send_events([], _state) do
    :ok
  end
end
