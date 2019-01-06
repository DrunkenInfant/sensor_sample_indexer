defmodule SensorSampleIndexer do
  use Application

  @moduledoc """
  Documentation for SensorSampleIndexer.
  """

  def start(_type, _args) do
    rabbitmq_timeout = 60
    rabbitmq_url = "amqp://localhost:5672"
    rabbitmq_queue = "debug_meas"
    children = [
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
