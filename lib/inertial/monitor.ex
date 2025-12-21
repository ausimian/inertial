defmodule Inertial.Monitor do
  @moduledoc false
  use GenServer
  use TypedStruct

  require Logger

  # The monitor uses the OS's built-in support for system event notification,
  # (either sysproto or netlink) for ip-address related events.
  #
  # A NIF is used for:
  #
  # - Setting the event filter on the socket which is called via an ioctl that
  #   is not available on the `:socket` module.
  # - Decoding the packets, which are natively C structs.
  #

  @on_load :load_nif
  if Version.match?(System.version(), ">= 1.16.0") do
    @nifs set_event_filter: 2, decode_event: 1
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  typedstruct enforce: true do
    field(:socket, :socket.socket())
    field(:recv_ref, reference() | nil, default: nil)
  end

  @impl true
  def init(_args) do
    with {:ok, state} <- subscribe() do
      {:ok, state, {:continue, :read}}
    end
  end

  @impl true
  def handle_continue(:read, %__MODULE__{recv_ref: nil} = state) do
    case :socket.recvmsg(state.socket, [], :nowait) do
      {:ok, %{iov: [data]}} ->
        case decode_event(data) do
          {:ok, events} ->
            events
            |> Enum.reverse()
            |> Enum.each(&Inertial.EventManager.notify/1)

            :ok

          _ ->
            :ok
        end

        {:noreply, state, {:continue, :read}}

      {:select, {:select_info, :recvmsg, ref}} ->
        {:noreply, %__MODULE__{state | recv_ref: ref}}

      {:error, reason} ->
        {:stop, reason, state}
    end
  end

  @impl true
  def handle_info({:"$socket", s, :select, ref}, %__MODULE__{socket: s, recv_ref: ref} = state) do
    {:noreply, %__MODULE__{state | recv_ref: nil}, {:continue, :read}}
  end

  defp subscribe do
    case :os.type() do
      {:unix, :darwin} ->
        # pf_system(32), sock_raw(3), sysproto_event(1)
        {:ok, s} = :socket.open(32, 3, 1)
        {:ok, fd} = :socket.getopt(s, {:otp, :fd})
        # vendor_apple(1), network_class(1)
        :ok = set_event_filter(fd, %{vendor: 1, class: 1})
        {:ok, %__MODULE__{socket: s}}

      {:unix, :linux} ->
        # pf_netlink(16), sock_raw(3), netlink_route(0)
        {:ok, s} = :socket.open(16, 3, 0)
        {:ok, fd} = :socket.getopt(s, {:otp, :fd})
        # RTMGRP_IPV4_IFADDR(0x10)
        :ok = set_event_filter(fd, %{groups: 0x10})
        {:ok, %__MODULE__{socket: s}}
    end
  end

  defp load_nif do
    path = Path.join(:code.priv_dir(:inertial), "inertial_nif")
    :erlang.load_nif(to_charlist(path), 0)
  end

  # NIF stand-ins
  defp set_event_filter(_sock, _filter), do: :erlang.nif_error(:not_implemented)
  defp decode_event(_data), do: :erlang.nif_error(:not_implemented)
end
