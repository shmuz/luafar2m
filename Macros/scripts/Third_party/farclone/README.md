# Rclone File Panel for Far Manager

Access your cloud storage (Google Drive, Dropbox, OneDrive, Mega, Yandex Disk, Box, etc.) directly in Far Manager panels using rclone.

## Features

- Quick access to rclone remotes from Disks menu (Alt+F1/F2)
- Hotkeys 1-9, 0, A-Z for fast remote selection
- Automatic SFTP server management
- Invoke rclone config editor (Shift+F4)
- Server control with manual stop (F8)
- Auto-timeout after configurable period of inactivity
- Visual indication of running server in menu

## Requirements

- [Far Manager 3.x](https://www.farmanager.com/)
- [NetBox plugin](https://github.com/michaellukashov/Far-NetBox)
- [Rclone](https://rclone.org/downloads/)

## Installation

1. Install rclone and configure your remotes:
   ```bash
   rclone config
   ```

2. Copy `rclone_panel.lua` to Far Manager macros directory:
   ```
   %FARPROFILE%\Macros\scripts\
   ```

3. Restart Far Manager or reload macros:
   ```
   macro:load
   ```

4. (Optional) Edit script configuration if rclone is not in PATH

## Usage

### Opening Remotes

1. Press **Alt+F1** (left panel) or **Alt+F2** (right panel)
2. Select "Rclone Remotes" from Disks menu
3. Choose your remote using number/letter hotkey or arrow keys
4. NetBox will open the remote in selected panel

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| **Alt+F1** | Open Disks menu (left panel) |
| **Alt+F2** | Open Disks menu (right panel) |
| **1-9, 0, A-Z** | Quick select remote by hotkey |
| **Enter** | Connect to selected remote |
| **Shift+F4** | Invoke rclone config editor |
| **F8** | Stop running server |

### Server Management

The script automatically:
- Starts rclone SFTP server when you connect to a remote
- Shows running remote with `[running]` marker in menu
- Stops server after timeout period (default: 10 minutes)
- Closes server on Far Manager exit

You can manually stop the server:
- Press **F8** in remotes menu
- Use "Stop Rclone Server" from Plugins menu (F11)

## Configuration

Edit these variables at the top of `rclone_panel.lua`:

```lua
-- Configuration (use \\ for paths in Windows)
local RclonePath = "C:\\Applications\\Utils\\rclone\\rclone.exe"  -- Path to rclone.exe
local ConfigPath = ""  -- Empty = use default rclone config location
local Timeout = 10  -- Server timeout in minutes

-- Server settings (SFTP protocol)
local ServPort = 2022
local ServPass = "rclone"
local RCPort = 5572
```

### Configuration Options

- **RclonePath**: Full path to rclone executable (use `\\` for backslashes). If rclone is in PATH, you can use `"rclone.exe"`
- **ConfigPath**: Path to custom rclone config file. Leave empty `""` to use default location
- **Timeout**: Idle timeout in minutes before server auto-stops
- **ServPort**: SFTP server port (default: 2022)
- **ServPass**: SFTP server password
- **RCPort**: Rclone RC API port (default: 5572)

## How It Works

When you select a remote from the menu:

1. Script starts rclone SFTP server on localhost
2. Server uses remote name as username for identification
3. NetBox opens connection showing `remotename@127.0.0.1:/`
4. Server automatically stops after timeout or manual stop
5. Multiple remotes can be switched by restarting server

The SFTP server runs in background and uses rclone's VFS cache for better performance with streaming-incompatible remotes (Mega, etc.).

## Troubleshooting

### "No remotes found" error

Run `rclone config` and create at least one remote. Verify with `rclone listremotes`.

### "Ports in use" error

Another application is using ports 2022 or 5572. Either:
- Close the conflicting application
- Change `ServPort` and `RCPort` in script configuration

### NetBox asks about shell session

This is normal for SFTP protocol. Check "Never ask me again" to suppress the dialog.

### Server doesn't stop when closing NetBox

This is expected behavior. The server will auto-stop after the configured timeout period. You can manually stop it with F8 or from Plugins menu.

### Rclone config window requires manual close

After exiting rclone config with 'q', the console window should close automatically. If it doesn't, press Enter or close manually.

## Screenshots

![Rclone Panel Menu](screenshot.png)

## License

MIT License

## Author

Developed with AI assistance

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## Links

- [Rclone Documentation](https://rclone.org/docs/)
- [Far Manager](https://www.farmanager.com/)
- [NetBox Plugin](https://github.com/michaellukashov/Far-NetBox)
