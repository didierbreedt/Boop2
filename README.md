# Boop2

Boop2 is a macOS scratchpad for transforming text with [Boop](https://github.com/IvanMathy/Boop)'s JavaScript tools. This fork uses a native text editor and adds tabs.

## Download

Download `Boop2-macOS.zip` from the [latest Boop2 release](https://github.com/didierbreedt/Boop2/releases/latest). Unzip the archive and move `Boop2.app` to Applications. The app contains both Apple Silicon and Intel code.

The GitHub build uses an ad hoc signature. Apple has not notarized it. macOS may block the first launch. If you trust this build, open System Settings → Privacy & Security and select **Open Anyway** after the first launch attempt.

Every push to `main` also creates a temporary ZIP under [GitHub Actions](https://github.com/didierbreedt/Boop2/actions). Version tags starting with `v` publish the ZIP as a GitHub release asset.

## Features

- Native macOS text editor with line numbers and a status bar for word, character, line, and selection counts.
- Persistent tabs. Boop2 saves each tab as a UTF-8 text file in its sandboxed Application Support folder. Use the File menu to open that folder in Finder.
- ⌘T creates a tab. ⌘1 through ⌘9 select the matching numbered tab.
- Settings → General controls the monochrome Boop menu bar icon.
- Boop's JavaScript tools and custom scripts. Press ⌘B to choose a script.

Boop2 uses plain text. The original SavannaKit syntax coloring is not part of the new editor.

## Build from source

Open `Boop/Boop.xcodeproj` in Xcode and run the `Boop` scheme. Run `./install.sh` to build a Debug app and install it at `/Applications/Boop2.app`.

See the [Boop documentation](Boop/Documentation/Readme.md) for the original app and its scripts. Boop2 retains the [MIT license](LICENSE).
