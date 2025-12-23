# Inertial

Inertial provides system event notifications for network interface
changes such as link status and IP address assignments, on Linux and OSX.

It uses the OS's native event notification mechanisms to provide real-time
updates with minimal overhead. A connection is made to a 'system' socket
using the Erlang [:socket](https://www.erlang.org/doc/apps/kernel/socket.html) module, 
and a NIF is used to set the appropriate event filters and decode the received packets.

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
    {:inertial, "~> 2.0.0"}
  ]
end
```