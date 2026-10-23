# Jam notes (ATL Gamedevs Jam, 2026-10-23): what broke or was missing, for after

- **`init .`**: let init write into the current directory (`haxelib run helix init .`), e.g. a freshly cloned
  `gamejams-<name>` repo. Today it refuses any directory with something in it (a clone has `.git/`, maybe a README or
  LICENSE), and the game's name comes from the directory's path, which for `.` needs to be the current directory's
  name, not ".". Decide what existing files it tolerates (`.git/`, README/LICENSE/.gitignore: keep or merge?).
