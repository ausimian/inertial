defmodule Inertial do
  @moduledoc """
  Inertial monitors dynamic interface address assignment and removal.

  Inertial provides a simple API to subscribe to system events when

  - Network interfaces come up or go down.
  - IP addresses are added or removed from network interfaces.

  ## Example

      iex> ref = Inertial.subscribe()
      #Reference<0.1234567890.1234567890.123456>
      iex> receive do
      ...>   {^ref, event} -> IO.inspect(event)
      ...> end
      %{type: :new_addr, ifname: "eth0", addr: {192, 168, 1, 100}}
  """

  @type link_event() :: %{type: :link_up | :link_down, ifname: String.t()}
  @type addr_event() :: %{
          type: :new_addr | :del_addr,
          ifname: String.t(),
          addr: :inet.ip_address()
        }
  @type event_msg() :: {reference(), link_event() | addr_event()}

  @doc """
  Subscribes the calling process to Inertial events.

  Returns a reference that can be used to unsubscribe later, and identifies the event when
  it arrives in the caller's mailbox. Messages will be of type `t:event_msg/0`.

  ## Example

      iex> ref = Inertial.subscribe()
      #Reference<0.1234567890.1234567890.123456>
      iex> receive do
      ...>   {^ref, event} -> IO.inspect(event)
      ...> end
      %{type: :new_addr, ifname: "eth0", addr: {192, 168, 1, 100}}
  """
  @spec subscribe() :: reference()
  def subscribe() do
    pid = self()
    alias = Process.alias()
    :ok = :gen_event.add_handler(Inertial.EventManager, {Inertial.Handler, alias}, {pid, alias})
    alias
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
