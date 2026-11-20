# Building the verify image (owner steps)

The verify image is built from `Dockerfile` beside this file, with Docker, inside a throwaway sbx sandbox. The tar
the build writes is then loaded into the local sandbox runtime with `sbx template load` (Q23; owner answer of 2026-11-13).
Every step is the owner's, on the machine that runs ignite. No step uses a coding agent, and no step puts a
credential into the image.

The steps below are the ones the owner ran: steps 1 to 6 on 2026-11-18, with `sbx` 0.48.0, and steps 5 and 6
again on 2026-11-19, with `sbx` 0.54.0. On 2026-11-18 an earlier version of the `Dockerfile` first ran out of space
in its final stage, because the build sandbox's `/var/lib/docker` is a separate 9.8 GB volume; the version beside
this file is the one that then built. The dates are UTC. Step 6 writes its listings out in fewer, tidier commands
than the owner typed in those runs, and not every command of step 6 was run again with `sbx` 0.54.0.

The checks at the end are AC-04 and AC-11 of the evaluators design note
(`docs/superpowers/specs/2026-11-11-evaluators-design.md`, sections 3, 16 and 18). Both passed on 2026-11-19, and
the run is recorded at the end of this file ("The recorded run"). The commit that records it replaced the verify
entry's `<Q23>` placeholders in `adapters/sandbox-registry.json` with the values below, after F43 had landed
(`FullSDLCtasks.md`).

## What the image is

| Item | Value |
|---|---|
| Base | `debian:trixie-20261104-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2` (Debian 13.7, linux/amd64) |
| Debian packages | snapshot.debian.org at `20261104T212339Z`, the base image's own build time |
| Image name | `hlo-verify`, tag `1` |
| Tool user | `hlo-tool`, uid and gid 10001, home `/home/hlo-tool` (mode 0700) |
| Deed user | `hlo-deed`, uid and gid 10002, home `/nonexistent` (not created) |
| sbx account | `agent`, uid and gid 1000, home `/home/agent`, the image's `USER`; no evaluator step runs as it |

None of the three accounts has sudo, and the image has no `sudo` at all. The build removes the setuid and setgid
bits from every file, and leaves no world-writable path but `/tmp`. The tools under `/opt/hlo` are owned by root
and writable by nobody else, so neither user can replace one.

`agent` is in the image because Docker Sandboxes documents it as the account a custom image must provide: "a
non-root `agent` account with UID 1000 and home directory `/home/agent`", with `USER agent` set, and executable
`/bin/sh` and `/bin/bash` ([Base images for sandbox workloads](https://docs.docker.com/ai/sandboxes/customize/author/base-images/)).
The same page also lists "curl, git, and trusted CA certificates" as tools a custom image includes. The image
leaves out curl and git by the owner's decision, and keeps the CA bundle, which pip needs. The `shell` agent
started without curl and git (step 5 of the recorded run).

The values these steps produced, which the verify entry now names, are:

- `image`: `hlo-verify@sha256:633604f30c16f61ba72b133bd267883638412dc980ccc7c5c0a38d7ee59d8b52`, the digest step 4
  recorded;
- `toolUser`: `hlo-tool`;
- `deedUser`: `hlo-deed`.

If the image is ever rebuilt, every step below is run again, and recorded, before a new digest replaces this
one.

## 0. Before you start

- Docker's `sbx` CLI at `0.54.0` or later (the registry's `minVersion`; `sbx` 0.48.0 builds and loads the image but
  refuses to create a sandbox from it by digest, step 5). Run `sbx version` and keep the line.
- A shell on the host. The commands are written for PowerShell 7. In Git Bash on Windows, set
  `MSYS_NO_PATHCONV=1` for every `sbx` command: without it, Git Bash rewrites an argument that starts with `/`
  (such as `/usr/bin/id` or `/home/agent/verify-image`) into a Windows path before `sbx` sees it, and the command
  runs the wrong thing or fails.
- Disk. Inside the build sandbox, Docker keeps everything in `/var/lib/docker`, a separate volume of 9.8 GB that
  cannot be made larger. Every layer of every build stage stays there until the build ends. Step 3 writes the
  image straight to a tar in `/home/agent`, on the sandbox's other, larger volume, instead of also unpacking it
  into `/var/lib/docker`: in the owner's run of 2026-11-18 the build plus that unpacked copy did not fit (it
  failed with "no space left on device" while unpacking). In that run the build cache took 5.9 GB of the 9.8 GB,
  and the tar was 1,430,977,536 bytes. The tar is then copied to the host, so the host needs that much free too.
- The build fetches only from these hosts, and every file it fetches is checked against a pinned checksum or
  signature:
  - Docker Hub (`registry-1.docker.io`, `auth.docker.io`, `production.cloudfront.docker.com`), for the base image;
  - `snapshot.debian.org`, for Debian packages (apt checks the archive signature);
  - `github.com`, `codeload.github.com`, `objects.githubusercontent.com`, `release-assets.githubusercontent.com`
    and `raw.githubusercontent.com`, for Lean, opam-repository and the opam package sources;
  - `opam.ocaml.org`, opam's fallback source cache;
  - `www.python.org` and `files.pythonhosted.org`, for Python and pip.

  The sandbox's network policy denies every host by default, so step 3 allows these hosts for the build sandbox
  only, and for no other sandbox. Removing the build sandbox with `sbx rm` (step 4) removes those rules with it.

## 1. Sign in

```
sbx login
sbx version
```

## 2. Create a throwaway sandbox that has a Docker engine

Use the `shell` agent. It has no model and no coding agent. Do not attach to it with `sbx run`. In the owner's run
of 2026-11-18 (`sbx` 0.48.0), the `shell` sandbox had a Docker engine.

```
sbx create --name hlo-image-build --no-progress shell
sbx exec -i hlo-image-build docker version
```

If `docker version` prints both a Client and a Server section, the sandbox has an engine. Go to step 3.

If it does not, remove the sandbox and use the image the docs name for a workload that "needs Docker Engine inside
the sandbox", `docker.io/sbx/shell-docker-image:latest`
([Base images for sandbox workloads](https://docs.docker.com/ai/sandboxes/customize/author/base-images/)), and
record the digest it resolved to:

```
sbx rm -f hlo-image-build
sbx create --name hlo-image-build --no-progress -t docker.io/sbx/shell-docker-image:latest shell
sbx exec -i hlo-image-build docker version
sbx template ls --json
```

If that also has no engine, stop. Do not build on the host's Docker instead: that route has not been approved.

## 3. Build the image into a tar inside the sandbox

Allow the build's hosts (step 0) for this sandbox only. The policy denies every host until this is done:

```
sbx policy allow network --sandbox hlo-image-build "registry-1.docker.io,auth.docker.io,production.cloudfront.docker.com,snapshot.debian.org,github.com,codeload.github.com,objects.githubusercontent.com,release-assets.githubusercontent.com,raw.githubusercontent.com,opam.ocaml.org,www.python.org,files.pythonhosted.org"
```

Copy the build context in. Copy the `adapters/verify-image` directory, not the single `Dockerfile`: `sbx cp` of a
single file into a directory that does not exist yet fails, while a directory is created at the destination. The
build copies nothing from the context, so `BUILD.md` beside the `Dockerfile` does not change the image. Then check
the free space, build, and keep the output:

```
sbx cp adapters/verify-image hlo-image-build:/home/agent/verify-image
sbx exec -i hlo-image-build sha256sum /home/agent/verify-image/Dockerfile
sbx exec -i hlo-image-build df -h /var/lib/docker /home/agent
sbx exec -i hlo-image-build docker build --platform linux/amd64 --pull --output type=docker,name=hlo-verify:1,dest=/home/agent/hlo-verify.tar /home/agent/verify-image
sbx exec -i hlo-image-build docker system df
sbx exec -i hlo-image-build df -h /var/lib/docker /home/agent
sbx exec -i hlo-image-build ls -l /home/agent/hlo-verify.tar
sbx exec -i hlo-image-build sha256sum /home/agent/hlo-verify.tar
```

`--output type=docker,name=...,dest=...` writes the image, named `hlo-verify:1`, as a tar that `sbx template load`
reads, and does not unpack it into `/var/lib/docker`. So no `docker save` is needed, and afterwards the sandbox's
engine holds no `hlo-verify` image (`docker image inspect` finds none). The build log's export lines name the image's
manifest digest (`exporting manifest sha256:...`) and its config digest (`exporting config sha256:...`): keep both.
Step 4 compares the manifest digest with what `sbx` lists.

The build fails on purpose if the following happen:

- a download does not match its checksum;
- an opam package is not at its pinned version;
- the Stdlib cannot be loaded;
- a probe's first line does not match its registry pattern and pin;
- a path under `/opt/hlo` is not owned by root, or is writable by its group or by others;
- a setuid or setgid file, or a world-writable path other than `/tmp`, is left;
- `sudo`, `curl`, `wget`, `git`, `elan`, `opam` or `openssl` is in the final image.

Keep the full build log, and the `df` and `docker system df` output before and after the build.

If the build fails with "no space left on device" again, stop and report it with the log and the `df` output. Do
not delete files from `/var/lib/docker` by hand, and do not build on the host's Docker instead.

If a download fails with a certificate error, the sandbox's proxy may be intercepting TLS for the build's
containers. Stop and report it. Do not turn off certificate checks.

## 4. Copy the tar out and load it

On the host, from the repository root:

```
sbx cp hlo-image-build:/home/agent/hlo-verify.tar ./hlo-verify.tar
sbx rm -f hlo-image-build
sbx template load ./hlo-verify.tar
sbx template ls --json
```

`sbx rm` removes the build sandbox and the network rules step 3 allowed for it, so no other sandbox can reach the
build's hosts.

Record the digest `sbx template ls --json` prints for `hlo-verify:1`. It must equal the manifest digest of step 3's
export. `sbx` 0.48.0 listed only a 12-hex-digit image id (`633604f30c16` in the owner's run, the start of the
manifest digest); `sbx` 0.54.0 lists the full `sha256:` digest. In `sbx` 0.48.0, `sbx template inspect` is
cloud-only (its help says "Cloud-only in v1: requires --cloud"), so `template ls` is the local source.

Delete `hlo-verify.tar` from the repository root when you are done. It must never be committed.

## 5. AC-04: the provider takes the pinned image and runs it

Use the registry's verify create argv, with a throwaway name and the digest from step 4:

```
sbx create --name hlo-verify-check --no-progress --pull never -t hlo-verify@sha256:<digest> shell
sbx exec -i -u hlo-tool hlo-verify-check /usr/bin/id -u
sbx exec -i -u hlo-tool hlo-verify-check /opt/hlo/lean/bin/lean --version
```

Record whether it was accepted and ran the image (`10001`, then the Lean probe line). If it was refused, record the
exact message and stop: AC-04 has failed. `sbx` 0.48.0 makes no sandbox from this form for a loaded image: the
create fails with `error: request failed: 500 Internal Server Error: failed to run sandbox container`. The owner's
notes of that run give the reason: the cache check passes, then the engine tries to pull the digest reference and
is denied ("pull access denied"), because a tar-loaded image has no repository digest. `sbx` 0.54.0 accepts it. In `sbx` 0.54.0 the `shell` agent "now ships as a kit",
and every create prints that it is resolving `docker.io/sbx/shell:latest`; record that line too.

Then check that `--pull never` does not fetch an image that is not loaded. It must refuse:

```
sbx create --name hlo-verify-absent --no-progress --pull never -t hlo-verify@sha256:0000000000000000000000000000000000000000000000000000000000000000 shell
```

If that command made a sandbox, remove it with `sbx rm -f hlo-verify-absent` and record the failure.

## 6. AC-11 and the probes, inside `hlo-verify-check`

Each command is an argv with no shell, except where `sh -c` is written. The quoting is for PowerShell 7 on the
host: single quotes pass their contents unchanged. In Git Bash, set `MSYS_NO_PATHCONV=1` (step 0). Record every
output.

Some listings run as `root` (`-u root`), so that no directory the tool user cannot read hides anything from them.
They are the owner's checks of the image, not evaluator steps: no evaluator step runs as root.

The users, and that `-u` is honoured (expected uid `10001`, then `10002`, each in its own group only):

```
sbx exec -i -u hlo-tool hlo-verify-check /usr/bin/id
sbx exec -i -u hlo-deed hlo-verify-check /usr/bin/id
sbx exec -i -u hlo-tool hlo-verify-check /usr/bin/getent passwd hlo-tool hlo-deed agent root
```

The listings of section 16. Expected: no setuid or setgid file, no file capabilities, no sudo and no sudoers file,
no `hidepid` on `/proc`, and no path the deed user can write outside `/tmp` and `/dev` but what the runtime added
(list each, with the mount it is on):

```
sbx exec -i -u root hlo-verify-check sh -c '/usr/bin/find / \( -path /proc -o -path /sys \) -prune -o -perm /6000 -type f -print; echo setuid-done'
sbx exec -i -u root hlo-verify-check /opt/hlo/python/bin/python3 -c 'import os
n=0
for r,d,fs in os.walk("/"):
  if r.startswith(("/proc","/sys")): d[:]=[]; continue
  for f in fs:
    try:
      if os.getxattr(os.path.join(r,f),"security.capability",follow_symlinks=False): print("cap:",os.path.join(r,f)); n+=1
    except OSError: pass
print("caps:",n)'
sbx exec -i -u hlo-deed hlo-verify-check sh -c '/usr/bin/find / \( -path /proc -o -path /sys -o -path /tmp -o -path /dev \) -prune -o -writable ! -type l -print 2>/dev/null; echo writable-done'
sbx exec -i -u hlo-tool hlo-verify-check sh -c 'for t in elan curl wget git sudo opam openssl; do command -v $t; done; ls /etc/sudoers* 2>&1; grep hidepid /proc/mounts; echo absent-done'
sbx exec -i -u hlo-deed hlo-verify-check sh -c 'grep -E "^(CapEff|NoNewPrivs)" /proc/self/status'
sbx exec -i -u root hlo-verify-check sh -c 'ls -l /usr/local/bin; grep " /run/secrets " /proc/mounts'
```

The first must print only `setuid-done`, and the second `caps: 0`. The third lists what the deed user can write
outside `/tmp` and `/dev`, then `writable-done`. The fourth must print only the `ls` error for `/etc/sudoers*` and
`absent-done`. The fifth shows the deed user's effective capabilities (expected all zero) and its no-new-privileges
flag. The last lists what the runtime added in `/usr/local/bin` and the mount of `/run/secrets`.

The probes from `adapters/evaluators/formal-proof/IMAGE.md`, the reproducibility entry and the verify entry's
`endDeed`, as the tool user. Each first line must match the entry's `versionPattern` and capture the pin:

```
sbx exec -i -u hlo-tool hlo-verify-check /opt/hlo/lean/bin/lean --version
sbx exec -i -u hlo-tool hlo-verify-check /opt/hlo/lean/bin/lake --version
sbx exec -i -u hlo-tool hlo-verify-check /opt/hlo/rocq/bin/rocq --version
sbx exec -i -u hlo-tool hlo-verify-check /opt/hlo/python/bin/python3 --version
sbx exec -i -u hlo-tool hlo-verify-check /opt/hlo/python/bin/pip3 --version
sbx exec -i -u hlo-tool hlo-verify-check /usr/bin/sha256sum --version
sbx exec -i -u hlo-tool hlo-verify-check /usr/bin/stat --version
sbx exec -i -u hlo-tool hlo-verify-check /usr/bin/kill --version
sbx exec -i -u hlo-tool hlo-verify-check /usr/bin/pgrep --version
```

Expected first lines:

- `Lean (version 4.35.0, <target>, commit <40 hex>, Release)`
- `Lake version <x.y.z>-src+<7 hex> (Lean version 4.35.0)`
- `The Rocq Prover, version 9.3.0`
- `Python 3.15.2`
- `pip 26.3 from <path> (python 3.15)`
- `sha256sum (GNU coreutils) 9.7`
- `stat (GNU coreutils) 9.7`
- `kill from procps-ng 4.0.4`
- `pgrep from procps-ng 4.0.4`

The end-deed test of section 16, with the registry's `endDeed` argv. First a step that leaves a background `sleep`,
then one that leaves a process that keeps forking. After each, the kill runs as the deed user and the check as the
tool user. Last, a look for zombies:

```
sbx exec -i -u hlo-tool hlo-verify-check /usr/bin/pgrep --count --uid hlo-deed
sbx exec -i -u hlo-deed hlo-verify-check sh -c '/usr/bin/pgrep -a --uid hlo-deed'
sbx exec -i -u hlo-deed hlo-verify-check sh -c 'nohup sleep 600 >/dev/null 2>&1 & echo started'
sbx exec -i -u hlo-tool hlo-verify-check /usr/bin/pgrep --count --uid hlo-deed
sbx exec -i -u hlo-deed hlo-verify-check /usr/bin/kill -KILL -- -1
sbx exec -i -u hlo-tool hlo-verify-check /usr/bin/pgrep --count --uid hlo-deed
sbx exec -i -u hlo-deed hlo-verify-check sh -c 'nohup sh -c "while :; do sh -c \"sleep 600 &\"; sleep 0.05; done" >/dev/null 2>&1 & echo started'
sbx exec -i -u hlo-tool hlo-verify-check /usr/bin/pgrep --count --uid hlo-deed
sbx exec -i -u hlo-deed hlo-verify-check /usr/bin/kill -KILL -- -1
sbx exec -i -u hlo-tool hlo-verify-check /usr/bin/pgrep --count --uid hlo-deed
sbx exec -i -u root hlo-verify-check sh -c 'ps -eo stat,user,comm | grep -E "^Z"; echo zombie-check-done'
```

Expected: the first check prints `0` and exits 1. The `pgrep -a` from inside a deed exec lists only its own shell,
so no process of the deed user wraps the exec. Each count after a leftover is more than 0 and exits 0. Each kill
exits 0. Each check after a kill prints `0` and exits 1. The zombie look prints only `zombie-check-done`.

This check is informative and does not gate AC-04 or AC-11. It shows whether reproducibility's pip can reach PyPI
through the sandbox proxy with the image's CA bundle. Allow the two pip hosts for this sandbox, then fetch one index
page as the deed user:

```
sbx policy allow network --sandbox hlo-verify-check pypi.org
sbx policy allow network --sandbox hlo-verify-check files.pythonhosted.org
sbx exec -i -u hlo-deed hlo-verify-check /opt/hlo/python/bin/python3 -c 'import urllib.request; print(urllib.request.urlopen("https://pypi.org/simple/pip/").status)'
```

Expected: `200`. A certificate error means the proxy's CA is not in the image's bundle. Record it: reproducibility
cannot install a lockfile until the image trusts that CA.

## 7. Remove the sandbox

```
sbx rm -f hlo-verify-check
sbx ls --json
```

The listing must not name `hlo-verify-check` or `hlo-image-build`. `sbx rm` removes each sandbox's network rules
with it.

## 8. Record

Record these together, in the commit that names the image's digest in the verify entry:

- the date;
- the `sbx version` line of each run;
- the base digest (above);
- the `Dockerfile`'s sha256, and the build log's last lines, with the export's manifest and config digests;
- the `df` and `docker system df` output from step 3;
- the tar's size and sha256, and the `template ls` digest;
- whether the build sandbox had a Docker engine, and which sandbox gave it;
- each command above with its output.

AC-04 passes when step 5's create is accepted with the digest form and runs the image, and the absent digest is
refused. AC-11 passes when step 6 shows the following:

- uid `10001` and `10002`;
- no setuid or setgid file, and no file capabilities;
- no sudo;
- no `hidepid`, so the tool user sees the deed user's processes;
- no path the deed user can write outside `/tmp`, beyond what the runtime mounts;
- the end-deed test as expected above.

Each probe's first line must match its registry entry. If one does not, the entry or the image is wrong, and the
image is not used until it is corrected.

## The recorded run (AC-04 and AC-11)

Run by the owner, on the machine that runs ignite (Windows 11). What follows is taken from the output the owner
saved from the runs. Where a line says "noted", no output was saved, and the line is from the owner's notes made
during the run. The dates are UTC. No token value is recorded.

**Versions and dates.**

- 2026-11-18: steps 1 to 6, `sbx version v0.48.0 5caf923e0587d376848f6f388eca3e0f5ca00e2d`.
- 2026-11-19, 00:16 UTC: steps 5 and 6 again, `sbx version v0.54.0 4bec4a5ce093466e54b034146965b143d065dc09`.

**Build (step 3).** From the `Dockerfile` as the commit "verify image: fit the build in the sandbox's 9.8 GB Docker
volume" left it, sha256 `142947ad3cfa56c072911fa190befe5f2951a1abe63ce71469a989871f48c04c` (`sha256sum` in the build
sandbox, before the build). The commit that records this run changed only the file's header comment, which no build
step reads, so the file beside this one has another sha256. The build sandbox was the `shell` agent's, and it had a
Docker engine. The network allow-list was step 0's hosts, for that sandbox only.

- The first build of this `Dockerfile`, with `-t hlo-verify:1` and no `--output`, built every stage and then failed
  while unpacking the image into the engine: "no space left on device", with `/var/lib/docker` at 9.3 GB used of
  9.8 GB. In that build every step of the final stage ran, none from cache: the Lean unpack, with Python's
  `compression.zstd` as tar's decompressor (`[verify 5/8]`, 16.7 s); the users, with the check that every path under
  `/opt/hlo` is root-owned and not writable by group or others (`[verify 6/8]`, 1.1 s); and the probes
  (`[verify 7/8]`, 0.8 s).
- The build with `--output type=docker,name=hlo-verify:1,dest=/home/agent/hlo-verify.tar`, its stages from the first
  build's cache, exited 0. Export lines: `exporting manifest
  sha256:633604f30c16f61ba72b133bd267883638412dc980ccc7c5c0a38d7ee59d8b52`, `exporting config
  sha256:7cd52d9615462461d74856158da334cb5ec193f1d7e87864cad190bf4c07a784`.
- `df` after the build: `/var/lib/docker` 5.9 GB used of 9.8 GB, 3.4 GB free.
- The tar: 1,430,977,536 bytes, sha256 `4d07ba541e0bdb5c25358768c43c0ee4c33079f3b1504d14e8dde127a8619ec2`.

**Load (step 4).** Noted: `sbx template load` gave the template `docker.io/library/hlo-verify:1`; `sbx` 0.48.0 listed
its id as `633604f30c16`; `sbx` 0.54.0's `sbx template ls --json` lists the digest
`sha256:633604f30c16f61ba72b133bd267883638412dc980ccc7c5c0a38d7ee59d8b52`, equal to the export's manifest digest.
The saved output that shows the loaded image answers to that digest is AC-04's create below, by digest with
`--pull never`.

**AC-04 (step 5): passes on `sbx` 0.54.0.**

- `sbx create --name hlo-verify-check --no-progress --pull never -t
  hlo-verify@sha256:633604f30c16f61ba72b133bd267883638412dc980ccc7c5c0a38d7ee59d8b52 shell` printed
  `now ships as a kit; resolving docker.io/sbx/shell:latest` for the `shell` agent, then
  `Created sandbox hlo-verify-check`. In it, `id -u` as `hlo-tool` printed `10001`, and the Lean probe printed its
  pinned line.
- The all-zero digest was refused: `error: image
  "hlo-verify@sha256:0000000000000000000000000000000000000000000000000000000000000000" is not cached locally and
  pull_policy=never; pre-pull the image or use pull_policy=missing`. No sandbox was made.
- On `sbx` 0.48.0 (2026-11-18), the digest form made no sandbox: `error: request failed: 500 Internal Server Error:
  failed to run sandbox container`. Noted: the cache check passed, then the engine tried to pull the digest reference
  and was denied ("pull access denied", "insufficient_scope"); the config digest was "not cached locally". The tag
  form `-t hlo-verify:1` was accepted (`Created sandbox hlo-verify-check`). So the registry's `minVersion` is 0.54.0.

**AC-11 (step 6): passes**, on `sbx` 0.48.0 with the image by tag and on `sbx` 0.54.0 by digest.

- Users: `uid=10001(hlo-tool) gid=10001(hlo-tool) groups=10001(hlo-tool)` and `uid=10002(hlo-deed)
  gid=10002(hlo-deed) groups=10002(hlo-deed)` (0.54.0; on 0.48.0, `id -u` printed `10001` and `10002`); both have the
  shell `/usr/sbin/nologin` (`getent passwd`, 0.48.0).
- The setuid and setgid listing, as root over every mount but `/proc` and `/sys`, printed nothing, on both. The
  file-capability walk found none, on both (`caps: 0` on 0.54.0).
- `elan`, `curl`, `wget`, `git`, `sudo`, `opam` and `openssl` are absent, and there is no `/etc/sudoers` or
  `/etc/sudoers.d`, on both. `/proc` has no `hidepid`, on both. On 0.48.0, a process of the tool user read `CapEff:
  0000000000000000` and `NoNewPrivs: 0` (not set); the deed user's were not read, and neither was read on 0.54.0.
- Paths the deed user can write: outside `/tmp` and `/dev`, only `/run/secrets` (0.54.0). Under `/dev` (0.48.0):
  `/dev/null`, `/dev/zero`, `/dev/full`, `/dev/random`, `/dev/urandom`, `/dev/tty`, `/dev/pts/ptmx`, `/dev/shm`
  (a tmpfs, `noexec`) and `/dev/mqueue`. `/run/secrets` is an empty tmpfs the runtime adds, mode 1777, `noexec`.
- Probes, first lines, each matching its entry's pattern and pin:
  - `Lean (version 4.35.0, x86_64-unknown-linux-gnu, commit eb6cafb7290e8bd5f2937522d8d804f58f02bafc, Release)`
  - `Lake version 5.0.0-src+eb6cafb (Lean version 4.35.0)`
  - `The Rocq Prover, version 9.3.0`
  - `Python 3.15.2`
  - `pip 26.3 from /opt/hlo/python/lib/python3.15/site-packages/pip (python 3.15)`
  - `sha256sum (GNU coreutils) 9.7`
  - `stat (GNU coreutils) 9.7`
  - `kill from procps-ng 4.0.4`
  - `pgrep from procps-ng 4.0.4`
- End-deed test (0.48.0): the first check printed `0` and exited 1. A `pgrep -a` inside an exec as `hlo-deed`
  listed only its own `sh`, so no process of the deed user wraps the exec. A leftover `sleep`: count 1 (exit 0),
  kill exit 0, check `0` (exit 1). A forking leftover: count 55 (exit 0), kill exit 0, check `0` (exit 1). The
  zombie look printed only `zombie-check-done`.
- End-deed test (0.54.0): a forking leftover: count 50 (exit 0), kill exit 0, check `0` (exit 1). The first check,
  the `pgrep -a` look, the leftover `sleep` and the zombie look were not run again on 0.54.0.
- The record shows each check's output as the line `0`; it does not show the bytes.

**Not run.** The informative pip-to-PyPI TLS check of step 6, because it needs `pypi.org` allowed for the check
sandbox. Whether reproducibility's pip can install a lockfile through the sandbox's proxy with the image's CA
bundle is not known.

**What the runtime adds, outside the image** (`sbx` 0.54.0). These are known runtime additions, not part of the
image, and are followed up as F93 to F95 in `FullSDLCtasks.md`:

- The `shell` agent is a kit that every create resolves from `docker.io/sbx/shell:latest`, by tag, not by digest.
  Since F93's rule commit the verify entry pins it (`kit.ref`), and `sandbox create --verify` refuses unless the
  host setting `kit.shortcuts.shell` is exactly that digest reference. Every operator must run
  `sbx settings set kit.shortcuts.shell docker.io/sbx/shell@sha256:89ed5d63def6bfb2373d408e3ab6ad55aa5c010f884a182a78299fcf85ea42d1`
  on their own host before evaluators run: until then every verify create there is refused (`verify-host-settings`).
  The owner's live test (2026-11-19 03:49 UTC, `sbx` 0.54.0): with the shortcut set, `sbx create --pull never -t
  hlo-verify@sha256:633604f3...8b52 shell` printed that it was resolving `docker.io/sbx/shell@sha256:89ed5d63...`
  from `kit.shortcuts.shell` and created the sandbox; `id -u` printed 10001 as `hlo-tool` and 10002 as `hlo-deed`,
  and `rocq --version` printed "The Rocq Prover, version 9.3.0". The sandbox was then removed.
- Host helpers in `/usr/local/bin`: `clip.exe`, `pbcopy`, `sbx-clipboard`, `sbx-clipboard-write`, `wl-copy`,
  `wl-paste`, `xclip`, `xdg-open` and `xsel`. They ask the host, through the runtime's gateway, to open a URL in the
  host's browser or to write its clipboard. The image has no `curl` or `jq`, so the helpers themselves do not run,
  but a deed's own code can reach the same endpoint. Noted: a clipboard write was refused (403) with
  `clipboard.textCopy` false. Opening a URL was not tried, since it would have opened the owner's browser. `browser.enabled` was true,
  `sbx`'s default; the owner has since turned it off, and `sandbox create --verify` refuses unless both settings
  are off.
- `/run/secrets`, the empty tmpfs above.
- Noted: in the environment of every exec user, the deed user included: a GitHub-shaped `GH_TOKEN` placeholder (not the
  host's token: the proxy swaps it on an allowed request), `HTTPS_PROXY`, `PROXY_CA_CERT_B64` and
  `MCP_SENTINEL_TOKEN_NAME`. The verify exec sets `GH_TOKEN` empty; the others stay. The verify VM's network policy
  is deny-all with only the plan's ecosystem hosts opened, so no host the proxy holds a credential for is reachable;
  `sandbox create --verify` refuses (`verify-proxy-credentials`) while one would be (F94).
- The kit's own `sh` and `sleep` run as `agent`.
