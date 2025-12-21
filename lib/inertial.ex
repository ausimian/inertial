defmodule Inertial do
  @moduledoc """
  Inertial monitors dynamic interface address assignment and removal.

  The API exposes a single function, `event_mgr/0`, that returns the
  event manager process that relays events. Clients should use the
  [gen_event](https://erlang.org/doc/apps/stdlib/gen_event.html) API
  to add and remove handlers from this event manager.
  """

  @type event_type() :: :new_addr | :del_addr
  @type event() :: %{type: event_type(), ifname: String.t(), addr: :inet.ip_address()}

  @doc """
  Returns the inertial event manager process.

  Clients should use [:gen_event.add_handler/3](https://erlang.org/doc/apps/stdlib/gen_event.html#add_handler/3) or
  [:gen_event.add_sup_handler/3](https://erlang.org/doc/apps/stdlib/gen_event.html#add_sup_handler/3)
  to add their own handlers to this event manager.

  The events published will of type `t:event/0`.
  """
  @spec event_mgr() :: pid() | atom()
  def event_mgr, do: Inertial.EventManager
end
