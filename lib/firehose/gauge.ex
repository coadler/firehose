defmodule Firehose.Gauge do
  @moduledoc """
  
  """

  use GenServer

  require Logger

  def start_link(opts \\ []) do
    check_interval = opts[:check_interval] || 200
    GenServer.start_link(__MODULE__, [check_interval: check_interval])
  end

  def init(state) do
    Process.send_after(self(), :run_check, state[:check_interval])
  end

  def handle_info(:run_check, state) do
    Process.send_after(self(), :run_check, state[:check_interval])
    Firehose.Pump.queue_length()
  end
end
