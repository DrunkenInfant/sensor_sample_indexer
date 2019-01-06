defmodule RabbitMQ.Deserializer do
  use GenStage
  use AMQP
  require Logger

  def start_link(opts), do: GenStage.start_link(__MODULE__, opts, opts)

  def init(opts) do
    {:producer_consumer, %{}, Keyword.take(opts, [:subscribe_to, :dispatcher])}
  end

  def handle_events(events, _from, state) do
    {:noreply, events |> Enum.flat_map(&deserialize_event/1), state}
  end

  def deserialize_event({_, _, %{content_type: content_type}} = event) when content_type != :undefined do
    deserialize(event, parse_content_type(content_type))
  end

  def deserialize_event({_, _, %{headers: headers}} = event) do
    {_, _, content_type} =
      Enum.find(headers, {"Content-Type", :longstr, "text/plain; charset=utf-8"}, fn {key, _, _} ->
        key == "Content-Type"
      end)

    deserialize(event, parse_content_type(content_type))
  end

  def deserialize_event(event) do
    deserialize(event, {"text/plain", "utf-8"})
  end

  defp deserialize({chan, json, props} = event, {"application/json", _}) do
    case Poison.decode(json) do
      {:ok, obj} ->
        [{chan, obj, props}]
      err ->
        Logger.error("Invalid json: #{inspect(err)}")
        RabbitMQ.Consumer.nack(event)
        []
    end
  end

  defp deserialize(event, {"text/plain", _}), do: [event]

  defp deserialize(event, {content_type, _}) do
    Logger.error("Unknown content type: #{content_type}")
    RabbitMQ.Consumer.nack(event)
    []
  end

  defp parse_content_type(content_type) do
    case content_type |> String.split(";") |> Enum.map(&String.trim/1) do
      [content_type] -> {content_type, "utf-8"}
      [content_type, charset] -> {content_type, charset}
    end
  end
end
