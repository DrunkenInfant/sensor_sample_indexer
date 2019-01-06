defmodule SensorSampleIndexer.Indexer do
  use GenStage
  require Logger

  def start_link(opts), do: GenStage.start_link(__MODULE__, opts, opts)

  def init(opts) do
    {:consumer, %{}, Keyword.take(opts, [:subscribe_to])}
  end

  def handle_events(events, _from, state) do
    Enum.each(events, fn (e) -> Logger.info(inspect(e)) end)
    Enum.each(events, fn e -> RabbitMQ.Consumer.ack(e) end)
    {:noreply, [], state}
  end
end
