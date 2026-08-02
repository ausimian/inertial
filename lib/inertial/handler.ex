defmodule Inertial.Handler do
  @moduledoc false
  @behaviour :gen_event

  use TypedStruct

  typedrecord :state do
    field :alias, reference()
    field :mon, reference()
    field :filter, :any | MapSet.t(String.t())
  end

  @impl true
  def init({pid, alias, filter}) when is_pid(pid) and is_reference(alias) do
    # We are passed the pid of the subscribing process, an alias for it, and the
    # interface filter for the subscription. The pid is used to monitor the
    # process and the alias is used to send messages. The alias is also used as a
    # unique identifier for the subscription this handler represents.
    mon = Process.monitor(pid)
    {:ok, state(alias: alias, mon: mon, filter: filter)}
  end

  @impl true
  def handle_event(event, state(alias: alias, filter: filter) = state) do
    if selected?(event, filter) do
      send(alias, {alias, event})
    end

    {:ok, state}
  end

  # An event whose interface cannot be determined (the decoder reports `:unknown`)
  # is only delivered to unscoped subscriptions.
  defp selected?(_event, :any), do: true

  defp selected?(%{ifname: ifname}, filter) when is_binary(ifname),
    do: MapSet.member?(filter, ifname)

  defp selected?(_event, _filter), do: false

  @impl true
  def handle_call(_request, state) do
    {:ok, :ok, state}
  end

  @impl true
  def terminate(_, state(mon: mon)) do
    Process.demonitor(mon, [:flush])
    :ok
  end

  @impl true
  def handle_info({:DOWN, mon, :process, _pid, _reason}, state(mon: mon)) do
    :remove_handler
  end

  def handle_info(_, state) do
    {:ok, state}
  end
end
