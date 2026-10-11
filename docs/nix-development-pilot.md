# Nix development environment experiment

On 2026-10-11, Jeffrey approved a small Nix development environment experiment
for Prompt Registry and Spanish Studio. The purpose is to determine whether
pinned toolchains reduce setup time and environment failures for fresh coding
agents and worktrees. Adoption beyond these repositories depends on measured
benefit and maintenance effort.

## Scope and decision

- Prompt Registry is the ordinary TypeScript service case.
- Spanish Studio is the mixed Node, Python, and native audio dependency case.
- Pin toolchains with `flake.nix` and `flake.lock`; retain npm lockfiles.
- Keep Ubuntu, systemd deployments, production runtimes, and worker isolation.
- Start with local verification. Add opt-in CI verification after local results
  are understood; broad worker activation and production changes are separate
  later decisions.

The host runs Node 24.14.1 and Python 3.12.3. Prompt Registry's `.nvmrc` names
Node 22, its `server/.node-version` names 20.17.0, and its existing CI job uses
Node 20. Both pilot shells select Node 24 to match the production major version;
the exact patch version is pinned by Nixpkgs and can differ from the host.

## Pilot locations

| Repository | Branch | Worktree |
| --- | --- | --- |
| homelab | experiment/nix-dev-environments | /home/jkeyser/.worktrees/homelab-nix-pilot |
| prompt-registry | experiment/nix-dev-environment | /home/jkeyser/.worktrees/prompt-registry-nix-pilot |
| spanish-studio | experiment/nix-dev-environment | /home/jkeyser/.worktrees/spanish-studio-nix-pilot |

See each application's `docs/nix-development.md` for repeatable verification
commands. Jeffrey requested publication to `main` on 2026-10-11. Prompt Registry
`b7f7231` and Spanish Studio `e93efef` are now pushed to their repositories'
`main` branches. The worktrees above retain the original experiment branches.

## Installation and activation

Nix 2.35.2 was installed from the official release tarball after SHA-256
verification. This bounded pilot uses a single-user installation owned by
`jkeyser`, with no daemon, channels, or shell profile modifications. Activate
explicitly when needed:

```bash
. "$HOME/.nix-profile/etc/profile.d/nix.sh"
```

`~/.config/nix/nix.conf` enables `nix-command` and `flakes`, limits build jobs
to one, and gives each build two cores to limit contention on the Beelink.
The upstream-recommended multi-user installation can be evaluated if adoption
expands. The official installer does not provide a security boundary for agents
sharing this user account.

## Measures and acceptance

Record the first shell realization time, cached shell entry time, npm install
time, build/test outcomes, tool versions, Nix store size, and any required manual
fixes. Compare with normal host tools at the same source revision. Cache state
and npm authentication must be noted when comparing timings.

A useful pilot should reproduce tool versions from the same lockfile in a
second fresh worktree, pass the existing offline test suites, and require no
production credentials. Failures must be compared with host-tool baselines
before attributing them to Nix. Keeping the same results on one host alone does
not establish portability to CI, macOS, or other hardware.

## Results

The local pilot passes on x86_64 Linux. Prompt Registry's server builds and
passes 149 tests. Spanish Studio's server and client build; 624 server tests,
143 client tests, and 26 Python sidecar tests pass. Two server integration tests
skip because Azure credentials and a seeded test database were not supplied.
Host-tool baselines also pass the same 149 Prompt Registry tests and 624 Spanish
Studio server tests, plus all 26 sidecar tests using the existing production
venv's Python executable against the pilot source.

A native smoke check generated an Opus/WebM tone, passed it through the built
application's FFmpeg transcoder, verified 16 kHz mono WAV output, and measured
220 Hz with Parselmouth. A generated HEIC also converted to JPEG using the
configured Nix image converter and the application's argument pattern.

| Measure | Prompt Registry | Spanish Studio |
| --- | --- | --- |
| First environment realization | 28.19 s | 61.00 s for the initial full FFmpeg variant |
| Cached entry, final environment | 0.91 s | 1.97 s |
| Fresh worktree entry, same cached store | 1.03 s | 1.98 s |
| npm installation using existing cache | 9.57 s server | 3.61 s root, 7.29 s server, 5.68 s client |
| Node / npm | 24.18.0 / 11.16.0 | 24.18.0 / 11.16.0 |

Fresh detached worktrees reproduced identical tool versions and store paths
with only HOME, USER, and the basic system PATH supplied. The Nix store occupies
about 2.7 GiB, including the initial full FFmpeg variant and build dependencies.
The final Spanish Studio environment uses headless FFmpeg 8.0, libheif 1.20.2,
Python 3.12.13, Parselmouth 0.4.6, NumPy 2.3.4, Flask 3.1.2, and pytest 8.4.2.
Nixpkgs 25.11 was selected to keep pytest within the sidecar's existing `<9`
requirement; updates should recheck all Python version constraints.

Two adjustments were needed: select `libheif.bin` and its `heif-dec` executable,
and make the server's defaults test unset image-tool environment overrides
before asserting `/usr/bin` defaults. No application behavior changed. Flake
validation passes for the host architecture. The application changes are
committed locally as Prompt Registry `b7f7231` and Spanish Studio `e93efef`.

These timings used the existing npm cache and private package authentication.
Some realizations and tests ran concurrently, so the numbers do not establish
a speed advantage over host tools. The result establishes that both fresh
checkouts can use the pinned toolchain on this host. CI and other platforms
remain the next validation stage.

The durable [measurement record](nix-development-pilot-results.json) includes
stage timings, host baselines, initial failure, and replay results. Full logs
from this run are under `/tmp/nix-pilot-results/` and are temporary.

## Next stage

Use the documented Nix commands for work assigned to these pilot repositories and
record environment failures or manual setup steps. Add opt-in CI verification
using the same lockfiles on `main`. Evaluate adoption
after several real worker runs; keep deployment changes outside this pilot.
