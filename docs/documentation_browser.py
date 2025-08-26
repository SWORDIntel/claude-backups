#!/usr/bin/env python3
"""
Documentation Browser for Claude Agent Framework
A comprehensive PyGUI interface for browsing the organized documentation system

Features:
- Tree-view navigation with 8 category folders
- Content viewer with markdown rendering
- Search functionality across all documents
- Role-based quick access buttons
- Support for .md and .pdf files
- Professional user interface

Usage: python3 documentation_browser.py
"""

import tkinter as tk
from tkinter import ttk, messagebox, filedialog
import os
import sys
import webbrowser
import subprocess
from pathlib import Path
import re
from typing import Dict, List, Optional, Tuple
import threading
import queue
import json

try:
    from PIL import Image, ImageTk
    PIL_AVAILABLE = True
except ImportError:
    PIL_AVAILABLE = False

class DocumentationBrowser:
    """Main documentation browser application"""
    
    def __init__(self, root: tk.Tk):
        self.root = root
        self.current_file = None
        self.search_results = []
        self.docs_root = Path(__file__).parent
        
        # Documentation categories and their descriptions
        self.categories = {
            'guides': 'Installation, configuration, getting started (7 files)',
            'reference': 'Complete references, overviews, standards, includes PDFs (8 files)',
            'architecture': 'Technical architecture, system design (9 files)',
            'implementation': 'Implementation reports, completion status (10 files)',
            'features': 'New features and enhancements (2 files)',
            'fixes': 'Bug fixes and updates (2 files)',
            'troubleshooting': 'Problem solving and debugging (1 file)',
            'legacy': 'Historical documentation and deprecated info (8 files)'
        }
        
        # Role-based quick access mappings
        self.role_mappings = {
            'New Users': [
                'guides/installation-guide.md',
                'reference/PROJECT_OVERVIEW.md',
                'guides/FIRST_TIME_LAUNCH_GUIDE.md',
                'guides/README.md'
            ],
            'Developers': [
                'architecture/tandem-orchestration.md',
                'reference/COMPLETE_AGENT_LISTING.md',
                'architecture/existing-agent-enhancement-guide.md',
                'architecture/binary-communication.md'
            ],
            'System Administrators': [
                'guides/CONFIGURATION_GUIDE.md',
                'architecture/CONTAINERIZED_POSTGRESQL_SYSTEM.md',
                'troubleshooting/TROUBLESHOOTING_GUIDE.md',
                'guides/installation-guide.md'
            ],
            'Researchers': [
                'reference/241007-hybrid-threats-and-hybrid-warfare.pdf',
                'architecture/ml-learning-system.md',
                'implementation/LEARNING_SYSTEM_IMPLEMENTATION_COMPLETE.md',
                'reference/Cyber-Reports-2019-10-CyberInfluence.pdf'
            ]
        }
        
        self.setup_ui()
        self.load_documentation_tree()
        
    def setup_ui(self):
        """Setup the main user interface"""
        self.root.title("Claude Agent Framework - Documentation Browser")
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
        """Create the top toolbar with search and quick access"""
        toolbar = ttk.Frame(parent)
        toolbar.grid(row=0, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=(0, 5))
        toolbar.columnconfigure(1, weight=1)
        
        # Role-based quick access
        role_frame = ttk.LabelFrame(toolbar, text="Quick Access by Role", padding="5")
        role_frame.grid(row=0, column=0, sticky=(tk.W, tk.N), padx=(0, 10))
        
        for i, role in enumerate(self.role_mappings.keys()):
            btn = ttk.Button(role_frame, text=role, 
                           command=lambda r=role: self.show_role_documents(r))
            btn.grid(row=i//2, column=i%2, padx=2, pady=2, sticky=(tk.W, tk.E))
        
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
        """Create the left navigation panel with tree view"""
        nav_frame = ttk.LabelFrame(parent, text="Documentation Structure", padding="5")
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
        self.tree.configure(columns=('description',), show='tree headings')
        self.tree.heading('#0', text='Document')
        self.tree.heading('description', text='Description')
        self.tree.column('#0', width=300, minwidth=200)
        self.tree.column('description', width=400, minwidth=200)
        
        # Bind tree selection
        self.tree.bind('<<TreeviewSelect>>', self.on_tree_select)
        self.tree.bind('<Double-1>', self.on_tree_double_click)
        
        # Statistics
        stats_frame = ttk.Frame(nav_frame)
        stats_frame.grid(row=1, column=0, sticky=(tk.W, tk.E), pady=(5, 0))
        
        self.stats_label = ttk.Label(stats_frame, text="Loading documentation...", 
                                   font=('Arial', 9), foreground='blue')
        self.stats_label.pack()
        
    def create_content_panel(self, parent):
        """Create the right content panel for document viewing"""
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
        
        ttk.Button(content_toolbar, text="Open in External Editor", 
                  command=self.open_external).pack(side=tk.LEFT, padx=(0, 5))
        ttk.Button(content_toolbar, text="Copy Path", 
                  command=self.copy_file_path).pack(side=tk.LEFT, padx=(0, 5))
        
        # File info label
        self.file_info_label = ttk.Label(content_toolbar, text="No file selected", 
                                       font=('Arial', 9), foreground='gray')
        self.file_info_label.pack(side=tk.RIGHT)
        
    def create_status_bar(self, parent):
        """Create the bottom status bar"""
        self.status_var = tk.StringVar()
        self.status_var.set("Ready - 47 documentation files available")
        
        status_bar = ttk.Label(parent, textvariable=self.status_var, 
                             relief=tk.SUNKEN, anchor=tk.W, font=('Arial', 9))
        status_bar.grid(row=2, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=(5, 0))
        
    def load_documentation_tree(self):
        """Load the documentation structure into the tree view"""
        try:
            # Clear existing items
            for item in self.tree.get_children():
                self.tree.delete(item)
            
            total_files = 0
            
            # Add each category
            for category, description in self.categories.items():
                category_path = self.docs_root / category
                
                if category_path.exists():
                    files = list(category_path.glob('*.md')) + list(category_path.glob('*.pdf'))
                    file_count = len(files)
                    total_files += file_count
                    
                    # Insert category node
                    category_id = self.tree.insert('', 'end', 
                                                 text=f"{category}/ ({file_count} files)",
                                                 values=(description,),
                                                 tags=('category',))
                    
                    # Add files in this category
                    for file_path in sorted(files):
                        file_size = file_path.stat().st_size
                        size_str = self.format_file_size(file_size)
                        
                        self.tree.insert(category_id, 'end',
                                       text=file_path.name,
                                       values=(f"Size: {size_str}",),
                                       tags=('file',))
            
            # Configure tags
            self.tree.tag_configure('category', background='lightblue', font=('Arial', 10, 'bold'))
            self.tree.tag_configure('file', background='white')
            
            # Expand all categories
            for item in self.tree.get_children():
                self.tree.item(item, open=True)
            
            # Update statistics
            self.stats_label.config(text=f"Total: {total_files} files across 8 categories")
            self.status_var.set(f"Loaded {total_files} documentation files")
            
        except Exception as e:
            messagebox.showerror("Error", f"Failed to load documentation tree: {e}")
            self.status_var.set(f"Error loading documentation: {e}")
    
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
                category = self.tree.item(parent, 'text').split('/')[0]
                file_path = self.docs_root / category / item_text
                self.load_file_content(file_path)
    
    def on_tree_double_click(self, event):
        """Handle double-click on tree items"""
        self.open_external()
    
    def load_file_content(self, file_path: Path):
        """Load and display file content"""
        try:
            self.current_file = file_path
            
            if file_path.suffix.lower() == '.pdf':
                # Handle PDF files
                self.content_text.config(state=tk.NORMAL)
                self.content_text.delete(1.0, tk.END)
                self.content_text.insert(1.0, f"PDF Document: {file_path.name}\n\n")
                self.content_text.insert(tk.END, "This is a PDF file. Click 'Open in External Editor' to view it.\n\n")
                self.content_text.insert(tk.END, f"File path: {file_path}\n")
                self.content_text.insert(tk.END, f"File size: {self.format_file_size(file_path.stat().st_size)}\n")
                self.content_text.config(state=tk.DISABLED)
            else:
                # Handle markdown files
                with open(file_path, 'r', encoding='utf-8') as f:
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
        """Show documents relevant to a specific role"""
        docs = self.role_mappings.get(role, [])
        if not docs:
            messagebox.showinfo("Role Documents", f"No documents configured for role: {role}")
            return
        
        # Create a popup window showing role-specific documents
        popup = tk.Toplevel(self.root)
        popup.title(f"Quick Access - {role}")
        popup.geometry("600x400")
        popup.transient(self.root)
        popup.grab_set()
        
        # Create listbox with documents
        frame = ttk.Frame(popup, padding="10")
        frame.pack(fill=tk.BOTH, expand=True)
        
        ttk.Label(frame, text=f"Recommended documents for {role}:", 
                 font=('Arial', 12, 'bold')).pack(anchor=tk.W, pady=(0, 10))
        
        listbox = tk.Listbox(frame, font=('Arial', 10))
        listbox.pack(fill=tk.BOTH, expand=True, pady=(0, 10))
        
        # Add documents to listbox
        for doc in docs:
            doc_path = self.docs_root / doc
            if doc_path.exists():
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
                full_path = self.docs_root / doc_path
                if full_path.exists():
                    self.load_file_content(full_path)
                    # Select in tree
                    self.select_file_in_tree(doc_path)
                    popup.destroy()
                else:
                    messagebox.showerror("Error", f"Document not found: {doc_path}")
        
        ttk.Button(btn_frame, text="Open Document", command=open_selected).pack(side=tk.LEFT)
        ttk.Button(btn_frame, text="Close", command=popup.destroy).pack(side=tk.RIGHT)
        
        # Bind double-click
        listbox.bind('<Double-1>', lambda e: open_selected())
    
    def select_file_in_tree(self, doc_path: str):
        """Select a specific file in the tree view"""
        parts = doc_path.split('/')
        if len(parts) != 2:
            return
        
        category, filename = parts
        
        # Find category in tree
        for cat_item in self.tree.get_children():
            cat_text = self.tree.item(cat_item, 'text')
            if cat_text.startswith(category):
                # Find file in category
                for file_item in self.tree.get_children(cat_item):
                    file_text = self.tree.item(file_item, 'text')
                    if file_text == filename:
                        self.tree.selection_set(file_item)
                        self.tree.focus(file_item)
                        self.tree.see(file_item)
                        return
    
    def on_search_change(self, *args):
        """Handle search text change (for real-time search)"""
        search_term = self.search_var.get().strip()
        if len(search_term) > 2:  # Start searching after 3 characters
            self.highlight_search_results(search_term)
        else:
            self.clear_search_highlights()
    
    def perform_search(self):
        """Perform comprehensive search across all documents"""
        search_term = self.search_var.get().strip()
        if not search_term:
            messagebox.showwarning("Search", "Please enter a search term")
            return
        
        self.status_var.set(f"Searching for: {search_term}")
        results = []
        
        try:
            # Search through all markdown files
            for category in self.categories.keys():
                category_path = self.docs_root / category
                if category_path.exists():
                    for file_path in category_path.glob('*.md'):
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
                        
                        except Exception as e:
                            continue  # Skip files that can't be read
            
            self.show_search_results(search_term, results)
            
        except Exception as e:
            messagebox.showerror("Search Error", f"Search failed: {e}")
            self.status_var.set("Search failed")
    
    def show_search_results(self, search_term: str, results: List[Tuple[Path, str, str]]):
        """Show search results in a popup window"""
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
        
        results_tree.column('file', width=200)
        results_tree.column('location', width=100)
        results_tree.column('context', width=400)
        
        # Add results
        for file_path, location, context in results:
            relative_path = file_path.relative_to(self.docs_root)
            results_tree.insert('', 'end', values=(str(relative_path), location, context))
        
        results_tree.pack(fill=tk.BOTH, expand=True, pady=(0, 10))
        
        # Scrollbar for results
        results_scroll = ttk.Scrollbar(frame, orient=tk.VERTICAL, command=results_tree.yview)
        results_scroll.pack(side=tk.RIGHT, fill=tk.Y)
        results_tree.configure(yscrollcommand=results_scroll.set)
        
        def open_result():
            selection = results_tree.selection()
            if selection:
                item = results_tree.item(selection[0])
                file_name = item['values'][0]
                file_path = self.docs_root / file_name
                if file_path.exists():
                    self.load_file_content(file_path)
                    self.select_file_in_tree(file_name)
                    results_window.destroy()
        
        # Buttons
        btn_frame = ttk.Frame(frame)
        btn_frame.pack(fill=tk.X)
        
        ttk.Button(btn_frame, text="Open Selected", command=open_result).pack(side=tk.LEFT)
        ttk.Button(btn_frame, text="Close", command=results_window.destroy).pack(side=tk.RIGHT)
        
        results_tree.bind('<Double-1>', lambda e: open_result())
        
        self.status_var.set(f"Found {len(results)} results for: {search_term}")
    
    def highlight_search_results(self, search_term: str):
        """Highlight search results in the tree (simple implementation)"""
        # This is a placeholder for more advanced search highlighting
        pass
    
    def clear_search_highlights(self):
        """Clear search highlights"""
        # This is a placeholder for clearing search highlights
        pass
    
    def open_external(self):
        """Open current file in external editor or viewer"""
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
    # Check if running from docs directory
    current_dir = Path.cwd()
    if current_dir.name != 'docs':
        print("Warning: This browser is designed to run from the docs/ directory")
        print(f"Current directory: {current_dir}")
        print("Please run from the docs/ directory for best results")
    
    # Create and run the application
    root = tk.Tk()
    
    try:
        app = DocumentationBrowser(root)
        
        # Handle window closing
        def on_closing():
            root.destroy()
        
        root.protocol("WM_DELETE_WINDOW", on_closing)
        
        # Start the GUI
        root.mainloop()
        
    except Exception as e:
        messagebox.showerror("Application Error", f"Failed to start documentation browser: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()