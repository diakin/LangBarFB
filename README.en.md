# LangBarFB

**English** | [Русский](README.md)

LangBarFB is a keyboard layout switcher for Windows written in FreeBASIC. It shows the current layout, fixes text typed in the wrong layout and can switch the layout by itself.

The program is based on [LangBarXX](https://github.com/Krot66/LangBarXX) (AutoHotkey v1.1, by Krot66). The code was written from scratch; the behavior, default settings, transliteration table, flag file names, sounds, Hunspell dictionaries and the NHunspell library come from LangBarXX. The windows are built with RqLcl, RapidQ classes on top of LCL, from the [unIDE](https://github.com/diakin/unIDE) repository (branch `mainTest`, folder `RqLcl`).

The program is 32-bit and works with windows of any bitness. It was tested on Windows 7.

## Features

- Runs as a single instance in the notification area.
- The tray icon is the flag of the layout of the window you are working in. Flags are loaded from `flags\<code>.png` (`ru-RU.png`, `en-US.png`, the same names as in LangBarXX); without the file, a colored rectangle with the country code is drawn. The `flags` folder is looked up next to the exe and one level above.
- A flag next to the text cursor (windows with a system caret: Notepad, standard Windows edit boxes, Delphi/Lazarus, Word), a flag next to the mouse pointer (off, always, or for 3 s after a layout change), and a large flag in the middle of the screen for 0.7 s when the layout changes.
- A click on the tray icon or on the caret flag switches to the next layout; a right click on the caret flag works like Break.
- Switching from the keyboard: single left or right Shift or Ctrl (single or double press) selects the next, previous or a chosen layout; left Ctrl, Alt or Win + digit 1–9 selects the layout with that number; Caps Lock modes; Num Lock on at startup.
- Text correction with hotkeys (the key combination does not reach the window):

| Action | Default |
| --- | --- |
| Retype the last typed word in the next layout; pressing again cycles through the layouts | Break |
| Convert the layout of the selected text | Shift + Break |
| Invert the case of the selected text | Alt + Break |
| Transliterate the selected text (Cyrillic to Latin) | Alt + Scroll Lock |

  Left Shift+Backspace and Ctrl+Caps Lock can do the same as Break (enabled in the settings). If there is no typed word, Break converts the selected text. Pressing the same combination right after the action restores the original text.
- Automatic switching based on Hunspell dictionaries: the beginning of a word is checked at the third letter, the whole word after a space. If the word is not in the dictionary of the layout it was typed in but is in another one, it is retyped and the layout is switched. Break right after an automatic switch restores the word and remembers it (optionally in `user_dict.dic`).
- Dictionaries come with the installer or are downloaded by the program ("Download dictionaries") for the languages of the Windows layouts: en-US, ru-RU, uk-UA, be-BY, de-DE, fr-FR.
- Settings window: "General", "Switching", "Hotkeys", "Sounds", "Auto switching", "Switching rules" (an empty page for now). Settings are stored in `langbarfb.ini` next to the exe.
- Reset to defaults with a copy of the previous ini in `backup\`, start with Windows, "About LangBarFB" window, help, Russian or English interface.
- Debug window (tray menu opened with Shift held down): key presses, layouts, automatic switching decisions.

More details are in the help: [help/langbarfb.en.html](help/langbarfb.en.html), [help/langbarfb.ru.html](help/langbarfb.ru.html).

## Installation

The installer `LangBarFB_setup_<version>.exe` installs the program to `%LOCALAPPDATA%\LangBarFB` without administrator rights, because the program writes `langbarfb.ini`, dictionaries, `user_dict.dic` and `backup` to its own folder. Setup types: standard (ru and en dictionaries), full, minimal (without automatic switching), custom. A portable mode installs without an uninstaller and shortcuts. A running copy of the program is closed before installing and uninstalling.

Without the installer, put `langbar32.exe`, `rqlcl32.dll` and, optionally, the `help`, `sounds`, `flags`, `hunspell` and `dict` folders into one folder.

## Limitations

- The caret flag appears only in windows with a system caret; browsers and Electron apps do not get it (that needs Acc/UIA).
- The layout of console and UWP windows is not always detected correctly.
- Automatic switching: only a space ends a word (not Enter, Tab or punctuation); there is no single-language mode, no undo with Ctrl+Z and no n-gram check.
- The word for Break is tracked from key presses; a mouse click, Enter, Tab, arrow keys or switching windows resets it.
- After actions on selected text, the clipboard is restored only if it held text.
- LangBarXX settings (`LangBarXX.ini`) are not read.

Not ported from LangBarXX: Num/Scroll/Caps marks on the icon; Shift+Shift, Ctrl+Ctrl, Ctrl+Shift+Shift; short and long presses; Caps Lock "as Shift" and Scroll Lock modes; right Ctrl/Shift + digit or F key; separate case commands; the indicator; application rules; text autoreplace (`hotstrings.ini`).

## Building

You need FreeBASIC for Windows, 32-bit (tested with 1.10.1), and the `RqLcl` folder from unIDE (branch `mainTest`). A 64-bit fbc stops the build with an error.

### From unIDE

Open `src\langbar32.bas`, select GUI and 32 bit and build. The RqLcl folder is set in IDE Options → Compilers → RapidQ Basic → RqLcl folder. unIDE adds `-i <RqLcl>\inc` by itself, puts the exe and `rqlcl32.dll` into `bin\` and takes the exe icon from Project Properties ("Значок exe" field); without it, `src\langbar32.rc` is used.

### With build.bat

Copy `build_local.bat.example` to `build_local.bat` and set your paths (`build_local.bat` itself is not tracked by git):

```
set FB32DIR=D:\FreeBASIC-1.10.1-win32
set RQLCL=D:\unIDE\RqLcl
```

The compiler is looked up as `fbc32.exe`, then `fbc.exe`; without `FB32DIR`, in PATH. Without `RQLCL`, the folder is looked up in `..\unIDE\RqLcl`. `build.bat` builds `bin\langbar32.exe` and copies `rqlcl32.dll`.

### Installer

`LangBarFB.iss` is an Inno Setup 5 script (version 6 does not run on Windows 7), encoded in windows-1251 and based on `LangBarXX.iss`. Build the program first, then open `LangBarFB.iss` in Inno Setup and compile it; the result is `bin\LangBarFB_setup_<version>.exe`. The `flags` folder (flag images from LangBarXX), if present in the repository root, is included in the installer. The version is set at the top of the script (`MyAppVersion`) and must match `APP_VERSION` in `src/ui/dlg_about.bi`.

Windows test checklist: [docs/testing.md](docs/testing.md) (in Russian). Change history: [CHANGELOG.md](CHANGELOG.md) (in Russian). Porting plan: [docs/plan.md](docs/plan.md) (in Russian).

## Files

| File | Contents |
| --- | --- |
| `src/langbar32.bas` | Main program: single instance, tray menu, debug window, timers, message loop |
| `src/core/winapi.bi` | Windows API declarations (`Lb` prefix, without windows.bi) |
| `src/core/kbhook.bi` | Keyboard and mouse hooks (ring buffer of key presses, hotkey filter) |
| `src/core/config.bi` | Settings: `langbarfb.ini`, start with Windows, sounds, reset |
| `src/core/lang.bi` | Interface language: `Tr()` and the English translation table |
| `src/core/hotkeys.bi` | Key combinations: text form, parsing, matching in the hook, capture mode |
| `src/core/switchkeys.bi` | Keyboard switching: single Shift/Ctrl, Ctrl/Alt/Win + digit, Caps Lock, Num Lock |
| `src/core/layouts.bi` | Layout list, layout of a window, layout change |
| `src/core/caret.bi` | Caret position (GetGUIThreadInfo) |
| `src/core/sendkeys.bi` | SendInput (keys, Unicode text), clipboard, copying the selection |
| `src/core/convert.bi` | Text layout conversion, case, transliteration, typed word buffer |
| `src/core/actions.bi` | Hotkey actions |
| `src/core/spell.bi` | Hunspell: library and dictionaries, word check, `user_dict.dic` |
| `src/core/wordstart.bi` | Table of word beginnings for the third-letter check |
| `src/core/autoswitch.bi` | Automatic switching: word check and retyping |
| `src/core/dictload.bi` | Downloading the Hunspell library and dictionaries in a separate thread |
| `src/ui/tray.bi` | Service window, tray icon and its menu |
| `src/ui/gfx.bi` | GDI+: flag from png or text flag, icon |
| `src/ui/overlay.bi` | Topmost windows: caret and mouse flags, notification |
| `src/ui/dlg_settings.bi` | Settings window and "Assign hotkey" window (RqLcl) |
| `src/ui/dlg_about.bi` | "About LangBarFB" window, program version |
| `src/langbar32.rc`, `src/RysLat2.ico` | Exe icon (`FB_PROGRAM_ICON`) |
| `help/` | Help in Russian and English |
| `sounds/` | LangBarXX sounds |
| `hunspell/`, `dict/` | NHunspell library (`Hunspellx86.dll`) and dictionaries from the LangBarXX 1.8.4 installer; licenses in [dict/README.md](dict/README.md) |
| `LangBarFB.iss` | Installer (Inno Setup 5) |
| `build.bat`, `build_local.bat.example` | Build script and a sample paths file |

The `.bas`, `.bi` and `.bat` sources are stored in CP1251 with CRLF, as in unIDE (`.gitattributes`, `working-tree-encoding`). Strings passed to RqLcl must be in CP1251. Source comments are in Russian.

## License

Copyright (C) 2026 Diakin. Developed with Claude Code (Anthropic).

LangBarFB is distributed under the GNU Lesser General Public License version 3 ([COPYING.LESSER](COPYING.LESSER)) together with the GNU General Public License version 3 ([COPYING](COPYING)), the same license as LangBarXX (`_Installer/LGPL-3.0.txt` in its repository).

- LangBarXX: © Krot66, https://github.com/Krot66/LangBarXX.
- Sounds (`sounds/`) and flags come from LangBarXX.

### Third-party libraries

| File | Source | License |
| --- | --- | --- |
| `rqlcl32.dll` | RqLcl from [unIDE](https://github.com/diakin/unIDE) (branch `mainTest`, `RqLcl/bin`; sources in `RqLcl/dll`). RapidQ classes on the Lazarus LCL, built with FPC 3.2.2 and Lazarus 3.8 | RqLcl code: MIT (unIDE `LICENSE`). Inside the DLL: LCL and FPC libraries under the modified LGPL (LGPL with a linking exception); part of the [RichMemo](https://github.com/skalogryz/richmemo) package under the same modified LGPL, texts in `RqLcl/dll/richmemo` |
| `hunspell/Hunspellx86.dll` | NHunspell (Thomas Maierhofer, Crawler-Lib), from the LangBarXX 1.8.4 installer; fallback source: NHunspell 1.2.5554.16953 package on nuget.org | GPL / LGPL / MPL at your choice (nuget.org package description); based on Hunspell |
| `dict/*` | Hunspell dictionaries from the LangBarXX 1.8.4 installer (LibreOffice dictionaries) | Each dictionary has its own, see [dict/README.md](dict/README.md) and `README_*.txt` |
| `gdiplus.dll` and others | Windows system libraries, not shipped | — |
