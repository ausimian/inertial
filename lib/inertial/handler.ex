defmodule Inertial.Handler do
  @moduledoc false
  @behaviour :gen_event

  use TypedStruct

  typedrecord :state do
    field(:alias, reference())
    field(:mon, reference())
  end

  @impl true
  def init({pid, alias}) when is_pid(pid) and is_reference(alias) do
    # We are passed both the pid and an alias for the subscribing process. The
    # pid is used to monitor the process and the alias is used to send messages.
    # The alias is also used as a unique identifier for the subscription this
    # handler represents.
    mon = Process.monitor(pid)
    {:ok, state(alias: alias, mon: mon)}
  end

  @impl true
  def handle_event(event, state(alias: alias) = state) do
    send(alias, {alias, event})
    {:ok, state}
  end

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
