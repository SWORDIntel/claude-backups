# Nano Editor Quick Reference

## Why Nano?
- **User-friendly** - Commands shown at bottom of screen
- **No modes** - Unlike vim, you're always in "edit mode"
- **Simple** - Just start typing!

## Essential Nano Commands

### File Operations
- **Ctrl+O** - Save file (WriteOut)
- **Ctrl+X** - Exit nano
- **Ctrl+R** - Read/insert another file

### Editing
- **Ctrl+K** - Cut current line
- **Ctrl+U** - Paste (Uncut)
- **Ctrl+W** - Search
- **Ctrl+\** - Search and replace
- **Alt+U** - Undo
- **Alt+E** - Redo

### Navigation
- **Ctrl+A** - Beginning of line
- **Ctrl+E** - End of line
- **Ctrl+Y** - Page up
- **Ctrl+V** - Page down
- **Ctrl+_** - Go to line number

### Other Useful
- **Ctrl+G** - Help
- **Ctrl+C** - Show cursor position
- **Alt+#** - Toggle line numbers
- **Ctrl+J** - Justify (format) paragraph

## Common Workflows

### Create and edit a new file:
```bash
nano agent_discovery.c
# Type your code
# Ctrl+O to save
# Enter to confirm filename
# Ctrl+X to exit
```

### Quick edit and save:
```bash
nano TODO.md
# Make changes
# Ctrl+X (it will ask to save)
# Y (yes to save)
# Enter (confirm filename)
```

### Search and replace:
```bash
nano ultra_hybrid_enhanced.c
# Ctrl+W to search
# Ctrl+\ for replace
# Enter search term
# Enter replacement
# A to replace all
```

## VS Code Alternative

If you prefer a GUI editor and have VS Code installed:
```bash
# Open file in VS Code
code agent_discovery.c

# Open entire project
code .
```

## Other Beginner-Friendly Editors

### Gedit (if GUI available)
```bash
gedit agent_discovery.c &
```

### Micro (modern terminal editor)
```bash
# Install if not present
sudo apt install micro

# Use it
micro agent_discovery.c
```

## Pro Tip for Nano

Add this to your `~/.nanorc` for better experience:
```bash
echo "set linenumbers" >> ~/.nanorc    # Always show line numbers
echo "set mouse" >> ~/.nanorc          # Enable mouse support
echo "set tabsize 4" >> ~/.nanorc      # Set tab to 4 spaces
echo "set autoindent" >> ~/.nanorc     # Auto-indent new lines
```

## Quick Comparison

| Task | Vim | Nano | VS Code |
|------|-----|------|---------|
| Open file | `vim file.c` | `nano file.c` | `code file.c` |
| Start typing | `i` first | Just type! | Just type! |
| Save | `:w` | `Ctrl+O` | `Ctrl+S` |
| Exit | `:q` | `Ctrl+X` | `Ctrl+W` |
| Save & Exit | `:wq` | `Ctrl+X, Y` | `Ctrl+S, Ctrl+W` |

## For Your Development

All the commands in TODO.md and checkpoints now use nano:
```bash
# Original (vim)
vim agent_discovery.c

# Updated (nano) 
nano agent_discovery.c

# Just as effective, much friendlier!
```

Remember: **The editor doesn't matter** - the code does! Use whatever you're comfortable with. 😊