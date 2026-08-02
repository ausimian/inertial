defmodule Inertial do
  @moduledoc """
  Inertial provides system event notifications for network interface
  changes such as link status and IP address assignments, on Linux and OSX.

  It uses the OS's native event notification mechanisms to provide real-time
  updates with minimal overhead. A connection is made to a 'system' socket
  using the Erlang [`:socket`](`:socket`) module, and a NIF is used to set the appropriate
  event filters and decode the received packets.

  ## Example

      iex> ref = Inertial.subscribe()
      #Reference<0.1234567890.1234567890.123456>
      iex> receive do
      ...>   {^ref, event} -> IO.inspect(event)
      ...> end
      %{type: :new_addr, ifname: "eth0", addr: {192, 168, 1, 100}}

  Subscriptions cover every interface by default, but can be scoped to one or more
  interfaces with the `:ifname` option:

      iex> ref = Inertial.subscribe(ifname: "eth0")
      #Reference<0.1234567890.1234567890.123456>
  """

  @type link_event() :: %{type: :link_up | :link_down, ifname: String.t()}
  @type addr_event() :: %{
          type: :new_addr | :del_addr,
          ifname: String.t(),
          addr: :inet.ip_address()
        }
  @type event_msg() :: {reference(), link_event() | addr_event()}
  @type ifname_filter() :: :any | String.t() | [String.t()]
  @type subscribe_option() :: {:ifname, ifname_filter()}

  @doc """
  Subscribes the calling process to Inertial events.

  Returns a reference that can be used to unsubscribe later, and identifies the event when
  it arrives in the caller's mailbox. Messages will be of type `t:event_msg/0`.

  ## Options

    * `:ifname` - restricts the subscription to one or more interfaces. Accepts `:any`
      (the default) to receive events for every interface, a single interface name, or a
      list of interface names. An empty list matches nothing.

  ## Examples

      iex> ref = Inertial.subscribe()
      #Reference<0.1234567890.1234567890.123456>
      iex> receive do
      ...>   {^ref, event} -> IO.inspect(event)
      ...> end
      %{type: :new_addr, ifname: "eth0", addr: {192, 168, 1, 100}}

  Scoping a subscription to a single interface:

      iex> ref = Inertial.subscribe(ifname: "eth0")
      #Reference<0.1234567890.1234567890.123456>

  Or to a set of interfaces:

      iex> ref = Inertial.subscribe(ifname: ["eth0", "wlan0"])
      #Reference<0.1234567890.1234567890.123456>
  """
  @spec subscribe([subscribe_option()]) :: reference()
  def subscribe(opts \\ []) when is_list(opts) do
    filter = opts |> Keyword.get(:ifname, :any) |> normalize_filter()
    pid = self()
    alias = Process.alias()

    :ok =
      :gen_event.add_handler(
        Inertial.EventManager,
        {Inertial.Handler, alias},
        {pid, alias, filter}
      )

    alias
  end

  defp normalize_filter(:any), do: :any
  defp normalize_filter(ifname) when is_binary(ifname), do: MapSet.new([ifname])

  defp normalize_filter(ifnames) when is_list(ifnames) do
    if Enum.all?(ifnames, &is_binary/1) do
      MapSet.new(ifnames)
    else
      raise ArgumentError,
            "expected :ifname to be a list of interface names, got: #{inspect(ifnames)}"
    end
  end

  defp normalize_filter(other) do
    raise ArgumentError,
          "expected :ifname to be :any, an interface name, or a list of interface names, " <>
            "got: #{inspect(other)}"
  end

  @doc """
  Unsubscribes the calling process from Inertial events.

  Takes the reference returned by `subscribe/0`, and unsubscribes. Should be called by the same
  process that called `subscribe/0`.

  Guarantees that no further messages with the given reference will be received after this call.

  ## Example

      iex> ref = Inertial.subscribe()
      #Reference<0.1234567890.1234567890.123456>
      iex> Inertial.unsubscribe(ref)
      :ok
  """
  @spec unsubscribe(reference()) :: :ok
  def unsubscribe(ref) when is_reference(ref) do
    Process.unalias(ref)
    :gen_event.delete_handler(Inertial.EventManager, {Inertial.Handler, ref}, [])
    drain_late_events(ref)
  end

  defp drain_late_events(ref) do
    receive do
      {^ref, _event} -> drain_late_events(ref)
    after
      0 -> :ok
    end
  end
end
