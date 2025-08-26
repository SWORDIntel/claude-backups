#!/usr/bin/env python3
"""
Universal Documentation Browser
A modular PyGUI interface that adapts to any documentation structure

Features:
- Auto-detection of documentation structure
- Configurable category recognition
- Adaptive role-based access
- Generic search functionality
- Portable and modular design

Usage: python3 universal_docs_browser.py [directory]
"""

import tkinter as tk
from tkinter import ttk, messagebox, filedialog
import os
import sys
import webbrowser
import subprocess
from pathlib import Path
import re
import json
from typing import Dict, List, Optional, Tuple, Set
import threading
import queue
import configparser
import argparse

try:
    from PIL import Image, ImageTk
    PIL_AVAILABLE = True
except ImportError:
    PIL_AVAILABLE = False

class DocumentationStructureAnalyzer:
    """Analyzes and adapts to different documentation structures"""
    
    def __init__(self, root_path: Path):
        self.root_path = root_path
        self.structure = {}
        self.categories = {}
        self.role_mappings = {}
        self.config_file = root_path / ".docs_browser_config.json"
        
    def analyze_structure(self) -> Dict:
        """Automatically analyze documentation structure"""
        structure = {
            'total_files': 0,
            'categories': {},
            'file_types': {},
            'depth': 0,
            'patterns': []
        }
        
        # Load existing config if available
        if self.config_file.exists():
            try:
                with open(self.config_file, 'r') as f:
                    saved_config = json.load(f)
                    if saved_config.get('structure'):
                        return saved_config['structure']
            except Exception:
                pass
        
        # Scan directory structure
        for item in self.root_path.iterdir():
            if item.is_dir() and not item.name.startswith('.'):
                category_info = self._analyze_category(item)
                if category_info['file_count'] > 0:
                    structure['categories'][item.name] = category_info
                    structure['total_files'] += category_info['file_count']
        
        # Also check for files in root
        root_files = self._get_doc_files(self.root_path, recursive=False)
        if root_files:
            structure['categories']['_root'] = {
                'path': str(self.root_path),
                'description': 'Root documentation files',
                'file_count': len(root_files),
                'files': [f.name for f in root_files],
                'patterns': self._detect_patterns([f.name for f in root_files])
            }
            structure['total_files'] += len(root_files)
        
        # Detect overall patterns and depth
        structure['patterns'] = self._detect_global_patterns(structure['categories'])
        structure['depth'] = self._calculate_depth()
        structure['file_types'] = self._analyze_file_types()
        
        self.structure = structure
        return structure
    
    def _analyze_category(self, category_path: Path) -> Dict:
        """Analyze a specific category directory"""
        files = self._get_doc_files(category_path)
        
        return {
            'path': str(category_path),
            'description': self._generate_description(category_path.name, files),
            'file_count': len(files),
            'files': [f.name for f in files],
            'patterns': self._detect_patterns([f.name for f in files]),
            'subdirs': [d.name for d in category_path.iterdir() if d.is_dir()]
        }
    
    def _get_doc_files(self, path: Path, recursive: bool = True) -> List[Path]:
        """Get all documentation files in a directory"""
        extensions = {'.md', '.txt', '.rst', '.pdf', '.html', '.htm', '.adoc', '.tex'}
        files = []
        
        if recursive:
            for ext in extensions:
                files.extend(path.rglob(f'*{ext}'))
        else:
            for ext in extensions:
                files.extend(path.glob(f'*{ext}'))
        
        return [f for f in files if not f.name.startswith('.')]
    
    def _detect_patterns(self, filenames: List[str]) -> List[str]:
        """Detect naming patterns in filenames"""
        patterns = []
        
        # Common patterns
        common_patterns = [
            (r'^README', 'readme'),
            (r'^INSTALL', 'installation'),
            (r'^SETUP', 'setup'),
            (r'^CONFIG', 'configuration'),
            (r'^GUIDE', 'guide'),
            (r'^TUTORIAL', 'tutorial'),
            (r'^API', 'api'),
            (r'^REFERENCE', 'reference'),
            (r'^ARCH', 'architecture'),
            (r'^DESIGN', 'design'),
            (r'^IMPL', 'implementation'),
            (r'^TEST', 'testing'),
            (r'^FIX', 'fixes'),
            (r'^BUG', 'bugfix'),
            (r'^FEATURE', 'features'),
            (r'^CHANGE', 'changelog'),
            (r'^RELEASE', 'releases'),
            (r'^SECURITY', 'security'),
            (r'^DEPLOY', 'deployment'),
            (r'^TROUBLE', 'troubleshooting'),
            (r'^FAQ', 'faq'),
            (r'^LEGACY', 'legacy'),
            (r'^DEPRECAT', 'deprecated'),
            (r'\d{4}-\d{2}-\d{2}', 'dated'),
            (r'v\d+\.\d+', 'versioned')
        ]
        
        for pattern, name in common_patterns:
            if any(re.search(pattern, f, re.IGNORECASE) for f in filenames):
                patterns.append(name)
        
        return patterns
    
    def _detect_global_patterns(self, categories: Dict) -> List[str]:
        """Detect global documentation patterns"""
        all_patterns = []
        for cat in categories.values():
            all_patterns.extend(cat.get('patterns', []))
        
        # Return unique patterns
        return list(set(all_patterns))
    
    def _generate_description(self, category_name: str, files: List[Path]) -> str:
        """Generate description for a category based on its name and contents"""
        name_lower = category_name.lower()
        
        # Predefined descriptions for common categories
        descriptions = {
            'guides': 'User guides and tutorials',
            'guide': 'User guides and tutorials', 
            'docs': 'General documentation',
            'documentation': 'General documentation',
            'reference': 'Reference documentation and specifications',
            'ref': 'Reference documentation',
            'api': 'API documentation and reference',
            'architecture': 'System architecture and design',
            'arch': 'System architecture and design',
            'design': 'Design documents and specifications',
            'implementation': 'Implementation details and reports',
            'impl': 'Implementation details',
            'features': 'Feature documentation and specifications',
            'fixes': 'Bug fixes and patches',
            'bugfixes': 'Bug fixes and patches',
            'security': 'Security documentation and policies',
            'troubleshooting': 'Problem solving and debugging',
            'trouble': 'Problem solving and debugging',
            'faq': 'Frequently asked questions',
            'installation': 'Installation and setup guides',
            'install': 'Installation and setup guides',
            'setup': 'Setup and configuration guides',
            'config': 'Configuration documentation',
            'configuration': 'Configuration documentation',
            'deployment': 'Deployment guides and procedures',
            'deploy': 'Deployment guides',
            'testing': 'Testing documentation and procedures',
            'test': 'Testing documentation',
            'examples': 'Code examples and samples',
            'samples': 'Code examples and samples',
            'tutorial': 'Tutorials and learning materials',
            'tutorials': 'Tutorials and learning materials',
            'legacy': 'Legacy and deprecated documentation',
            'deprecated': 'Deprecated documentation',
            'archive': 'Archived documentation',
            'old': 'Old documentation',
            'backup': 'Backup documentation',
            'temp': 'Temporary documentation',
            'draft': 'Draft documentation',
            'work': 'Work in progress documentation'
        }
        
        # Try to match category name
        for key, desc in descriptions.items():
            if key in name_lower:
                return f"{desc} ({len(files)} files)"
        
        # Fallback: generate based on content patterns
        patterns = self._detect_patterns([f.name for f in files])
        if patterns:
            return f"{patterns[0].title()} documentation ({len(files)} files)"
        
        return f"{category_name.title()} ({len(files)} files)"
    
    def _calculate_depth(self) -> int:
        """Calculate maximum directory depth"""
        max_depth = 0
        for item in self.root_path.rglob('*'):
            if item.is_file():
                depth = len(item.relative_to(self.root_path).parts)
                max_depth = max(max_depth, depth)
        return max_depth
    
    def _analyze_file_types(self) -> Dict[str, int]:
        """Analyze file type distribution"""
        file_types = {}
        for file_path in self._get_doc_files(self.root_path):
            ext = file_path.suffix.lower()
            file_types[ext] = file_types.get(ext, 0) + 1
        return file_types
    
    def generate_role_mappings(self) -> Dict[str, List[str]]:
        """Generate role-based document mappings based on detected structure"""
        mappings = {
            'New Users': [],
            'Developers': [],
            'Administrators': [],
            'Advanced Users': []
        }
        
        # Map based on patterns and category names
        for cat_name, cat_info in self.structure.get('categories', {}).items():
            cat_path = Path(cat_info['path'])
            files = cat_info.get('files', [])
            
            for file_name in files:
                file_path = str(cat_path / file_name)
                relative_path = str(Path(cat_path.name) / file_name) if cat_name != '_root' else file_name
                
                name_lower = file_name.lower()
                cat_lower = cat_name.lower()
                
                # New Users
                if any(pattern in name_lower for pattern in ['readme', 'getting', 'start', 'intro', 'quick', 'begin']):
                    mappings['New Users'].append(relative_path)
                elif any(pattern in cat_lower for pattern in ['guide', 'tutorial', 'intro']):
                    mappings['New Users'].append(relative_path)
                
                # Developers
                if any(pattern in name_lower for pattern in ['api', 'arch', 'design', 'dev', 'code', 'impl']):
                    mappings['Developers'].append(relative_path)
                elif any(pattern in cat_lower for pattern in ['api', 'architecture', 'reference', 'implementation']):
                    mappings['Developers'].append(relative_path)
                
                # Administrators
                if any(pattern in name_lower for pattern in ['install', 'setup', 'config', 'deploy', 'admin', 'trouble']):
                    mappings['Administrators'].append(relative_path)
                elif any(pattern in cat_lower for pattern in ['install', 'setup', 'config', 'deploy', 'troubleshooting']):
                    mappings['Administrators'].append(relative_path)
                
                # Advanced Users
                if any(pattern in name_lower for pattern in ['advanced', 'expert', 'extend', 'custom', 'hack']):
                    mappings['Advanced Users'].append(relative_path)
                elif any(pattern in cat_lower for pattern in ['advanced', 'expert', 'extend']):
                    mappings['Advanced Users'].append(relative_path)
        
        # Remove empty roles and limit items
        filtered_mappings = {}
        for role, docs in mappings.items():
            if docs:
                # Limit to most relevant documents (max 6 per role)
                filtered_mappings[role] = docs[:6]
        
        self.role_mappings = filtered_mappings
        return filtered_mappings
    
    def save_config(self):
        """Save configuration for future use"""
        config = {
            'version': '1.0',
            'root_path': str(self.root_path),
            'structure': self.structure,
            'role_mappings': self.role_mappings,
            'generated_at': str(Path.cwd()),
            'analyzed_at': self.root_path.stat().st_mtime
        }
        
        try:
            with open(self.config_file, 'w') as f:
                json.dump(config, f, indent=2)
        except Exception as e:
            print(f"Warning: Could not save config: {e}")

class UniversalDocumentationBrowser:
    """Universal documentation browser that adapts to any structure"""
    
    def __init__(self, root: tk.Tk, docs_path: Path = None):
        self.root = root
        self.docs_path = docs_path or Path.cwd()
        self.current_file = None
        self.search_results = []
        
        # Initialize structure analyzer
        self.analyzer = DocumentationStructureAnalyzer(self.docs_path)
        self.structure = self.analyzer.analyze_structure()
        self.categories = self.structure.get('categories', {})
        self.role_mappings = self.analyzer.generate_role_mappings()
        
        # Save config for future use
        self.analyzer.save_config()
        
        self.setup_ui()
        self.load_documentation_tree()
        
    def setup_ui(self):
        """Setup the adaptive user interface"""
        project_name = self.docs_path.name.replace('-', ' ').replace('_', ' ').title()
        self.root.title(f"Universal Documentation Browser - {project_name}")
        self.root.geometry("1400x900")
        self.root.minsize(1000, 600)
        
        # Configure style
        style = ttk.Style()
        style.theme_use('clam')
        
        # Main container
        main_frame = ttk.Frame(self.root, padding="5")
        main_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # Configure grid weights
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(0, weight=1)
        main_frame.columnconfigure(1, weight=1)
        main_frame.rowconfigure(1, weight=1)
        
        # Top toolbar
        self.create_toolbar(main_frame)
        
        # Main content area
        content_frame = ttk.Frame(main_frame)
        content_frame.grid(row=1, column=0, columnspan=2, sticky=(tk.W, tk.E, tk.N, tk.S), pady=(5, 0))
        content_frame.columnconfigure(1, weight=1)
        content_frame.rowconfigure(0, weight=1)
        
        # Left panel - Navigation
        self.create_navigation_panel(content_frame)
        
        # Right panel - Content viewer
        self.create_content_panel(content_frame)
        
        # Status bar
        self.create_status_bar(main_frame)
        
    def create_toolbar(self, parent):
        """Create adaptive toolbar"""
        toolbar = ttk.Frame(parent)
        toolbar.grid(row=0, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=(0, 5))
        toolbar.columnconfigure(1, weight=1)
        
        # Role-based quick access (only if roles were detected)
        if self.role_mappings:
            role_frame = ttk.LabelFrame(toolbar, text="Quick Access by Role", padding="5")
            role_frame.grid(row=0, column=0, sticky=(tk.W, tk.N), padx=(0, 10))
            
            for i, role in enumerate(self.role_mappings.keys()):
                btn = ttk.Button(role_frame, text=role, 
                               command=lambda r=role: self.show_role_documents(r))
                btn.grid(row=i//2, column=i%2, padx=2, pady=2, sticky=(tk.W, tk.E))
        else:
            # Fallback: directory browser
            dir_frame = ttk.LabelFrame(toolbar, text="Directory Navigation", padding="5")
            dir_frame.grid(row=0, column=0, sticky=(tk.W, tk.N), padx=(0, 10))
            
            ttk.Button(dir_frame, text="Change Directory", 
                      command=self.change_directory).pack(pady=2)
            ttk.Button(dir_frame, text="Refresh", 
                      command=self.refresh_structure).pack(pady=2)
        
        # Search frame
        search_frame = ttk.LabelFrame(toolbar, text="Search Documentation", padding="5")
        search_frame.grid(row=0, column=1, sticky=(tk.W, tk.E, tk.N), padx=(0, 10))
        search_frame.columnconfigure(0, weight=1)
        
        self.search_var = tk.StringVar()
        self.search_var.trace('w', self.on_search_change)
        
        search_entry = ttk.Entry(search_frame, textvariable=self.search_var, font=('Arial', 10))
        search_entry.grid(row=0, column=0, sticky=(tk.W, tk.E), padx=(0, 5))
        
        search_btn = ttk.Button(search_frame, text="Search", command=self.perform_search)
        search_btn.grid(row=0, column=1)
        
        # Bind Enter key to search
        search_entry.bind('<Return>', lambda e: self.perform_search())
    
    def create_navigation_panel(self, parent):
        """Create adaptive navigation panel"""
        nav_frame = ttk.LabelFrame(parent, text=f"Documentation Structure ({self.docs_path.name})", padding="5")
        nav_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S), padx=(0, 5))
        nav_frame.rowconfigure(0, weight=1)
        nav_frame.columnconfigure(0, weight=1)
        
        # Tree view with scrollbar
        tree_frame = ttk.Frame(nav_frame)
        tree_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        tree_frame.rowconfigure(0, weight=1)
        tree_frame.columnconfigure(0, weight=1)
        
        self.tree = ttk.Treeview(tree_frame, selectmode='browse')
        self.tree.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # Scrollbars for tree
        v_scroll = ttk.Scrollbar(tree_frame, orient=tk.VERTICAL, command=self.tree.yview)
        v_scroll.grid(row=0, column=1, sticky=(tk.N, tk.S))
        self.tree.configure(yscrollcommand=v_scroll.set)
        
        h_scroll = ttk.Scrollbar(tree_frame, orient=tk.HORIZONTAL, command=self.tree.xview)
        h_scroll.grid(row=1, column=0, sticky=(tk.W, tk.E))
        self.tree.configure(xscrollcommand=h_scroll.set)
        
        # Configure tree columns
        self.tree.configure(columns=('info',), show='tree headings')
        self.tree.heading('#0', text='Document/Folder')
        self.tree.heading('info', text='Information')
        self.tree.column('#0', width=300, minwidth=200)
        self.tree.column('info', width=400, minwidth=200)
        
        # Bind tree selection
        self.tree.bind('<<TreeviewSelect>>', self.on_tree_select)
        self.tree.bind('<Double-1>', self.on_tree_double_click)
        
        # Statistics and info
        stats_frame = ttk.Frame(nav_frame)
        stats_frame.grid(row=1, column=0, sticky=(tk.W, tk.E), pady=(5, 0))
        
        self.stats_label = ttk.Label(stats_frame, text="Analyzing structure...", 
                                   font=('Arial', 9), foreground='blue')
        self.stats_label.pack(anchor=tk.W)
        
        # Path info
        self.path_label = ttk.Label(stats_frame, text=f"Path: {self.docs_path}", 
                                   font=('Arial', 8), foreground='gray')
        self.path_label.pack(anchor=tk.W)
    
    def create_content_panel(self, parent):
        """Create content viewing panel"""
        content_frame = ttk.LabelFrame(parent, text="Document Viewer", padding="5")
        content_frame.grid(row=0, column=1, sticky=(tk.W, tk.E, tk.N, tk.S))
        content_frame.rowconfigure(0, weight=1)
        content_frame.columnconfigure(0, weight=1)
        
        # Content viewer with scrollbar
        viewer_frame = ttk.Frame(content_frame)
        viewer_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        viewer_frame.rowconfigure(0, weight=1)
        viewer_frame.columnconfigure(0, weight=1)
        
        self.content_text = tk.Text(viewer_frame, wrap=tk.WORD, font=('Courier', 10),
                                  bg='white', fg='black', selectbackground='lightblue')
        self.content_text.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # Scrollbars for content
        content_v_scroll = ttk.Scrollbar(viewer_frame, orient=tk.VERTICAL, 
                                       command=self.content_text.yview)
        content_v_scroll.grid(row=0, column=1, sticky=(tk.N, tk.S))
        self.content_text.configure(yscrollcommand=content_v_scroll.set)
        
        content_h_scroll = ttk.Scrollbar(viewer_frame, orient=tk.HORIZONTAL, 
                                       command=self.content_text.xview)
        content_h_scroll.grid(row=1, column=0, sticky=(tk.W, tk.E))
        self.content_text.configure(xscrollcommand=content_h_scroll.set)
        
        # Content toolbar
        content_toolbar = ttk.Frame(content_frame)
        content_toolbar.grid(row=1, column=0, sticky=(tk.W, tk.E), pady=(5, 0))
        
        ttk.Button(content_toolbar, text="Open External", 
                  command=self.open_external).pack(side=tk.LEFT, padx=(0, 5))
        ttk.Button(content_toolbar, text="Copy Path", 
                  command=self.copy_file_path).pack(side=tk.LEFT, padx=(0, 5))
        ttk.Button(content_toolbar, text="Show in Folder", 
                  command=self.show_in_folder).pack(side=tk.LEFT, padx=(0, 5))
        
        # File info label
        self.file_info_label = ttk.Label(content_toolbar, text="No file selected", 
                                       font=('Arial', 9), foreground='gray')
        self.file_info_label.pack(side=tk.RIGHT)
    
    def create_status_bar(self, parent):
        """Create adaptive status bar"""
        self.status_var = tk.StringVar()
        total_files = self.structure.get('total_files', 0)
        categories = len(self.categories)
        self.status_var.set(f"Ready - {total_files} files in {categories} categories - {self.docs_path}")
        
        status_bar = ttk.Label(parent, textvariable=self.status_var, 
                             relief=tk.SUNKEN, anchor=tk.W, font=('Arial', 9))
        status_bar.grid(row=2, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=(5, 0))
    
    def load_documentation_tree(self):
        """Load the documentation structure into tree view"""
        try:
            # Clear existing items
            for item in self.tree.get_children():
                self.tree.delete(item)
            
            total_files = 0
            
            # Load each category
            for cat_name, cat_info in self.categories.items():
                if cat_name == '_root':
                    # Handle root files
                    for filename in cat_info.get('files', []):
                        self.tree.insert('', 'end',
                                       text=filename,
                                       values=(f"Root file",),
                                       tags=('file',))
                        total_files += 1
                else:
                    cat_path = Path(cat_info['path'])
                    file_count = cat_info['file_count']
                    total_files += file_count
                    
                    # Insert category node
                    category_id = self.tree.insert('', 'end',
                                                 text=f"{cat_name}/ ({file_count} files)",
                                                 values=(cat_info['description'],),
                                                 tags=('category',))
                    
                    # Add files in this category
                    files = self._get_category_files(cat_path)
                    for file_path in sorted(files):
                        try:
                            file_size = file_path.stat().st_size
                            size_str = self.format_file_size(file_size)
                            
                            self.tree.insert(category_id, 'end',
                                           text=file_path.name,
                                           values=(f"Size: {size_str}",),
                                           tags=('file',))
                        except Exception:
                            # Handle files that might not exist or have permission issues
                            self.tree.insert(category_id, 'end',
                                           text=file_path.name,
                                           values=("File info unavailable",),
                                           tags=('file',))
            
            # Configure tags
            self.tree.tag_configure('category', background='lightblue', font=('Arial', 10, 'bold'))
            self.tree.tag_configure('file', background='white')
            
            # Expand all categories
            for item in self.tree.get_children():
                self.tree.item(item, open=True)
            
            # Update statistics
            cat_count = len([c for c in self.categories.keys() if c != '_root'])
            patterns = ", ".join(self.structure.get('patterns', []))[:50]
            if len(patterns) > 50:
                patterns += "..."
            
            stats_text = f"Total: {total_files} files, {cat_count} categories"
            if patterns:
                stats_text += f"\nPatterns: {patterns}"
            
            self.stats_label.config(text=stats_text)
            self.status_var.set(f"Loaded {total_files} files from {self.docs_path}")
            
        except Exception as e:
            messagebox.showerror("Error", f"Failed to load documentation tree: {e}")
            self.status_var.set(f"Error loading documentation: {e}")
    
    def _get_category_files(self, category_path: Path) -> List[Path]:
        """Get all documentation files in a category"""
        extensions = {'.md', '.txt', '.rst', '.pdf', '.html', '.htm', '.adoc', '.tex'}
        files = []
        
        try:
            for ext in extensions:
                files.extend(category_path.rglob(f'*{ext}'))
        except Exception:
            pass
        
        return [f for f in files if not f.name.startswith('.')]
    
    def change_directory(self):
        """Change the documentation directory"""
        new_dir = filedialog.askdirectory(
            title="Select Documentation Directory",
            initialdir=str(self.docs_path.parent)
        )
        
        if new_dir:
            self.docs_path = Path(new_dir)
            self.refresh_structure()
    
    def refresh_structure(self):
        """Refresh the documentation structure analysis"""
        try:
            # Re-analyze structure
            self.analyzer = DocumentationStructureAnalyzer(self.docs_path)
            self.structure = self.analyzer.analyze_structure()
            self.categories = self.structure.get('categories', {})
            self.role_mappings = self.analyzer.generate_role_mappings()
            
            # Update UI
            project_name = self.docs_path.name.replace('-', ' ').replace('_', ' ').title()
            self.root.title(f"Universal Documentation Browser - {project_name}")
            
            # Reload tree
            self.load_documentation_tree()
            
            # Update path label
            self.path_label.config(text=f"Path: {self.docs_path}")
            
            messagebox.showinfo("Refresh", "Documentation structure refreshed successfully!")
            
        except Exception as e:
            messagebox.showerror("Error", f"Failed to refresh structure: {e}")
    
    def show_in_folder(self):
        """Show current file in system folder"""
        if not self.current_file:
            messagebox.showwarning("Show in Folder", "No file selected")
            return
        
        try:
            folder_path = self.current_file.parent
            if sys.platform.startswith('darwin'):  # macOS
                subprocess.run(['open', str(folder_path)])
            elif sys.platform.startswith('linux'):  # Linux
                subprocess.run(['xdg-open', str(folder_path)])
            elif sys.platform.startswith('win'):  # Windows
                subprocess.run(['explorer', str(folder_path)])
        except Exception as e:
            messagebox.showerror("Error", f"Failed to show in folder: {e}")
    
    # Include all the common methods from the original browser
    def format_file_size(self, size: int) -> str:
        """Format file size in human-readable format"""
        for unit in ['B', 'KB', 'MB']:
            if size < 1024.0:
                return f"{size:.1f} {unit}"
            size /= 1024.0
        return f"{size:.1f} GB"
    
    def on_tree_select(self, event):
        """Handle tree selection"""
        selection = self.tree.selection()
        if not selection:
            return
        
        item = selection[0]
        item_text = self.tree.item(item, 'text')
        
        # Check if it's a file (not a category)
        if not item_text.endswith(')'):  # Categories end with file count in parentheses
            parent = self.tree.parent(item)
            if parent:
                # File in category
                category = self.tree.item(parent, 'text').split('/')[0]
                category_info = self.categories.get(category, {})
                if category_info:
                    category_path = Path(category_info['path'])
                    file_path = self._find_file_in_category(category_path, item_text)
                    if file_path:
                        self.load_file_content(file_path)
            else:
                # Root file
                file_path = self.docs_path / item_text
                if file_path.exists():
                    self.load_file_content(file_path)
    
    def _find_file_in_category(self, category_path: Path, filename: str) -> Optional[Path]:
        """Find a file within a category directory"""
        try:
            # First try direct path
            direct_path = category_path / filename
            if direct_path.exists():
                return direct_path
            
            # Then search recursively
            for file_path in self._get_category_files(category_path):
                if file_path.name == filename:
                    return file_path
        except Exception:
            pass
        return None
    
    def on_tree_double_click(self, event):
        """Handle double-click on tree items"""
        self.open_external()
    
    def load_file_content(self, file_path: Path):
        """Load and display file content"""
        try:
            self.current_file = file_path
            
            if file_path.suffix.lower() in ['.pdf', '.doc', '.docx', '.odt']:
                # Handle binary files
                self.content_text.config(state=tk.NORMAL)
                self.content_text.delete(1.0, tk.END)
                self.content_text.insert(1.0, f"Binary Document: {file_path.name}\n\n")
                self.content_text.insert(tk.END, f"Type: {file_path.suffix.upper()} file\n")
                self.content_text.insert(tk.END, "Click 'Open External' to view this file.\n\n")
                self.content_text.insert(tk.END, f"File path: {file_path}\n")
                self.content_text.insert(tk.END, f"File size: {self.format_file_size(file_path.stat().st_size)}\n")
                self.content_text.config(state=tk.DISABLED)
            else:
                # Handle text files
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                except UnicodeDecodeError:
                    # Try with different encoding
                    with open(file_path, 'r', encoding='latin-1') as f:
                        content = f.read()
                
                self.content_text.config(state=tk.NORMAL)
                self.content_text.delete(1.0, tk.END)
                self.content_text.insert(1.0, content)
                self.content_text.config(state=tk.DISABLED)
            
            # Update file info
            file_size = self.format_file_size(file_path.stat().st_size)
            self.file_info_label.config(text=f"{file_path.name} ({file_size})")
            self.status_var.set(f"Loaded: {file_path.name}")
            
        except Exception as e:
            messagebox.showerror("Error", f"Failed to load file: {e}")
            self.status_var.set(f"Error loading file: {e}")
    
    def show_role_documents(self, role: str):
        """Show documents for a specific role"""
        docs = self.role_mappings.get(role, [])
        if not docs:
            messagebox.showinfo("Role Documents", f"No documents found for role: {role}")
            return
        
        # Create popup window
        popup = tk.Toplevel(self.root)
        popup.title(f"Quick Access - {role}")
        popup.geometry("600x400")
        popup.transient(self.root)
        popup.grab_set()
        
        frame = ttk.Frame(popup, padding="10")
        frame.pack(fill=tk.BOTH, expand=True)
        
        ttk.Label(frame, text=f"Recommended documents for {role}:", 
                 font=('Arial', 12, 'bold')).pack(anchor=tk.W, pady=(0, 10))
        
        listbox = tk.Listbox(frame, font=('Arial', 10))
        listbox.pack(fill=tk.BOTH, expand=True, pady=(0, 10))
        
        # Add documents to listbox
        for doc in docs:
            full_path = self.docs_path / doc
            if full_path.exists():
                listbox.insert(tk.END, doc)
            else:
                listbox.insert(tk.END, f"{doc} (not found)")
        
        # Button frame
        btn_frame = ttk.Frame(frame)
        btn_frame.pack(fill=tk.X)
        
        def open_selected():
            selection = listbox.curselection()
            if selection:
                doc_path = docs[selection[0]]
                full_path = self.docs_path / doc_path
                if full_path.exists():
                    self.load_file_content(full_path)
                    popup.destroy()
                else:
                    messagebox.showerror("Error", f"Document not found: {doc_path}")
        
        ttk.Button(btn_frame, text="Open Document", command=open_selected).pack(side=tk.LEFT)
        ttk.Button(btn_frame, text="Close", command=popup.destroy).pack(side=tk.RIGHT)
        
        listbox.bind('<Double-1>', lambda e: open_selected())
    
    def on_search_change(self, *args):
        """Handle search text change"""
        # Placeholder for real-time search
        pass
    
    def perform_search(self):
        """Perform search across all documents"""
        search_term = self.search_var.get().strip()
        if not search_term:
            messagebox.showwarning("Search", "Please enter a search term")
            return
        
        self.status_var.set(f"Searching for: {search_term}")
        results = []
        
        try:
            # Search through all accessible files
            for cat_name, cat_info in self.categories.items():
                cat_path = Path(cat_info['path'])
                
                if cat_name == '_root':
                    files_to_search = [self.docs_path / f for f in cat_info.get('files', [])]
                else:
                    files_to_search = self._get_category_files(cat_path)
                
                for file_path in files_to_search:
                    if file_path.suffix.lower() in ['.md', '.txt', '.rst', '.html', '.htm']:
                        try:
                            with open(file_path, 'r', encoding='utf-8') as f:
                                content = f.read()
                            
                            # Search in filename
                            if search_term.lower() in file_path.name.lower():
                                results.append((file_path, "filename", f"Found in filename: {file_path.name}"))
                            
                            # Search in content
                            lines = content.split('\n')
                            for i, line in enumerate(lines, 1):
                                if search_term.lower() in line.lower():
                                    context = line.strip()[:100] + "..." if len(line) > 100 else line.strip()
                                    results.append((file_path, f"line {i}", context))
                        
                        except Exception:
                            continue  # Skip files that can't be read
            
            self.show_search_results(search_term, results)
            
        except Exception as e:
            messagebox.showerror("Search Error", f"Search failed: {e}")
            self.status_var.set("Search failed")
    
    def show_search_results(self, search_term: str, results):
        """Show search results in popup"""
        if not results:
            messagebox.showinfo("Search Results", f"No results found for: {search_term}")
            self.status_var.set(f"No results found for: {search_term}")
            return
        
        # Create results window
        results_window = tk.Toplevel(self.root)
        results_window.title(f"Search Results - {search_term}")
        results_window.geometry("800x500")
        results_window.transient(self.root)
        
        frame = ttk.Frame(results_window, padding="10")
        frame.pack(fill=tk.BOTH, expand=True)
        
        ttk.Label(frame, text=f"Found {len(results)} results for: {search_term}", 
                 font=('Arial', 12, 'bold')).pack(anchor=tk.W, pady=(0, 10))
        
        # Results tree
        columns = ('file', 'location', 'context')
        results_tree = ttk.Treeview(frame, columns=columns, show='headings', height=15)
        
        results_tree.heading('file', text='File')
        results_tree.heading('location', text='Location')
        results_tree.heading('context', text='Context')
        
        results_tree.column('file', width=250)
        results_tree.column('location', width=100)
        results_tree.column('context', width=400)
        
        # Add results
        for file_path, location, context in results:
            try:
                relative_path = file_path.relative_to(self.docs_path)
                results_tree.insert('', 'end', values=(str(relative_path), location, context))
            except ValueError:
                # Handle files outside the docs path
                results_tree.insert('', 'end', values=(str(file_path), location, context))
        
        results_tree.pack(fill=tk.BOTH, expand=True, pady=(0, 10))
        
        def open_result():
            selection = results_tree.selection()
            if selection:
                item = results_tree.item(selection[0])
                file_name = item['values'][0]
                file_path = self.docs_path / file_name
                if file_path.exists():
                    self.load_file_content(file_path)
                    results_window.destroy()
        
        # Buttons
        btn_frame = ttk.Frame(frame)
        btn_frame.pack(fill=tk.X)
        
        ttk.Button(btn_frame, text="Open Selected", command=open_result).pack(side=tk.LEFT)
        ttk.Button(btn_frame, text="Close", command=results_window.destroy).pack(side=tk.RIGHT)
        
        results_tree.bind('<Double-1>', lambda e: open_result())
        
        self.status_var.set(f"Found {len(results)} results for: {search_term}")
    
    def open_external(self):
        """Open current file in external editor"""
        if not self.current_file:
            messagebox.showwarning("Open External", "No file selected")
            return
        
        try:
            if sys.platform.startswith('darwin'):  # macOS
                subprocess.run(['open', str(self.current_file)])
            elif sys.platform.startswith('linux'):  # Linux
                subprocess.run(['xdg-open', str(self.current_file)])
            elif sys.platform.startswith('win'):  # Windows
                os.startfile(str(self.current_file))
            else:
                messagebox.showinfo("Open External", f"Please open manually: {self.current_file}")
        except Exception as e:
            messagebox.showerror("Error", f"Failed to open external editor: {e}")
    
    def copy_file_path(self):
        """Copy current file path to clipboard"""
        if not self.current_file:
            messagebox.showwarning("Copy Path", "No file selected")
            return
        
        try:
            self.root.clipboard_clear()
            self.root.clipboard_append(str(self.current_file))
            self.status_var.set(f"Copied path: {self.current_file.name}")
        except Exception as e:
            messagebox.showerror("Error", f"Failed to copy path: {e}")


def main():
    """Main application entry point"""
    parser = argparse.ArgumentParser(description='Universal Documentation Browser')
    parser.add_argument('directory', nargs='?', default=None,
                       help='Documentation directory (default: current directory)')
    parser.add_argument('--config', help='Use specific configuration file')
    
    args = parser.parse_args()
    
    # Determine documentation directory
    if args.directory:
        docs_path = Path(args.directory).resolve()
    else:
        # Try to find documentation directory
        current = Path.cwd()
        candidates = [
            current / 'docs',
            current / 'doc', 
            current / 'documentation',
            current
        ]
        
        docs_path = current
        for candidate in candidates:
            if candidate.exists() and candidate.is_dir():
                # Check if it contains documentation files
                doc_files = list(candidate.glob('*.md')) + list(candidate.glob('*.rst')) + list(candidate.glob('*.txt'))
                if doc_files or any(candidate.iterdir()):
                    docs_path = candidate
                    break
    
    if not docs_path.exists():
        print(f"Error: Directory not found: {docs_path}")
        sys.exit(1)
    
    if not docs_path.is_dir():
        print(f"Error: Not a directory: {docs_path}")
        sys.exit(1)
    
    print(f"Universal Documentation Browser")
    print(f"Analyzing documentation at: {docs_path}")
    
    # Create and run the application
    root = tk.Tk()
    
    try:
        app = UniversalDocumentationBrowser(root, docs_path)
        
        def on_closing():
            root.destroy()
        
        root.protocol("WM_DELETE_WINDOW", on_closing)
        root.mainloop()
        
    except Exception as e:
        messagebox.showerror("Application Error", f"Failed to start browser: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()