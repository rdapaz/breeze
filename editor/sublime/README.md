# Breeze — Sublime Text Package

Syntax highlighting, build system, and editor settings for `.bz` files in Sublime Text.

## Installation

Copy the contents of this folder into your Sublime Text Packages directory:

- **Windows:** `%APPDATA%\Sublime Text\Packages\Breeze\`
- **macOS:** `~/Library/Application Support/Sublime Text/Packages/Breeze/`
- **Linux:** `~/.config/sublime-text/Packages/Breeze/`

## Files

| File | Purpose |
|------|---------|
| `Breeze.sublime-syntax` | Syntax highlighting for `.bz` files |
| `Breeze.sublime-build` | Build system (run/compile via Ctrl+B) |
| `Breeze.sublime-settings` | Editor settings (2-space tabs) |
| `Comments.tmPreferences` | Comment toggling (Ctrl+/) |

## Build System

The build file assumes `lua` and `breeze.lua` are on your PATH. If not, edit `Breeze.sublime-build` to use absolute paths:

```json
{
  "cmd": ["C:\\path\\to\\lua.exe", "D:\\path\\to\\breeze.lua", "$file"]
}
```

**Build variants:**
- **Ctrl+B** — Run the current `.bz` file
- **Ctrl+Shift+B → Compile to Lua** — Print compiled Lua output
