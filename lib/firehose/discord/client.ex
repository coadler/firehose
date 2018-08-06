defmodule Firehose.Discord.Client do
  @moduledoc """

  """

  require Logger

  import Firehose.Discord.Utility

  @behaviour :websocket_client

  def opcodes do
    %{
      :dispatch               => 0,
      :heartbeat              => 1,
      :identify               => 2,
      :status_update          => 3,
      :voice_state_update     => 4,
      :voice_server_ping      => 5,
      :resume                 => 6,
      :reconnect              => 7,
      :request_guild_members  => 8,
      :invalid_session        => 9,
      :hello                  => 10,
      :heartbeat_ack          => 11
    }
  end

  def start_link(opts) do
    # Fetch the Discord gateway URL
    url = gateway_url! opts

    # Connect to the Discord gateway
    :crypto.start()
    :ssl.start()
    :websocket_client.start_link(url, __MODULE__, opts)
  end

  def init(state) do
    {:once, state}
  end

  def send(text) do
    :websocket_client.cast(__MODULE__, {:text, text})
  end

  def onconnect(_req, state) do
    Logger.debug fn ->
      "Connected to the Discord gateway"
    end
    send_identify(state)
    {:ok, state}
  end

  def ondisconnect({:remote, :closed}, state) do
    IO.puts "Websocket ondisconnect"
    {:close, {:remote, :closed}, state}
  end

  defp send_identify(state) do
    data = %{
      "token" => state[:token],
      "properties" => %{
        "$os" => "erlang-vm",
        "$browser" => "firehose",
        "$device" => "firehose"
      },
      "compress" => state[:compress] || true,
      "large_threshold" => state[:large_threshold] || 250,

      "presence" => %{
        "status" => "dnd",
        "since" => DateTime.utc_now() |> DateTime.to_unix,
        "afk" => false
      }
    }
    payload = prepare_frame(opcodes()[:identify], data)
    :websocket_client.cast(self(), {:binary, payload})
  end

  def websocket_handle({:ping, _}, _conn, state) do
    {:ok, state}
  end

  def websocket_handle({:text, msg}, _conn, state) do
    IO.puts "Received message: #{msg}"
    {:ok, state}
  end

  def websocket_handle({:binary, data}, _conn, state) do
    #IO.puts "Received binary message: #{inspect decode_frame(data)}"
    data = decode_frame(data)
    if data[:op] == opcodes()[:dispatch] do
      state = Keyword.put(state, :last_seq, data[:s])
    end

    {k, _value} = Enum.find opcodes(), fn({_key, v}) -> v == data[:op] end
    frame_handle({k, data}, state)
  end

  def frame_handle({:hello, %{:d => %{:heartbeat_interval => heartbeat_interval, :_trace => trace}}}, state) do
    Logger.debug fn ->
      "Received HELLO from Discord gateway via #{trace}, heartbeat_interval=#{heartbeat_interval}"
    end
    Process.send_after(self(), :beat, heartbeat_interval)
    state = Keyword.put(state, :heartbeat_interval, heartbeat_interval)
    {:ok, state}
  end

  def frame_handle({:dispatch, %{:d => data, :t => :READY}}, state) do
    Logger.debug fn ->
      "#{data[:user][:username]}##{data[:user][:discriminator]} READY as #{data[:session_id]} via #{Enum.at(data[:_trace], 1)} v#{data[:v]}, #{length data[:guilds]} guilds, #{length data[:private_channels]} private_channels"
    end
    {:ok, state}
  end

  def frame_handle({:heartbeat_ack, _data}, state) do
    Logger.debug fn -> "Received heartbeat acknowledgement from gateway." end
    {:ok, state}
  end

  def frame_handle({_event, data}, state) do
    Firehose.Pump.sync_notify(data)
    {:ok, state}
  end

  def websocket_info(:beat, _conn, state) do
    Logger.debug fn -> "Sending heartbeat..." end
    payload = prepare_frame(opcodes()[:heartbeat], state[:last_seq])
    :websocket_client.cast(self(), {:binary, payload})
    Process.send_after(self(), :beat, state[:heartbeat_interval])
    {:ok, state}
  end

  def websocket_info(:start, _conn, state) do
    IO.puts "Websocket up"
    {:ok, state}
  end

  def websocket_terminate(reason, _conn, state) do
    IO.puts "Websocket closed in state #{state} with reason #{reason}"
    :ok
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end
end
