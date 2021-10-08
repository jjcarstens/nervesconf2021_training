defmodule Setup do
  use GenServer

  require Logger

  import Record, only: [defrecord: 2]

  @inet_dns "kernel/src/inet_dns.hrl"

  defrecord :dns_rr, Record.extract(:dns_rr, from_lib: @inet_dns)

  @query {:dns_query, '_epmd._tcp.local', :ptr, :in}

  @found "tmp/found.txt"
  @completed "tmp/completed.txt"
  @rebooted "tmp/rebooted.txt"
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    {:ok, host} = :inet.gethostname()
    Node.start(:"setup@#{host}.local")
    Node.set_cookie(:nerves_livebook_cookie)
    File.touch!(@found)
    File.touch!(@completed)
    File.touch!(@rebooted)

    found =
      File.read!(@found)
      |> String.split("\n", trim: true)
      |> MapSet.new()

    completed =
      File.read!(@completed)
      |> String.split("\n", trim: true)
      |> MapSet.new()

    rebooted =
      File.read!(@rebooted)
      |> String.split("\n", trim: true)
      |> MapSet.new()

    send(self(), :find)
    {:ok, %{found: found, completed: completed, rebooted: rebooted}}
  end

  @impl GenServer
  def handle_continue(:notify, state) do
    # Reboot the ones that have been found to ensure
    # they start back up and connect to network
    rebooted =
      MapSet.difference(state.found, state.rebooted)
      |> Enum.reduce(state.rebooted, &do_reboot/2)

    # Complete those that have successfully rebooted
    completed =
      MapSet.difference(state.rebooted, state.completed)
      |> Enum.reduce(state.completed, &do_complete/2)

    {:noreply, %{state | completed: completed, rebooted: rebooted}}
  end

  @impl GenServer
  def handle_info(:find, state) do
    # For comparison
    before = state.found

    MdnsLite.Responder.multicast_all(@query)
    :timer.sleep(2000)
    %{additional: records} = MdnsLite.Responder.query_all_caches(@query)

    found =
      Enum.reduce(records, state.found, fn
        dns_rr(type: :srv, class: :in, data: {_, _, _, hostname}), acc ->
          MapSet.put(acc, to_string(hostname))

        _, acc ->
          acc
      end)

    # Write newly found devices
    for h <- MapSet.difference(found, before), do: File.write!(@found, h <> "\n", [:append])

    Process.send_after(self(), :find, 2000)

    {:noreply, %{state | found: found}, {:continue, :notify}}
  end

  defp do_complete(target, acc) do
    n = :"livebook@#{target}"

    with :pong <- Node.ping(n),
         _ = Node.spawn(n, ScrollHat.Display, :start_link, []),
         :ok <- GenServer.call({ScrollHat.Display, n}, {:draw, "OK"}),
         :ok <- File.write(@completed, target <> "\n", [:append]) do
      MapSet.put(acc, target)
    else
      err ->
        Logger.error("#{target} failed to notify - #{inspect(err)}")
        acc
    end
  catch
    _, _ ->
      Logger.error("#{target} failure during notify")
      acc
  end

  defp do_reboot(target, acc) do
    n = :"livebook@#{target}"

    with :pong <- Node.ping(n),
         _ = Node.spawn(n, ScrollHat.Display, :start_link, []),
         :ok <- GenServer.call({ScrollHat.Display, n}, {:draw, "REBOOT"}),
         _ = Node.spawn(n, Nerves.Runtime, :reboot, []),
         :ok <- File.write(@rebooted, target <> "\n", [:append]) do
      MapSet.put(acc, target)
    else
      err ->
        Logger.error("#{target} failed to notify - #{inspect(err)}")
        acc
    end
  catch
    _, _ ->
      Logger.error("#{target} failure during notify")
      acc
  end
end
