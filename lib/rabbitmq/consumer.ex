defmodule RabbitMQ.Consumer do
  use GenStage
  use AMQP
  require Logger

  def start_link(opts), do: GenStage.start_link(__MODULE__, opts, opts)

  def init(opts) do
    connection = Keyword.fetch!(opts, :connection)
    queue = Keyword.fetch!(opts, :queue)
    prefetch = Keyword.get(opts, :prefetch, 10)
    send(self(), {:connect, :start})
    {:producer, %{chan: nil, queue: queue, prefetch: prefetch, connection: connection}}
  end

  def connect(_reason, %{connection: conn, prefetch: prefetch, queue: queue} = state) do
    with {:ok, chan} <- RabbitMQ.Connection.channel(conn),
         Process.monitor(chan.pid),
         :ok <- Basic.qos(chan, prefetch_count: prefetch),
         {:ok, _consumer_tag} <- Basic.consume(chan, queue) do
      {:ok, %{state | chan: chan}}
    else
      {:error, :not_connected} -> {:backoff, 1000, state} # TODO listen to connection
      {:error, error} ->
        Logger.error("#{__MODULE__} Failed to open channel #{inspect error}")
        {:backoff, 1000, state}
    end
  end

  def disconnect(_reason, %{chan: chan} = state) do
    Logger.info("#{__MODULE__}: Closing channel")
    AMQP.Channel.close(chan)
    {:stop, :normal, %{state | chan: nil}}
  end

  def ack({_, _, %{consumer: consumer}} = event) do
    GenServer.cast(consumer, {:ack, event})
  end
  def nack({_, _, %{consumer: consumer}} = event) do
    GenServer.cast(consumer, {:nack, event})
  end

  def handle_cast({:ack, {_, _, %{delivery_tag: tag}}}, %{chan: chan} = state) do
    Basic.ack(chan, tag)
    {:noreply, [], state}
  end

  def handle_cast({:nack, {_, _, %{delivery_tag: tag}}}, %{chan: chan} = state) do
    Basic.reject(chan, tag, requeue: false)
    {:noreply, [], state}
  end

  def handle_call(:health, _from, %{chan: chan} = state) when not is_nil(chan), do: {:reply, :ok, [], state}

  def handle_call(:health, _from, state), do: {:reply, {:error, "No open channel"}, [], state}

  def handle_info({:connect, reason}, state) do
    case connect(reason, state) do
      {:ok, new_state} -> {:noreply, [], new_state}
      {:backoff, timeout, new_state} ->
        Process.send_after(self(), {:connect, :reconnect}, timeout)
        {:noreply, [], new_state}
    end
  end

  def handle_info(:consume, state) do
    {:noreply, [], state}
  end

  # Confirmation sent by the broker after registering this process as a consumer
  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, state) do
    {:noreply, [], state}
  end

  # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
  def handle_info({:basic_cancel, %{consumer_tag: _consumer_tag}}, state) do
    {:stop, :remote_cancel_consume, state}
  end

  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  def handle_info({:basic_cancel_ok, %{consumer_tag: _consumer_tag}}, state) do
    {:stop, :normal, state}
  end

  def handle_info({:basic_deliver, payload, props}, %{chan: chan} = state) do
    {:noreply, [{chan, payload, Map.put(props, :consumer, self())}], state}
  end

  def handle_info({:DOWN, _, :process, _pid, _reason}, state) do
    Logger.error("#{__MODULE__}: Channel stopped unexpectedly.")
    {:stop, :normal, state}
  end

  def handle_demand(demand, state) when demand > 0 do
    {:noreply, [], state}
  end
end
