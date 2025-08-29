# Documentation Browser

A comprehensive PyGUI interface for browsing the Claude Agent Framework documentation system.

## Features

### Navigation
- **Tree-view structure** showing all 8 documentation categories
- **47 total files** organized across guides, reference, architecture, implementation, features, fixes, troubleshooting, and legacy folders
- **Expandable categories** with file counts and descriptions
- **File size information** for each document

### Content Viewing
- **Markdown file rendering** in the built-in text viewer
- **PDF file support** with external viewer integration
- **Syntax highlighting** and proper text formatting
- **Copy file path** functionality for easy reference

### Search Functionality
- **Real-time search** as you type (starts after 3 characters)
- **Comprehensive content search** across all markdown files
- **Filename matching** and content matching
- **Search results window** with context and line numbers
- **Double-click to open** from search results

### Role-Based Quick Access
Pre-configured document sets for different user types:

- **New Users**: Getting started guides, installation, basic usage
- **Developers**: Architecture docs, orchestration status, quick reference
- **System Administrators**: Installation, PostgreSQL setup, troubleshooting
- **Researchers**: Learning system architecture, security integration, binary communications

## Usage

### Starting the Browser
```bash
# Navigate to docs directory
cd /home/ubuntu/Documents/claude-backups/docs

# Run the browser
python3 documentation_browser.py
```

### Navigation
1. **Browse by Category**: Expand folders in the left tree view
2. **Select Files**: Click on any file to view its content
3. **Quick Access**: Use role-based buttons for curated document sets
4. **Search**: Type in the search box to find documents by name or content

### Keyboard Shortcuts
- **Enter** in search box: Perform comprehensive search
- **Double-click** on tree items: Open in external editor
- **Double-click** on search results: Open document

## File Structure Support

The browser supports the complete documentation structure:

```
docs/
├── guides/ (7 files)
│   ├── Installation, configuration, getting started
├── reference/ (8 files)
│   ├── Complete references, overviews, standards
│   └── Includes PDF files
├── architecture/ (9 files)
│   ├── Technical architecture, system design
├── implementation/ (10 files)
│   ├── Implementation reports, completion status
├── features/ (2 files)
│   ├── New features and enhancements
├── fixes/ (2 files)
│   ├── Bug fixes and updates
├── troubleshooting/ (1 file)
│   ├── Problem solving and debugging
└── legacy/ (8 files)
    └── Historical documentation and deprecated info
```

## Requirements

### Python Dependencies
- **tkinter** (usually included with Python)
- **pathlib** (included with Python 3.4+)
- **PIL/Pillow** (optional, for enhanced image support)

### System Requirements
- Python 3.6 or higher
- GUI environment (X11, Wayland, Windows, macOS)
- External editor/viewer for PDF files

## Advanced Features

### External Integration
- **Open in External Editor**: Launch files in your preferred editor
- **PDF Viewer Integration**: Automatic detection and external viewer launching
- **Cross-platform Support**: Works on Linux, Windows, and macOS

### Search Capabilities
- **Filename Search**: Finds documents by name matching
- **Content Search**: Full-text search across all markdown files
- **Context Display**: Shows surrounding text for search matches
- **Line Number References**: Precise location information

### Professional Interface
- **Resizable Panels**: Adjust navigation and content panel sizes
- **Status Bar**: Real-time feedback on operations
- **File Information**: Size, type, and path details
- **Statistics Display**: Total file counts and category information

## Troubleshooting

### Common Issues

1. **Application won't start**
   - Ensure you're running from the docs/ directory
   - Check Python 3 is installed: `python3 --version`
   - Verify tkinter is available: `python3 -c "import tkinter"`

2. **Files not displaying**
   - Verify file permissions are readable
   - Check that markdown files use UTF-8 encoding
   - Ensure file extensions are .md or .pdf

3. **External editor not opening**
   - Install xdg-open (Linux), open (macOS), or configure file associations
   - Check file permissions for execution

### Performance Tips
- Search works best with specific terms rather than single characters
- Large files may take a moment to load in the content viewer
- Use role-based quick access for faster navigation to relevant documents

## Integration

The documentation browser is designed to work seamlessly with the Claude Agent Framework documentation system and can be extended to support additional file types and features as needed.