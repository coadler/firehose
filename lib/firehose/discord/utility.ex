defmodule Firehose.Discord.Utility do
  @moduledoc """
  A collection of mostly-private methods that `Firehose.Discord.Client` and
  `Firehose.Discord.Heart` use for various purposes.
  """

  require Logger

  alias Firehose.Error

  def gateway_url(opts) do
    version = opts[:version] || 6
    case HTTPoison.get "https://discordapp.com/api/gateway" do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        url = Poison.decode!(body)["url"] <> "?v=#{version}&encoding=etf"
        Logger.debug fn ->
          "Fetched Discord gateway URL: #{url}"
        end
        {:ok, String.to_charlist(url)}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error fn ->
          "Failed to discover Discord gateway URL: #{reason}"
        end
        {:error, reason}

      _ ->
        Logger.error fn ->
          "Failed to discover Discord gateway URL: unknown reason"
        end
        {:error, :unknown}
    end
  end

  def gateway_url!(opts) do
    case gateway_url(opts) do
      {:ok, url} -> url
      {:error, reason} -> raise Error, reason: reason
    end
  end

  @doc "Build a binary payload for discord communication"
  @spec prepare_frame(number, map, number, String.t) :: binary
  def prepare_frame(op, data, seq_num \\ nil, event_name \\ nil) do
    load = %{"op" => op, "d" => data}
    load
      |> _update_payload(seq_num, "s", seq_num)
      |> _update_payload(event_name, "t", seq_num)
      |> :erlang.term_to_binary
  end

  @doc "Decode an incoming ETF-encoded binary payload from the Discord
  gateway."
  @spec decode_frame(binary) :: map
  def decode_frame(data) do
    :erlang.binary_to_term(data)
  end

  # Makes it easy to just update and pipe a payload
  defp _update_payload(load, var, key, value) do
    if var do
      Map.put(load, key, value)
    else
      load
    end
  end
end
