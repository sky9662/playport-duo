# Playport Duo

An unofficial community fork of [Playport](https://github.com/playportdev/playport),
which is built on [willfaust/Madeira](https://github.com/willfaust/Madeira).
This fork is not an official Playport release and is not endorsed by the upstream authors.

## Current stable release

[Playport Duo Next07](https://github.com/sky9662/playport-duo/releases/tag/duo-next07)
is the current owner-approved stable release of this fork. The owner reported
Puyo Puyo Tetris runs and approved this exact build. Native release packaging,
distribution checks and source checks passed; long-session stability and
compatibility with every game or device are not established.

The release includes the unsigned IPA, complete Corresponding Source and checksums.
Re-sign with the existing sideloading tool/account and **upgrade in place; do not
uninstall an existing installation**, which deletes its container and local data.
See the [release record](docs/DUO-RELEASES.md) for the exact build and acceptance scope.

The fork implementation is on the
[duo-development branch](https://github.com/sky9662/playport-duo/tree/duo-development).
The fixed release source is tagged
[duo-next07](https://github.com/sky9662/playport-duo/tree/duo-next07).

## Documentation

- [Duo settings and validation limits](https://github.com/sky9662/playport-duo/blob/duo-development/docs/DUO.md)
- [Building](docs/BUILDING.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Device requirements](docs/DEVICE.md)
- [Licensing and third-party notices](docs/LICENSING.md)

[Upstream compatibility reports](https://playport.dev/compatibility/) describe
upstream builds and do not establish compatibility with this fork. Report Duo
problems using this fork's [problem template](https://github.com/sky9662/playport-duo/issues/new?template=problem.yml).

## Attribution and licensing

Original Playport code and its copyright notices are retained.
Playport is licensed under [GPL-3.0-or-later](LICENSE), with the additional
permission described in [LICENSE-EXCEPTION.md](LICENSE-EXCEPTION.md).
Dependencies retain their respective licenses; see the licensing documentation.

Names and trademarks belong to their respective owners. This fork does not claim
ownership of upstream branding or third-party game artwork.
