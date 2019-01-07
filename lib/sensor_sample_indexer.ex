defmodule SensorSampleIndexer do
  use Application

  @moduledoc """
  Documentation for SensorSampleIndexer.
  """

  def start(_type, _args) do
    {rabbitmq_timeout, _} = Integer.parse(System.get_env("RABBITMQ_TIMEOUT") || "1000")
    rabbitmq_url = System.get_env("RABBITMQ_URL") || "amqp://localhost"
    rabbitmq_queue = System.get_env("RABBITMQ_QUEUE") || "sensor_sample_indexer"
    children = [
      {SensorSampleIndexer.DbConnection, []},
      {RabbitMQ.Connection, [
        timeout: rabbitmq_timeout,
        url: rabbitmq_url,
        name: :rabbitmq_connection
      ]},
      {RabbitMQ.Consumer, [
        connection: :rabbitmq_connection,
        queue: rabbitmq_queue,
        prefetch: 10,
        name: :rabbitmq_consumer
      ]},
      {RabbitMQ.Decoder, [
        name: :rabbitmq_decoder,
        subscribe_to: [:rabbitmq_consumer]
      ]},
      {RabbitMQ.Deserializer, [
        name: :rabbitmq_deserializer,
        subscribe_to: [:rabbitmq_decoder],
      ]},
      {SensorSampleIndexer.Indexer, [
        name: :indexer,
        subscribe_to: [:rabbitmq_deserializer],
      ]},
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

end
