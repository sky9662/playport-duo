# Playport Duo releases

## Current stable: Next07 (`duo-next07`)

Published 2026-11-15 (Asia/Taipei) at the owner's request, after the owner reported
Puyo Puyo Tetris runs. This is the current stable baseline of this community fork,
not an official upstream Playport release.

- [Release and downloads](https://github.com/sky9662/playport-duo/releases/tag/duo-next07)
- [Fixed source checkpoint](https://github.com/sky9662/playport-duo/tree/duo-next07)
- Build source commit: `47e3f7922eb9dc114d7d61cb6c56af7031f23b04`.
- GitHub source checkpoint: `898259c189f6edb588f8ec577e3fc76564270581`.
- Both have source tree `b6c9908cbb6308f5df8d23d65840744af0d370d0`;
  the GitHub checkpoint has different commit metadata/history.
- IPA: `PlayportDuoNext07-PuyoController.ipa` (403,899,515 bytes).
- IPA SHA-256: `6a45e91fd499bc26a7e7e435de1430fce743d8a6766e0ce9c32cc7ee03f7e46a`.

The released IPA is the same file tested by the owner, without a rebuild or
binary change during promotion. Puyo's title profile uses a 512 MiB JIT pool;
the shared Steam shim implements the no-argument Controller lifecycle with no
connected devices. Full Steam Input and physical Steam Controller support are
not implemented by this change.

Native release build, 96 IPA checks, distribution notice checks, name and secret
checks passed. The x64 and i386 Steam client ABI probes each passed 7,414 slots
across 248 interface versions. The complete source archive (16 trees, 22 files)
and delivery checksums were verified.

The owner's acceptance establishes the reported Puyo startup result and approval
of this release. It does not establish long-session stability, all game features,
or every device. No additional Hollow Knight regression run was performed for
this candidate. The attached packaging audit predates the owner's acceptance;
its `device_validated: false` is retained as the original packaging record.

Download the complete `PlayportDuoNext07-PuyoController-source.tar` asset for the
Corresponding Source, dependency source and build/relink instructions. GitHub's
automatic source ZIP alone is not that complete bundle. The asset provenance and
release SHA256SUMS identify the exact files.

Re-sign with the existing sideloading tool and account. Back up saves, then
upgrade in place. Do not uninstall an existing app, which deletes its container
and local game data. The ordinary signing, JIT and device requirements remain.
