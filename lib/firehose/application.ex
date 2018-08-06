defmodule Firehose.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    # Prepare the Pump and the Gauge
    children = [
      Firehose.Pump
      # Firehose.Gauge
    ]

    # Prepare nozzles
    nozzle_count = Application.fetch_env!(:firehose, :nozzle_count)
    nozzle_opts = Application.fetch_env!(:firehose, :nozzle_amqp_options)
    nozzles = Enum.map 1..nozzle_count, fn n ->
      Supervisor.child_spec({Firehose.Nozzle.AMQP, nozzle_opts}, id: String.to_atom("nozzle_amqp_#{n}"))
    end

    # Validate shard configuration
    shard_count = Application.fetch_env!(:firehose, :discord_shards_count)
    shard_ids = Application.fetch_env!(:firehose, :discord_shards)
    shard_ids = cond do
      Enumerable.impl_for(shard_ids) == nil -> shard_ids..shard_ids
      true -> shard_ids
    end
    if length(Enum.to_list(shard_ids)) > shard_count do
      raise ArgumentError, message: "length of shard IDs list is greater than shard count"
    end

    # Prepare starting shards list
    discord_token = Application.fetch_env!(:firehose, :discord_token)
    websocket_encoding = case Application.get_env(:firehose, :discord_encoding) do
      {:ok, value} when value == :etf or value == :json -> value
      _ -> :etf
    end
    websocket_compression = case Application.get_env(:firehose, :discord_compress) do
      {:ok, value} when is_boolean(value) -> value
      _ -> false
    end
    shards = Enum.map shard_ids, fn shard_id ->
      {Firehose.Discord.Client, [
        token: discord_token,
        encoding: websocket_encoding,
        compression: websocket_compression,

        shard_count: shard_count,
        shard_id: shard_id
      ]}
    end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    children = children ++ nozzles ++ shards
    opts = [strategy: :one_for_one, name: Firehose.Supervisor]
    IEx.Helpers.i children
    Supervisor.start_link(children, opts)
  end
end
