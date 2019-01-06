defmodule SensorSampleIndexer.SampleSeries do
  def from_map(%{"sensor_type" => sensor_type, "sensor_id" => sensor_id, "value" => value, "timestamp" => timestamp}) do
    %{
      measurement: sensor_type,
      tags: %{sensor_id: sensor_id},
      fields: %{value: value},
      timestamp: timestamp * 1000 * 1000
    }
  end
end
