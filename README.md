# sdc-offline-verify

Verify a Settlement Receipt on a machine with no network: pinned versions of [`sdcreceipt`](https://github.com/SemanticDataCharter/sdcreceipt)
and [`sdcvalidator`](https://github.com/SemanticDataCharter/sdcvalidator), a wheelhouse for installing them without
PyPI, and a worked specimen to run them against.

Use it to reproduce a result independently, to examine it in an air-gapped or audited environment, or to keep a
reproducible copy of exactly what was run.

## Install without a network

Download the wheelhouse for your platform from the [latest release](../../releases/latest), check it against
`SHA256SUMS`, and install from it. Python 3.11, 3.12 or 3.13.

| Platform | Release asset |
|---|---|
| Linux x86_64 (glibc 2.28+) | `wheelhouse-linux-x86_64-py311-313.zip` |
| macOS Apple silicon | `wheelhouse-macos-arm64-py311-313.zip` |
| Windows x86_64 | `wheelhouse-windows-x86_64-py311-313.zip` |

```bash
sha256sum -c --ignore-missing SHA256SUMS      # macOS: shasum -a 256 -c --ignore-missing SHA256SUMS
unzip wheelhouse-linux-x86_64-py311-313.zip -d wheels
python3 -m venv .venv && . .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install --no-index --find-links wheels sdcreceipt sdcvalidator
```

`requirements.lock` records the exact versions the wheelhouses were built from and tested with.

**Not covered:** Intel Macs. `cryptography` 50 ships no x86_64 macOS wheel, and `sdcreceipt` 4.3.4 needs it. On an
Intel Mac, install online (`pip install -r requirements.lock`, which builds from source) or use another machine.

## Run the specimen

```bash
cd specimen && ./verify.sh
```

On Windows run it in WSL or Git Bash. It takes about a minute and checks:

1. The Settlement Receipt names the exact bytes of the source record and of its model.
2. The Receipt's issuer signature and both parties' releases verify.
3. A DENY Receipt over a refused transition is signed and attested but never settles (that failure is expected).
4. Every Governed Data Record validates against its published model, with the SDC4 reference model resolved from
   the local copy through `catalog.xml`, so this step needs no network either.
5. The credit note cites the Settlement Receipt's URN.
6. Every file matches `MANIFEST.sha256`.

The specimen is the deduction case from [HalvorsenDemo](https://github.com/SemanticDataCharter/HalvorsenDemo):
fictitious parties (Kestrel Mercantile, Halvorsen Foods), a 54.14 USD credit, and a refused contrast. The demonstration
holds all three signing keys; only public key documents are in `specimen/keys/`. In a real settlement each party
generates and publishes its own.

## The reference model, kept locally

The specimen's models include the SDC4 reference model by its published URL,
`https://semanticdatacharter.com/ns/sdc4/sdc4.xsd`. The kit carries a copy in `specimen/reference-model/sdc4.xsd`,
byte-identical to that URL and to `sdc4/schemas/sdc4.xsd` in
[SemanticDataCharter/SDCRM](https://github.com/SemanticDataCharter/SDCRM) release v4.1.0 (Apache-2.0).
`specimen/catalog.xml` is an OASIS XML Catalogs 1.1 file that maps the URL to the copy. `verify.sh` resolves through
it and refuses to fetch any remote URL the catalog does not list, so a missing entry fails loudly instead of quietly
reaching the network. Both files are in `MANIFEST.sha256`.

The same pattern works for your own records: keep the data, its models, the reference model and a catalog file
together, and validation runs on any machine with no call to the publisher.

## What a pass does and does not show

`sdcreceipt verify` reports what it did not check. In particular, for these Receipts:

- A chain link (`previous_hash`) is not followed, so an earlier Receipt in a chain is not checked.
- Trigger timestamps are not signed, and key validity windows are not compared with the Receipt's time.
- The payload and governance Receipt are checked only if you pass them.

A passing verification shows that a Receipt is intact and was released by the listed parties. It does not show that
the set of records around it is complete, or that the obligation it fixed is still outstanding at a later time. Those
need a separate, stated rule over the parties' own records.

## `--keys` was removed in sdcreceipt 4.3.3

Earlier instructions used `sdcreceipt verify --keys FILE`. Since 4.3.3 each key document must be declared as the
issuer's (`--issuer-keys`) or a party's (`--party-keys`), because pooling them let a party's own document supply an
issuer key (GHSA-gwhr-82j5-883w). `specimen/verify.sh` uses the new flags.

## Rebuilding the wheelhouse

```bash
pip download --only-binary=:all: --python-version 3.13 --platform manylinux_2_28_x86_64 \
    -d wheels sdcreceipt==4.3.4 sdcvalidator==4.6.1
```

Repeat per Python version and platform tag. The wheels are unmodified third-party and Axius releases from PyPI, each
under its own license.

## License

Apache-2.0 for the files in this repository. Packages in the wheelhouses keep their own licenses.
