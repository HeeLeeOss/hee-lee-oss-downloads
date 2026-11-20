# The verify image: one image for every sandbox evaluator (Q23, design note sections 3 and 16).
#
# It holds every tool the evaluator registry names, at the registry's absolute path, and nothing an
# evaluator does not need: no coding agent, no credential, no sudo, no elan, no curl, wget or git, no
# mathlib, and no setuid or setgid file. Build-only tools stay in the build stages; the final stage
# copies in only the installed tool directories, and unpacks the Lean tarball itself. BUILD.md beside
# this file gives the owner's steps.
#
# Every version and checksum below is pinned, and each comment names its source. Looked up on
# 2026-11-13. On 2026-11-18 the owner built the previous version of this file in the sbx build sandbox:
# every download and checksum passed and the Lean, Rocq and Python stages built, and the final stage ran
# out of space in the sandbox's 9.8 GB /var/lib/docker. This version is arranged to fit (see "Disk"
# below), and the owner built it the same day; BUILD.md records that run. The image is linux/amd64 only
# (the Lean tarball is x86_64).
#
# Disk. Every stage's layers stay on disk until the build ends, and a file that a later RUN changes is
# copied whole into that RUN's layer. So each build stage deletes what it does not ship, and clears the
# group and other write bits, in the same RUN that made the files; the final stage unpacks Lean from the
# checked tarball, bind-mounted, rather than copying an unpacked tree out of a stage, so the unpacked
# toolchain is on disk once; and no RUN in the final stage changes a file under /opt/hlo: it only checks
# owner and mode.
#
#   Base     debian:trixie-20261104-slim (Debian 13.7), index digest from Docker Hub's official
#            `library/debian` repository; tags and artifact commits from
#            https://github.com/docker-library/official-images/blob/master/library/debian
#   Debian   every package comes from snapshot.debian.org at the base image's own build time,
#            20261104T212339Z (the debuerreotype epoch 1793827419 of the amd64 slim artifact,
#            docker-debian-artifacts commit 373f61a386722a989c79f0c11f23fcf379b56e94), so every
#            Debian package version, build-only ones included, is fixed by that one timestamp. apt
#            checks each index against the Debian archive key already in the base image.
#   Lean     4.35.0, https://github.com/leanprover/lean4/releases/tag/v4.35.0
#   Rocq     9.3.0 (rocq-runtime, rocq-core) and the Rocq Stdlib 9.2.0, the Stdlib release whose
#            notes say "Compatible with Rocq 9.1, 9.2 and 9.3":
#            https://github.com/rocq-prover/rocq/releases/tag/V9.3.0 and
#            https://github.com/rocq-prover/stdlib/releases/tag/V9.2.0; installed with opam, the
#            route Rocq's INSTALL.md at V9.3.0 recommends ("Opam 2.3 is known to work"), from
#            opam-repository at a fixed commit, on OCaml 4.14.2 (INSTALL.md: OCaml >= 4.14.0;
#            "Support for OCaml 5.x remains experimental")
#   Python   3.15.2, https://www.python.org/downloads/release/python-3152/
#   pip      26.3, https://pypi.org/project/pip/26.3/
#   coreutils and util-linux: from the base image (coreutils 9.7-3, util-linux 2.41.5-0+deb13u1,
#            per the artifact's rootfs.manifest)
#   procps   2:4.0.4-9 (procps-ng 4.0.4), for `kill` and `pgrep` (F43)

ARG BASE=debian:trixie-20261104-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2

# ---------------------------------------------------------------------------------------------------
# snap: the base image with apt pointed at the one snapshot. Every later stage starts here.
FROM --platform=linux/amd64 ${BASE} AS snap
# Source: https://snapshot.debian.org/ (timestamp as above). http, not https: the base image has no
# CA bundle, and apt verifies every index against the archive keyring whatever the transport.
RUN set -eu; \
    f=/etc/apt/sources.list.d/debian.sources; \
    sed -i \
      -e 's#^URIs: http://deb.debian.org/debian-security$#URIs: http://snapshot.debian.org/archive/debian-security/20261104T212339Z#' \
      -e 's#^URIs: http://deb.debian.org/debian$#URIs: http://snapshot.debian.org/archive/debian/20261104T212339Z#' \
      "$f"; \
    if grep -q 'deb.debian.org' "$f"; then echo "unreplaced source in $f"; exit 1; fi; \
    test "$(grep -c '^URIs: http://snapshot.debian.org/archive/' "$f")" -eq 2; \
    printf 'Acquire::Check-Valid-Until "false";\nAPT::Install-Recommends "false";\n' > /etc/apt/apt.conf.d/90hlo-snapshot

# ---------------------------------------------------------------------------------------------------
# build: the build-only tools. Nothing in this stage reaches the final image except the files the
# final stage copies by path.
FROM snap AS build
RUN set -eu; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      build-essential pkg-config ca-certificates curl git xz-utils zstd \
      m4 unzip bzip2 patch rsync libgmp-dev \
      opam=2.3.0-1+deb13u2 \
      libssl-dev zlib1g-dev libffi-dev libbz2-dev liblzma-dev libsqlite3-dev libmpdec-dev \
      libzstd-dev uuid-dev; \
    rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------------------------------
# lean: the official release tarball, checked against its sha256. It stays packed here (594481375 bytes,
# the size GitHub lists for the asset); the final stage unpacks it.
FROM build AS lean
# Source: https://github.com/leanprover/lean4/releases/download/v4.35.0/lean-4.35.0-linux.tar.zst
# sha256: the asset digest GitHub lists for that file on the v4.35.0 release.
RUN set -eu; \
    curl -fsSL --proto '=https' --tlsv1.2 -o /tmp/lean.tar.zst \
      https://github.com/leanprover/lean4/releases/download/v4.35.0/lean-4.35.0-linux.tar.zst; \
    echo '7289597a44543246c9227b8cae501767e095ce17f6d448b95fc4a8dc97268f6d  /tmp/lean.tar.zst' | sha256sum -c -

# ---------------------------------------------------------------------------------------------------
# rocq: Rocq 9.3.0 and the Stdlib through opam, in a switch whose prefix is /opt/hlo/rocq, so the
# final stage copies it to the same path it was built for.
FROM build AS rocq
ENV OPAMROOT=/opt/hlo OPAMYES=1 OPAMROOTISOK=1 OPAMNODEPEXTS=1 OPAMCOLOR=never
# Source: https://github.com/ocaml/opam-repository at commit ec55494d94f36dd0a83fc57b8eff27def5177dc0
# (master on 2026-11-13). opam checks every package source against the sha256 its opam file gives,
# among them rocq-9.3.0.tar.gz (3f0fc283e8644394aa9c7a6e3995b6d9ebbe1e6dda712bf431f9c372dcef95ad, as the
# Rocq V9.3.0 release lists it) and stdlib-9.2.0.tar.gz
# (f2ee1cb0b9af3e7b20625f0e9ec4becb7a27bb453d53b9bc0ea3d67bc8b3142c, as the Stdlib V9.2.0 release lists it).
# One RUN, so the checkout, opam's copy of the repository, its download cache and its logs, deleted at
# the end, are in no layer. Only the switch is copied out.
RUN set -eu; \
    git init -q /tmp/opam-repository; \
    git -C /tmp/opam-repository fetch -q --depth 1 https://github.com/ocaml/opam-repository.git \
      ec55494d94f36dd0a83fc57b8eff27def5177dc0; \
    git -C /tmp/opam-repository checkout -q FETCH_HEAD; \
    test "$(git -C /tmp/opam-repository rev-parse HEAD)" = ec55494d94f36dd0a83fc57b8eff27def5177dc0; \
    opam init --bare --disable-sandboxing --no-setup default /tmp/opam-repository; \
    opam switch create rocq --packages=ocaml-base-compiler.4.14.2; \
    opam install --switch=rocq \
      dune.3.25.0 ocamlfind.1.9.8 zarith.1.14 \
      rocq-runtime.9.3.0 rocq-core.9.3.0 rocq-stdlib.9.2.0; \
    installed="$(opam list --switch=rocq --installed --short --columns=package)"; \
    for p in ocaml-base-compiler.4.14.2 rocq-runtime.9.3.0 rocq-core.9.3.0 rocq-stdlib.9.2.0; do \
      printf '%s\n' "$installed" | grep -qx "$p" || { echo "not installed: $p"; exit 1; }; \
    done; \
    rm -rf /opt/hlo/rocq/.opam-switch/sources /opt/hlo/rocq/.opam-switch/build \
      /opt/hlo/rocq/.opam-switch/backup /opt/hlo/rocq/doc /opt/hlo/rocq/man; \
    test -x /opt/hlo/rocq/bin/rocq; \
    cd /tmp; \
    printf 'From Stdlib Require Import Arith.\nGoal 2 + 2 = 4. Proof. reflexivity. Qed.\n' > stdlib_check.v; \
    /opt/hlo/rocq/bin/rocq compile stdlib_check.v; \
    rm -f stdlib_check.*; \
    cd /; \
    rm -rf /tmp/opam-repository /opt/hlo/repo /opt/hlo/download-cache /opt/hlo/log; \
    chmod -R go-w /opt/hlo/rocq

# ---------------------------------------------------------------------------------------------------
# python: CPython from python.org's source tarball, checked against its sha256, then pip 26.3 from
# its PyPI wheel, checked against its sha256 and installed with no index.
FROM build AS python
# One RUN, so the tarball, the source tree and the build tree, deleted in it, are in no layer, and the
# pip reinstall adds no second layer of pip.
# Source: https://www.python.org/ftp/python/3.15.2/Python-3.15.2.tar.xz
# sha256: the SHA-256 python.org lists for that file on the 3.15.2 release page.
# Source: https://files.pythonhosted.org/packages/07/25/ee8c38ae72d66b844ce8eb9711ba905dba21ca1a8a0c960057c41cd23337/pip-26.3-py3-none-any.whl
# sha256: the digest PyPI's JSON API (https://pypi.org/pypi/pip/26.3/json) lists for that file.
RUN set -eu; \
    curl -fsSL --proto '=https' --tlsv1.2 -o /tmp/Python-3.15.2.tar.xz \
      https://www.python.org/ftp/python/3.15.2/Python-3.15.2.tar.xz; \
    echo '8b5536d280142ecf6cdfe15d12a21ba1c65e300bbf7b28a8d0cdb849575797de  /tmp/Python-3.15.2.tar.xz' | sha256sum -c -; \
    tar -xJf /tmp/Python-3.15.2.tar.xz --no-same-owner -C /tmp; \
    cd /tmp/Python-3.15.2; \
    ./configure --prefix=/opt/hlo/python --with-ensurepip=install; \
    make -j"$(nproc)"; \
    make install; \
    cd /; \
    rm -rf /tmp/Python-3.15.2 /tmp/Python-3.15.2.tar.xz /opt/hlo/python/lib/python3.15/test; \
    curl -fsSL --proto '=https' --tlsv1.2 -o /tmp/pip-26.3-py3-none-any.whl \
      https://files.pythonhosted.org/packages/07/25/ee8c38ae72d66b844ce8eb9711ba905dba21ca1a8a0c960057c41cd23337/pip-26.3-py3-none-any.whl; \
    echo 'f3b60b20ffaadd4415ed7957212a38ac63fa4c5fa375bd0f4a797777940fad13  /tmp/pip-26.3-py3-none-any.whl' | sha256sum -c -; \
    /opt/hlo/python/bin/python3 -m pip install --no-index --no-deps --no-cache-dir --force-reinstall \
      --disable-pip-version-check /tmp/pip-26.3-py3-none-any.whl; \
    rm -f /tmp/pip-26.3-py3-none-any.whl; \
    test -x /opt/hlo/python/bin/pip3; \
    /opt/hlo/python/bin/python3 -c 'import ssl, ctypes, _decimal, lzma, bz2, zlib, sqlite3, hashlib, venv'; \
    chmod -R go-w /opt/hlo/python

# ---------------------------------------------------------------------------------------------------
# verify: the image the owner loads with `sbx template load`.
FROM snap AS verify

# procps for F43's `kill` and `pgrep`, and the two libraries the Python build links that the slim
# base lacks. Exact versions, as the snapshot holds them. Then apt loses its download methods and its
# lists, so nothing in the image can fetch a package.
RUN set -eu; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      procps=2:4.0.4-9 libproc2-0=2:4.0.4-9 libffi8=3.4.8-2 libmpdec4=4.0.1-5; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/* /usr/lib/apt/methods

# The tools, owned by root and writable by nobody else: COPY sets the owner, and each stage has already
# cleared the group and other write bits. Lean is unpacked below.
COPY --from=rocq --chown=0:0 /opt/hlo/rocq /opt/hlo/rocq
COPY --from=python --chown=0:0 /opt/hlo/python /opt/hlo/python

# The CA bundle only (from Debian's ca-certificates 20250419+deb13u1, installed in the build stage),
# without the ca-certificates package, whose dependency would bring the openssl command, a network
# client. pip's TLS checks read it through OpenSSL's default paths.
COPY --from=build --chown=0:0 /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

# Lean, unpacked here from the tarball the lean stage checked. The tarball is bind-mounted, so it is in no
# layer of this image, and the unpacked toolchain is written once. The base has GNU tar but no zstd
# program, so tar's decompressor is the image's own Python 3.15 (its compression.zstd module, built
# against the build stage's libzstd, on the base's libzstd1), and tar fails if that program exits
# non-zero. The digest is checked again, on the exact bytes unpacked. The script is deleted in the same RUN.
RUN --mount=type=bind,from=lean,source=/tmp/lean.tar.zst,target=/tmp/lean.tar.zst \
    set -eu; \
    echo '7289597a44543246c9227b8cae501767e095ce17f6d448b95fc4a8dc97268f6d  /tmp/lean.tar.zst' | sha256sum -c -; \
    printf '%s\n' 'import shutil, sys' 'from compression import zstd' \
      'shutil.copyfileobj(zstd.ZstdFile(sys.stdin.buffer), sys.stdout.buffer, 1 << 20)' > /tmp/hlo-unzstd.py; \
    mkdir -p /opt/hlo/lean; \
    tar --use-compress-program='/opt/hlo/python/bin/python3 -I /tmp/hlo-unzstd.py' \
      -xf /tmp/lean.tar.zst --strip-components=1 --no-same-owner -C /opt/hlo/lean; \
    rm -f /tmp/hlo-unzstd.py; \
    chmod -R go-w /opt/hlo/lean; \
    test -x /opt/hlo/lean/bin/lean; \
    test -x /opt/hlo/lean/bin/lake

# Users (design note section 16). The tool user runs probes, the file-type and digest steps and the
# tree copy; the deed user runs every step that executes bytes from the tree and has no home. `agent`
# (uid 1000, /home/agent) is the account Docker Sandboxes documents for a custom image; no evaluator
# step runs as it. None of them has sudo: the image has no sudo at all. Nothing under /opt/hlo is changed
# here, since changing a file's owner or mode would copy the whole file into this layer; the build fails
# instead if any path there is not owned by root, or is writable by group or others.
RUN set -eu; \
    mkdir -p /usr/lib/ssl; \
    ln -sfn /etc/ssl/certs/ca-certificates.crt /usr/lib/ssl/cert.pem; \
    ln -sfn /etc/ssl/certs /usr/lib/ssl/certs; \
    groupadd --gid 10001 hlo-tool; \
    useradd --uid 10001 --gid 10001 --home-dir /home/hlo-tool --create-home --shell /usr/sbin/nologin hlo-tool; \
    groupadd --gid 10002 hlo-deed; \
    useradd --uid 10002 --gid 10002 --home-dir /nonexistent --no-create-home --shell /usr/sbin/nologin hlo-deed; \
    groupadd --gid 1000 agent; \
    useradd --uid 1000 --gid 1000 --home-dir /home/agent --create-home --shell /bin/bash agent; \
    chmod 0700 /home/hlo-tool /home/agent; \
    test -z "$(find /opt/hlo \( ! -uid 0 -o ! -gid 0 -o \( ! -type l -perm /022 \) \) -print)"; \
    chmod 0755 /var/tmp; \
    if [ -d /run/lock ]; then chmod 0755 /run/lock; fi; \
    find / -xdev -perm /6000 -type f -exec chmod ug-s {} +; \
    test -z "$(find / -xdev -perm /6000 -type f)"; \
    test -z "$(find / -xdev -perm -0002 ! -type l ! -path /tmp)"; \
    for t in sudo curl wget git elan opam openssl; do \
      if command -v "$t" >/dev/null 2>&1; then echo "unexpected tool: $t"; exit 1; fi; \
    done; \
    test "$(id -u hlo-tool)" = 10001; \
    test "$(id -u hlo-deed)" = 10002

# The registry's probes, each first line held to the entry's versionPattern and pin. A mismatch fails
# the build: either the image or the registry entry is wrong, and the image is not used until it is
# fixed. The owner-run check in the verify VM (BUILD.md) is the record; this is an early warning.
RUN set -eu; \
    first() { "$@" 2>&1 | head -n 1; }; \
    first /opt/hlo/lean/bin/lean --version | grep -Eqx 'Lean \(version 4\.35\.0, [^ ,]+, commit [0-9a-f]{40}, Release\)'; \
    first /opt/hlo/lean/bin/lake --version | grep -Eqx 'Lake version [0-9]+\.[0-9]+\.[0-9]+-src\+[0-9a-f]{7} \(Lean version 4\.35\.0\)'; \
    first /opt/hlo/rocq/bin/rocq --version | grep -Eqx 'The Rocq Prover, version 9\.3\.0'; \
    first /opt/hlo/python/bin/python3 --version | grep -Eqx 'Python 3\.15\.2'; \
    first /opt/hlo/python/bin/pip3 --version | grep -Eqx 'pip 26\.3 from [^ ]+ \(python [0-9][0-9.]*\)'; \
    first /usr/bin/sha256sum --version | grep -Eqx 'sha256sum \(GNU coreutils\) 9\.7'; \
    first /usr/bin/stat --version | grep -Eqx 'stat \(GNU coreutils\) 9\.7'; \
    first /usr/bin/kill --version | grep -Eqx 'kill from procps-ng 4\.0\.4'; \
    first /usr/bin/pgrep --version | grep -Eqx 'pgrep from procps-ng 4\.0\.4'; \
    test -x /usr/bin/setsid; \
    /opt/hlo/python/bin/python3 -c 'import ssl, ctypes, _decimal, lzma, bz2, zlib, sqlite3, hashlib, venv'

USER agent
WORKDIR /home/agent
CMD ["/bin/bash", "-l"]
