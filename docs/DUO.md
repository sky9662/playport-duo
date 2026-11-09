# Playport Duo

This community fork retains Playport's app identity, built-in JIT helper, game prefix and save locations. Upgrade an existing installation in place after backing up saves.

Settings > Graphics and each game's options expose Game cursor, DOOM memory compatibility, and OpenGL 4.1 compatibility. Default keeps the installed cursor and shared-image behavior and each title's OpenGL profile. Off explicitly removes the OpenGL version overrides from the launch copy of the shared configuration and the process environment, without editing the shared file; changing mapping or graphics compatibility applies on the next game start. Cursor display still follows the game's cursor visibility request.

Cursor size is adjustable from 100% to 400% in the same settings. Turing Complete defaults to 200%; other games retain 100%. Scaling enlarges the image around its hotspot, so the guest click position stays unchanged. Choose 100% to restore the original presentation.

Settings > Controls and each game's options offer independent touch trackpad and mouse sensitivity from 10% to 400%. Mouse sensitivity also controls relative touch look. Absolute tapping, scrolling, controller look and gyro remain separate. A game's Default follows Settings; resetting Settings restores 100%.

The running game's menu (three-finger tap, or hold a controller's Home button) also exposes both sensitivity steppers under Controls, including 250%. Changes are saved for that game and take effect when resuming. These are constant multipliers; no speed-dependent acceleration is applied.

The aspect ratio and resolution select the Windows virtual desktop. Phone uses the current scene's shape; 4:3 uses an inscribed rectangle and preserves bars rather than stretching. Wine enumerates common 4:3 modes that fit that desktop, including 720x540, 960x720, 1024x768 and 1280x960. Available modes update with scene geometry while the game's current logical mode remains selectable and unchanged until the game changes it. A game's selected display mode and actual presented framebuffer remain distinct from the physical panel. An engine may filter or fix its own modes. This fork does not rewrite Turing Complete's fullscreen or resolution settings.

Duo edge-to-edge behavior requires the genuine iOS 27.1 SDK. Build roots are read from xtool's swift-sdk.json, without renaming SDK directories or spoofing SDK versions. Xcode 27 SDK stubs require a linker supporting arm64e.x1; Apple's ld64 dependency uses the upstream TextAPI fix. Keep previous SDK and toolchain installations available during migration.

The memory page distinguishes the entitlement present in the signature from iOS's estimated current process budget. That estimate can change; physical RAM is not the process limit.

Cloud sync failures show details and a retry action on the game page. Existing saves and the losing side of an explicitly settled conflict retain the existing backup behavior. A failed download is not recorded as successfully synchronized.

Auto-Cloud directory root overrides for Windows are read from each game's PICS `ufs/rootoverrides`. For example, Turing Complete keeps `%SteamCloudDocuments%` in server file names while its Windows override stores those files under `AppData/Roaming/Turing Complete`. Both downloads and local-file discovery use that mapping, retaining the original cloud names for uploads and comparing existing saves before writing. Directory additions are supported; replacement/path-transform overrides remain unsupported rather than guessing a destination. See [Steamworks Auto-Cloud root overrides](https://partner.steamgames.com/doc/features/cloud#root_overrides).

Host tests do not establish device compatibility. Full-screen folding, mode selection inside Windows/OpenGL/Vulkan games, cursor alignment, cloud synchronization and performance require owner validation of the native IPA after an in-place test installation. Distribute the final IPA only after that validation.
