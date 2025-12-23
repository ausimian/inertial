# Inertial

Inertial provides system event notifications for network interface
changes such as link status and IP address assignments.

## Example

```elixir
  iex> ref = Inertial.subscribe()
  #Reference<0.1234567890.1234567890.123456>
  iex> receive do
  ...>   {^ref, event} -> IO.inspect(event)
  ...> end
  %{type: :new_addr, ifname: "eth0", addr: {192, 168, 1, 100}}
```

## Installation

The package can be installed by adding `inertial` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [
    {:inertial, "~> 0.1.0"}
  ]
end
```