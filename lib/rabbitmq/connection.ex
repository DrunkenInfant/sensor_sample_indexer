defmodule RabbitMQ.Connection do
  use Connection
  require Logger

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def start_link(opts) do
    Connection.start_link(__MODULE__, opts, opts)
  end

  def init(opts) do
    url = Keyword.get(opts, :url, "amqp://localhost")
    timeout = Keyword.get(opts, :timeout, 1000)
    {:connect, url, %{url: url, connected: false, conn: nil, backoff: timeout, timeout: timeout}}
  end

  def connect(_reason, %{timeout: timeout, backoff: backoff} = state) do
    case AMQP.Connection.open(state.url) do
      {:ok, conn} ->
        Logger.info("#{__MODULE__}: Connected to #{state.url}")
        Process.monitor(conn.pid)
        {:ok, %{state | connected: true, conn: conn, timeout: backoff}}

      _ ->
        Logger.error("#{__MODULE__}: Failed connecting to #{state.url}, reconnecting in #{timeout} ms")
        {:backoff, timeout, %{state | timeout: timeout * 2}}
    end
  end

  def disconnect(_reason, %{conn: conn} = state) do
    Logger.info("#{__MODULE__}: Disconnecting from #{state.url}")
    AMQP.Connection.close(conn)
    {:stop, :disconnect, %{state| conn: nil, connected: false}}
  end

  def channel(pid), do: GenServer.call(pid, {:channel})

  def handle_info({:DOWN, _, :process, _pid, _reason}, state) do
    Logger.error("#{__MODULE__}: Disconnected from #{state.url}")
    {:connect, :disconnected, %{state | connected: false, conn: nil}}
  end

  def handle_call({:channel}, _from, %{conn: conn, connected: true} = state) do
    reply =
      case AMQP.Channel.open(conn) do
        {:ok, chan} -> {:ok, chan}
        error -> error
      end

    {:reply, reply, state}
  end

  def handle_call({:channel}, _from, state) do
    {:reply, {:error, :not_connected}, state}
  end

  def handle_call(:health, _from, %{connected: true} = state), do: {:reply, :ok, state}

  def handle_call(:health, _from, state), do: {:reply, {:error, "Not connected"}, state}
end
