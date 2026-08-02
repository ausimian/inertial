defmodule InertialTest do
  use ExUnit.Case

  @link_up %{type: :link_up, ifname: "eth0"}
  @other_link_up %{type: :link_up, ifname: "wlan0"}
  @new_addr %{type: :new_addr, ifname: "eth0", addr: {192, 168, 1, 100}}

  # Handlers monitor the subscribing process, so each test's subscriptions are
  # removed automatically when the test process exits.

  test "can subscribe and receive events" do
    ref = Inertial.subscribe()
    assert is_reference(ref)
    # Since we can't easily trigger real network events in a test,
    # we will just check that the subscription works and that no
    # messages are received immediately.
    refute_receive {^ref, _event}, 100
  end

  describe "subscribe/0 (unscoped)" do
    test "receives events for every interface" do
      ref = Inertial.subscribe()

      notify(@link_up)
      notify(@other_link_up)
      notify(@new_addr)

      assert_received {^ref, @link_up}
      assert_received {^ref, @other_link_up}
      assert_received {^ref, @new_addr}
    end

    test "is equivalent to subscribing with ifname: :any" do
      any = Inertial.subscribe(ifname: :any)
      default = Inertial.subscribe()

      notify(@other_link_up)

      assert_received {^any, @other_link_up}
      assert_received {^default, @other_link_up}
    end

    test "receives events whose interface could not be determined" do
      ref = Inertial.subscribe()
      event = %{type: :new_addr, ifname: :unknown, addr: :unknown}

      notify(event)

      assert_received {^ref, ^event}
    end
  end

  describe "subscribe/1 scoped by ifname" do
    test "delivers only events for the named interface" do
      scoped = Inertial.subscribe(ifname: "eth0")
      unscoped = Inertial.subscribe()

      notify(@other_link_up)

      # The unscoped subscription proves the event was dispatched at all, so the
      # refutation below is about filtering rather than about timing.
      assert_received {^unscoped, @other_link_up}
      refute_received {^scoped, _event}

      notify(@link_up)

      assert_received {^scoped, @link_up}
      assert_received {^unscoped, @link_up}
    end

    test "filters address events as well as link events" do
      scoped = Inertial.subscribe(ifname: "wlan0")

      notify(@new_addr)
      notify(%{@new_addr | ifname: "wlan0"})

      assert_received {^scoped, %{type: :new_addr, ifname: "wlan0"}}
      refute_received {^scoped, %{ifname: "eth0"}}
    end

    test "accepts a list of interfaces" do
      scoped = Inertial.subscribe(ifname: ["eth0", "wlan0"])

      notify(@link_up)
      notify(@other_link_up)
      notify(%{type: :link_down, ifname: "lo0"})

      assert_received {^scoped, @link_up}
      assert_received {^scoped, @other_link_up}
      refute_received {^scoped, _event}
    end

    test "an empty list matches nothing" do
      scoped = Inertial.subscribe(ifname: [])
      unscoped = Inertial.subscribe()

      notify(@link_up)

      assert_received {^unscoped, @link_up}
      refute_received {^scoped, _event}
    end

    test "never receives events whose interface could not be determined" do
      scoped = Inertial.subscribe(ifname: "eth0")
      unscoped = Inertial.subscribe()
      event = %{type: :new_addr, ifname: :unknown, addr: :unknown}

      notify(event)

      assert_received {^unscoped, ^event}
      refute_received {^scoped, _event}
    end

    test "scoped subscriptions are independent of each other" do
      eth = Inertial.subscribe(ifname: "eth0")
      wlan = Inertial.subscribe(ifname: "wlan0")

      notify(@link_up)

      assert_received {^eth, @link_up}
      refute_received {^wlan, _event}
    end

    test "unsubscribing a scoped subscription leaves the others intact" do
      eth = Inertial.subscribe(ifname: "eth0")
      unscoped = Inertial.subscribe()

      :ok = Inertial.unsubscribe(eth)

      notify(@link_up)

      assert_received {^unscoped, @link_up}
      refute_received {^eth, _event}
    end

    test "rejects a filter that is not an interface name" do
      assert_raise ArgumentError, fn -> Inertial.subscribe(ifname: :eth0) end
      assert_raise ArgumentError, fn -> Inertial.subscribe(ifname: ["eth0", :wlan0]) end
    end
  end

  # `:gen_event.notify/2` is asynchronous. Following it with a synchronous call
  # into the same manager guarantees the notification has been dispatched to
  # every handler before we assert on (or refute) the resulting messages.
  defp notify(event) do
    :ok = Inertial.EventManager.notify(event)
    _ = :gen_event.which_handlers(Inertial.EventManager)
    :ok
  end
end
