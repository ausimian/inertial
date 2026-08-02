### Added

- `Inertial.subscribe/1` accepts an `:ifname` option to scope a subscription to a
  single interface or a list of interfaces. Subscriptions remain unscoped by
  default, so existing callers of `Inertial.subscribe/0` continue to receive
  events for every interface.
