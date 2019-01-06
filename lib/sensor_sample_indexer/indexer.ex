defmodule SensorSampleIndexer.Indexer do
  use GenStage
  require Logger

  def start_link(opts), do: GenStage.start_link(__MODULE__, opts, opts)

  def init(opts) do
    {:consumer, %{}, Keyword.take(opts, [:subscribe_to])}
  end

  def handle_events(events, _from, state) do
    points = events
             |> Enum.map(&get_event_data/1)
             |> Enum.map(&SensorSampleIndexer.SampleSeries.from_map/1)
    case SensorSampleIndexer.DbConnection.write(%{ points: points }) do
      :ok -> Enum.each(events, fn e -> RabbitMQ.Consumer.ack(e) end)
      err ->
        Logger.error(inspect err)
        Enum.each(events, fn e -> RabbitMQ.Consumer.nack(e) end)
    end
    {:noreply, [], state}
  end

  def get_event_data({_, data, _}), do: data
end
