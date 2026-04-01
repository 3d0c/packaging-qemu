# packaging-qemu

CI pipeline that builds QEMU RPM packages from [NVIDIA/QEMU](https://github.com/NVIDIA/QEMU) on GitHub Actions, targeting CentOS Stream 9 (x86_64 and aarch64).

## How it works

A pull request against `nvidia_stable-10.1` with a specially formatted title triggers the build:

```
build: <commit-sha>
```

The pipeline:

1. **build-srpm** — Clones NVIDIA/QEMU at the given commit (including submodules and meson subprojects), creates a source tarball, updates the spec file (pins commit, bumps release), builds an SRPM, and uploads the SRPM to Pulp.
2. **build-rpms** — Installs the SRPM and its build dependencies in a CentOS Stream 9 container, then builds binary RPMs and uploads them directly to Pulp. Runs in parallel for x86_64 and aarch64.
3. **publish** — Creates repository publication(s) in Pulp after all uploads succeed.

Progress is tracked via commits pushed to the PR branch (`srpm ready`, then `rpms ready`). Runs triggered by `github-actions[bot]` are ignored to prevent CI self-trigger loops.

## Getting started

### 1. Trigger a build

Create a branch off `nvidia_stable-10.1` and open a PR with a title like:

```
build: a1b2c3d4e5f6
```

The SHA must be a valid commit in [NVIDIA/QEMU](https://github.com/NVIDIA/QEMU).

### 2. Publish artifacts to Pulp

Before running the workflow, configure these settings in GitHub repository settings:

- `vars.PULP_BASE_URL`
- `vars.PULP_USERNAME`
- `secrets.PULP_PASSWORD`
- `vars.PULP_RPM_REPOSITORY` (repository prefix for binary RPMs; CI uploads/publishes to `<prefix>-x86_64` and `<prefix>-aarch64`)
- `vars.PULP_SRPM_REPOSITORY` (optional; if unset, SRPMs are uploaded/published to `<prefix>-SRPMS`)

After the pipeline finishes, SRPMs and RPMs are uploaded and published in the derived Pulp repository/repositories.

## Repository structure

```
.github/workflows/build.yml   # CI pipeline
scripts/create-tarball.sh      # Clones upstream, inits submodules, archives source as tar.xz
scripts/update-spec.sh         # Pins commit, bumps release
scripts/pulp-common.sh         # Shared Pulp helper functions for CI upload/publish steps
SPECS/qemu-kvm.spec            # RPM spec file
SOURCES/                       # Tarball and additional source files (configs, services, etc.)
```

## Spec file conventions

- `%global commit` — Tracks the upstream NVIDIA/QEMU commit SHA. Set automatically by CI.
- `Release:` — Auto-incremented on each build.
