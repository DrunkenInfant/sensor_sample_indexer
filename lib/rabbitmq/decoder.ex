defmodule RabbitMQ.Decoder do
  use GenStage
  use AMQP
  require Logger

  def start_link(opts), do: GenStage.start_link(__MODULE__, opts, opts)

  def init(opts) do
    IO.inspect(opts)
    {:producer_consumer, %{}, Keyword.take(opts, [:subscribe_to])}
  end

  def handle_events(events, _from, state) do
    {:noreply, Enum.flat_map(events, &decode_event/1), state}
  end

  def decode_event({_, _, %{content_encoding: content_encoding}} = event) when content_encoding != :undefined do
    decode(event, content_encoding)
  end

  def decode_event({_, _, %{headers: :undefined}} = event) do
    decode(event, "none")
  end

  def decode_event({_, _, %{headers: headers}} = event) do
    {_, _, content_encoding} =
      Enum.find(headers, {"Content-Encoding", :longstr, "none"}, fn {key, _, _} -> key == "Content-Encoding" end)

    decode(event, content_encoding)
  end

  defp decode({chan, data, props} = event, "gzip") do
    try do
      :zlib.gunzip(data)
    rescue
      e ->
        Logger.error("Failed to gunzip data: #{inspect(e)}")
        RabbitMQ.Consumer.nack(event)
        []
    else
      gunzipped -> [{chan, gunzipped, props}]
    end
  end

  defp decode(event, "none"), do: [event]

  defp decode(event, content_encoding) do
    Logger.error("Unknown content encoding: #{content_encoding}")
    RabbitMQ.Consumer.nack(event)
    []
  end
end
