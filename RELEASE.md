### Changed

- Raised the minimum Elixir requirement to 1.18.

### Fixed

- Bind the Linux netlink socket with a kernel-assigned port-id so the
  monitor no longer fails to start with `:eaddrinuse` when another
  netlink socket already exists in the same OS process (#6).
