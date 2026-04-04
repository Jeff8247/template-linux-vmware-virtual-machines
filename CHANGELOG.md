# Changelog

All notable changes to this template will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.16] - 2026-04-04

### Added
- Linux AD domain join support: set `windows_domain` and `windows_domain_password` to activate a `realmd`/`sssd` join script during guest customization. Handled by module v1.0.16.
- `windows_domain`, `windows_domain_user`, `windows_domain_password`, `windows_domain_ou`, `windows_domain_netbios` variables (global and per-VM override).
- `proxy_url` variable (global and per-VM) — HTTP/HTTPS proxy URL for the package install step. Set via `TF_VAR_proxy_url`.
- Initial tagged release of the Linux multi-VM VMware template.

### Changed
- Bumped module source ref to `v1.0.16`.
