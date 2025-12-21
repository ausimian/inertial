defmodule Inertial.EventManager do
  @moduledoc false

  @spec child_spec(Keyword.t()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {:gen_event, :start_link, [{:local, __MODULE__} | opts]},
      restart: :permanent,
      type: :worker,
      shutdown: 5000
    }
  end

  @spec notify(any()) :: :ok
  def notify(event) do
    :gen_event.notify(__MODULE__, event)
  end
end
