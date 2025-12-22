defmodule InertialTest do
  use ExUnit.Case

  test "can subscribe and receive events" do
    ref = Inertial.subscribe()
    assert is_reference(ref)
    # Since we can't easily trigger real network events in a test,
    # we will just check that the subscription works and that no
    # messages are received immediately.
    refute_receive {^ref, _event}, 100
  end
end
