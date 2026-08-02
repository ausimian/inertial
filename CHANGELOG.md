# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!-- %% CHANGELOG_ENTRIES %% -->

## 2.2.0 - 2026-08-02

### Added

- `Inertial.subscribe/1` accepts an `:ifname` option to scope a subscription to a
  single interface or a list of interfaces. Subscriptions remain unscoped by
  default, so existing callers of `Inertial.subscribe/0` continue to receive
  events for every interface.

## 2.1.0 - 2026-06-19

### Changed

- Raised the minimum Elixir requirement to 1.18.

### Fixed

- Bind the Linux netlink socket with a kernel-assigned port-id so the
  monitor no longer fails to start with `:eaddrinuse` when another
  netlink socket already exists in the same OS process (#6).

## 2.0.0 - 2025-12-23

Initial revision
