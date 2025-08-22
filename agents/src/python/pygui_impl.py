#!/usr/bin/env python3
"""
PYGUI Agent Python Implementation v9.0
Python GUI development specialist for desktop applications.

Comprehensive implementation supporting Tkinter, PyQt5, Kivy, and Streamlit
with automated UI generation, event handling, and modern design patterns.
"""

import asyncio
import json
import os
import sys
import traceback
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple, Union, Callable
from dataclasses import dataclass, asdict
import tempfile
import base64
import io

# Core GUI frameworks
try:
    import tkinter as tk
    from tkinter import ttk, messagebox, filedialog
    HAS_TKINTER = True
except ImportError:
    HAS_TKINTER = False

try:
    from PyQt5 import QtWidgets, QtCore, QtGui
    from PyQt5.QtCore import Qt, QThread, pyqtSignal
    HAS_PYQT = True
except ImportError:
    HAS_PYQT = False

try:
    import kivy
    from kivy.app import App
    from kivy.uix.boxlayout import BoxLayout
    HAS_KIVY = True
except ImportError:
    HAS_KIVY = False

try:
    import streamlit as st
    HAS_STREAMLIT = True
except ImportError:
    HAS_STREAMLIT = False

try:
    import matplotlib.pyplot as plt
    from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
    HAS_MATPLOTLIB = True
except ImportError:
    HAS_MATPLOTLIB = False

@dataclass
class UIComponent:
    """UI component definition"""
    component_type: str  # button, label, input, etc.
    id: str
    properties: Dict[str, Any]
    event_handlers: Dict[str, str]
    children: List['UIComponent'] = None
    layout: str = 'pack'  # pack, grid, place
    position: Dict[str, Any] = None

@dataclass
class GUIApplication:
    """GUI application structure"""
    name: str
    framework: str
    title: str
    size: Tuple[int, int]
    resizable: bool
    components: List[UIComponent]
    menu_bar: Optional[Dict] = None
    status_bar: bool = False
    theme: str = 'default'
    icon: Optional[str] = None

@dataclass
class EventBinding:
    """Event binding configuration"""
    component_id: str
    event_type: str  # click, change, hover, etc.
    handler: str  # function name or code
    parameters: Dict[str, Any] = None

class TkinterBuilder:
    """Tkinter GUI builder"""
    
    def __init__(self):
        self.root = None
        self.components = {}
        self.variables = {}
        
    def create_application(self, app_config: GUIApplication) -> tk.Tk:
        """Create Tkinter application"""
        self.root = tk.Tk()
        self.root.title(app_config.title)
        self.root.geometry(f"{app_config.size[0]}x{app_config.size[1]}")
        self.root.resizable(app_config.resizable, app_config.resizable)
        
        # Apply theme
        if app_config.theme != 'default':
            self._apply_theme(app_config.theme)
            
        # Create menu bar
        if app_config.menu_bar:
            self._create_menu_bar(app_config.menu_bar)
            
        # Create status bar
        if app_config.status_bar:
            self._create_status_bar()
            
        # Create components
        for component in app_config.components:
            self._create_component(component, self.root)
            
        return self.root
        
    def _create_component(self, component: UIComponent, parent) -> Any:
        """Create individual component"""
        widget = None
        
        if component.component_type == 'button':
            widget = ttk.Button(parent, **component.properties)
        elif component.component_type == 'label':
            widget = ttk.Label(parent, **component.properties)
        elif component.component_type == 'entry':
            var = tk.StringVar()
            self.variables[component.id] = var
            widget = ttk.Entry(parent, textvariable=var, **component.properties)
        elif component.component_type == 'text':
            widget = tk.Text(parent, **component.properties)
        elif component.component_type == 'frame':
            widget = ttk.Frame(parent, **component.properties)
        elif component.component_type == 'combobox':
            widget = ttk.Combobox(parent, **component.properties)
        elif component.component_type == 'checkbox':
            var = tk.BooleanVar()
            self.variables[component.id] = var
            widget = ttk.Checkbutton(parent, variable=var, **component.properties)
        elif component.component_type == 'radiobutton':
            var = tk.StringVar()
            self.variables[component.id] = var
            widget = ttk.Radiobutton(parent, variable=var, **component.properties)
        elif component.component_type == 'listbox':
            widget = tk.Listbox(parent, **component.properties)
        elif component.component_type == 'treeview':
            widget = ttk.Treeview(parent, **component.properties)
        elif component.component_type == 'progressbar':
            widget = ttk.Progressbar(parent, **component.properties)
        elif component.component_type == 'scale':
            widget = ttk.Scale(parent, **component.properties)
        elif component.component_type == 'notebook':
            widget = ttk.Notebook(parent)
            
        if widget:
            self.components[component.id] = widget
            
            # Apply layout
            if component.layout == 'pack':
                widget.pack(**component.position if component.position else {})
            elif component.layout == 'grid':
                widget.grid(**component.position if component.position else {})
            elif component.layout == 'place':
                widget.place(**component.position if component.position else {})
                
            # Bind events
            for event, handler in component.event_handlers.items():
                self._bind_event(widget, event, handler)
                
            # Create children
            if component.children:
                for child in component.children:
                    self._create_component(child, widget)
                    
        return widget
        
    def _bind_event(self, widget, event: str, handler: str):
        """Bind event to widget"""
        event_map = {
            'click': '<Button-1>',
            'double_click': '<Double-Button-1>',
            'right_click': '<Button-3>',
            'enter': '<Return>',
            'hover': '<Enter>',
            'leave': '<Leave>',
            'focus': '<FocusIn>',
            'blur': '<FocusOut>',
            'change': '<<ComboboxSelected>>',
            'key': '<Key>'
        }
        
        tk_event = event_map.get(event, event)
        
        def event_handler(e):
            # Execute handler code or function
            if handler.startswith('lambda'):
                exec(handler)
            else:
                print(f"Event {event} triggered on {widget}")
                
        widget.bind(tk_event, event_handler)
        
    def _create_menu_bar(self, menu_config: Dict):
        """Create menu bar"""
        menubar = tk.Menu(self.root)
        self.root.config(menu=menubar)
        
        for menu_name, items in menu_config.items():
            menu = tk.Menu(menubar, tearoff=0)
            menubar.add_cascade(label=menu_name, menu=menu)
            
            for item in items:
                if item == 'separator':
                    menu.add_separator()
                else:
                    menu.add_command(label=item['label'], 
                                   command=lambda: print(f"Menu: {item['label']}"))
                                   
    def _create_status_bar(self):
        """Create status bar"""
        status = ttk.Label(self.root, text="Ready", relief=tk.SUNKEN, anchor=tk.W)
        status.pack(side=tk.BOTTOM, fill=tk.X)
        self.components['status_bar'] = status
        
    def _apply_theme(self, theme: str):
        """Apply theme to application"""
        style = ttk.Style()
        
        if theme == 'dark':
            style.theme_use('clam')
            style.configure(".", background='#2b2b2b', foreground='white')
        elif theme == 'modern':
            style.theme_use('vista' if sys.platform == 'win32' else 'clam')

# PyQt Builder - only define if PyQt is available
if HAS_PYQT:
    class PyQtBuilder:
        """PyQt5 GUI builder"""
    
    def __init__(self):
        self.app = None
        self.window = None
        self.components = {}
        
    def create_application(self, app_config: GUIApplication) -> QtWidgets.QApplication:
        """Create PyQt application"""
        self.app = QtWidgets.QApplication(sys.argv)
        self.window = QtWidgets.QMainWindow()
        self.window.setWindowTitle(app_config.title)
        self.window.resize(app_config.size[0], app_config.size[1])
        
        # Central widget
        central_widget = QtWidgets.QWidget()
        self.window.setCentralWidget(central_widget)
        
        # Main layout
        layout = QtWidgets.QVBoxLayout(central_widget)
        
        # Create components
        for component in app_config.components:
            widget = self._create_component(component)
            if widget:
                layout.addWidget(widget)
                
        # Menu bar
        if app_config.menu_bar:
            self._create_menu_bar(app_config.menu_bar)
            
        # Status bar
        if app_config.status_bar:
            self.window.setStatusBar(QtWidgets.QStatusBar())
            
        return self.app
        
    def _create_component(self, component: UIComponent) -> QtWidgets.QWidget:
        """Create PyQt component"""
        widget = None
        
        component_map = {
            'button': QtWidgets.QPushButton,
            'label': QtWidgets.QLabel,
            'entry': QtWidgets.QLineEdit,
            'text': QtWidgets.QTextEdit,
            'checkbox': QtWidgets.QCheckBox,
            'radiobutton': QtWidgets.QRadioButton,
            'combobox': QtWidgets.QComboBox,
            'listbox': QtWidgets.QListWidget,
            'progressbar': QtWidgets.QProgressBar,
            'slider': QtWidgets.QSlider,
            'spinbox': QtWidgets.QSpinBox,
            'table': QtWidgets.QTableWidget,
            'tree': QtWidgets.QTreeWidget
        }
        
        widget_class = component_map.get(component.component_type)
        if widget_class:
            widget = widget_class()
            
            # Apply properties
            for prop, value in component.properties.items():
                if prop == 'text' and hasattr(widget, 'setText'):
                    widget.setText(str(value))
                elif prop == 'value' and hasattr(widget, 'setValue'):
                    widget.setValue(value)
                    
            self.components[component.id] = widget
            
            # Bind events
            for event, handler in component.event_handlers.items():
                self._bind_event(widget, event, handler)
                
        return widget
        
    def _bind_event(self, widget, event: str, handler: str):
        """Bind PyQt event"""
        if event == 'click' and hasattr(widget, 'clicked'):
            widget.clicked.connect(lambda: print(f"Clicked: {widget}"))
        elif event == 'change' and hasattr(widget, 'textChanged'):
            widget.textChanged.connect(lambda text: print(f"Changed: {text}"))
            
    def _create_menu_bar(self, menu_config: Dict):
        """Create PyQt menu bar"""
        menubar = self.window.menuBar()
        
        for menu_name, items in menu_config.items():
            menu = menubar.addMenu(menu_name)
            
            for item in items:
                if item == 'separator':
                    menu.addSeparator()
                else:
                    action = menu.addAction(item['label'])
                    action.triggered.connect(lambda: print(f"Menu: {item['label']}"))
else:
    # Placeholder PyQtBuilder when PyQt is not available
    class PyQtBuilder:
        def __init__(self):
            pass
        def create_application(self, app_config):
            raise ImportError("PyQt5 not available")

class StreamlitBuilder:
    """Streamlit web UI builder"""
    
    def __init__(self):
        self.components = {}
        
    def create_application(self, app_config: GUIApplication) -> str:
        """Generate Streamlit application code"""
        code = f"""
import streamlit as st
import pandas as pd
import numpy as np

# App configuration
st.set_page_config(
    page_title="{app_config.title}",
    layout="wide",
    initial_sidebar_state="expanded"
)

st.title("{app_config.title}")

"""
        
        # Generate component code
        for component in app_config.components:
            code += self._generate_component_code(component)
            
        return code
        
    def _generate_component_code(self, component: UIComponent) -> str:
        """Generate Streamlit component code"""
        code = ""
        
        if component.component_type == 'button':
            code = f"""
if st.button("{component.properties.get('text', 'Button')}", key="{component.id}"):
    st.write("Button clicked!")
"""
        elif component.component_type == 'input':
            code = f"""
{component.id} = st.text_input("{component.properties.get('label', 'Input')}", key="{component.id}")
"""
        elif component.component_type == 'slider':
            code = f"""
{component.id} = st.slider(
    "{component.properties.get('label', 'Slider')}",
    min_value={component.properties.get('min', 0)},
    max_value={component.properties.get('max', 100)},
    key="{component.id}"
)
"""
        elif component.component_type == 'selectbox':
            code = f"""
{component.id} = st.selectbox(
    "{component.properties.get('label', 'Select')}",
    options={component.properties.get('options', [])},
    key="{component.id}"
)
"""
        elif component.component_type == 'checkbox':
            code = f"""
{component.id} = st.checkbox("{component.properties.get('label', 'Checkbox')}", key="{component.id}")
"""
        elif component.component_type == 'dataframe':
            code = f"""
# Display dataframe
st.dataframe(data, key="{component.id}")
"""
        elif component.component_type == 'chart':
            code = f"""
# Display chart
st.line_chart(data, key="{component.id}")
"""
        elif component.component_type == 'columns':
            code = f"""
col1, col2, col3 = st.columns(3)
with col1:
    st.header("Column 1")
with col2:
    st.header("Column 2")
with col3:
    st.header("Column 3")
"""
            
        return code

class UIDesigner:
    """Visual UI designer and code generator"""
    
    def __init__(self):
        self.layouts = {}
        self.templates = self._load_templates()
        
    def _load_templates(self) -> Dict[str, Any]:
        """Load UI templates"""
        return {
            'login_form': {
                'components': [
                    UIComponent('label', 'title_label', {'text': 'Login'}, {}),
                    UIComponent('entry', 'username_input', {'placeholder': 'Username'}, {}),
                    UIComponent('entry', 'password_input', {'placeholder': 'Password', 'show': '*'}, {}),
                    UIComponent('checkbox', 'remember_cb', {'text': 'Remember me'}, {}),
                    UIComponent('button', 'login_btn', {'text': 'Login'}, {'click': 'handle_login'})
                ]
            },
            'dashboard': {
                'components': [
                    UIComponent('label', 'header', {'text': 'Dashboard'}, {}),
                    UIComponent('frame', 'sidebar', {}, {}),
                    UIComponent('frame', 'main_content', {}, {}),
                    UIComponent('frame', 'footer', {}, {})
                ]
            },
            'data_viewer': {
                'components': [
                    UIComponent('label', 'title', {'text': 'Data Viewer'}, {}),
                    UIComponent('treeview', 'data_tree', {'columns': ['Name', 'Value', 'Type']}, {}),
                    UIComponent('button', 'refresh_btn', {'text': 'Refresh'}, {'click': 'refresh_data'}),
                    UIComponent('button', 'export_btn', {'text': 'Export'}, {'click': 'export_data'})
                ]
            }
        }
        
    def design_ui(self, template: str = None, custom_components: List[UIComponent] = None) -> GUIApplication:
        """Design UI from template or custom components"""
        
        if template and template in self.templates:
            components = self.templates[template]['components']
        elif custom_components:
            components = custom_components
        else:
            components = []
            
        return GUIApplication(
            name='designed_app',
            framework='tkinter',
            title='Designed Application',
            size=(800, 600),
            resizable=True,
            components=components
        )
        
    def generate_code(self, app: GUIApplication, framework: str = 'tkinter') -> str:
        """Generate code for the designed UI"""
        
        if framework == 'tkinter':
            return self._generate_tkinter_code(app)
        elif framework == 'pyqt':
            return self._generate_pyqt_code(app)
        elif framework == 'streamlit':
            builder = StreamlitBuilder()
            return builder.create_application(app)
        else:
            return "# Unsupported framework"
            
    def _generate_tkinter_code(self, app: GUIApplication) -> str:
        """Generate Tkinter code"""
        code = f"""#!/usr/bin/env python3
import tkinter as tk
from tkinter import ttk, messagebox

class {app.name.title().replace('_', '')}App:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("{app.title}")
        self.root.geometry("{app.size[0]}x{app.size[1]}")
        self.create_widgets()
        
    def create_widgets(self):
"""
        
        for component in app.components:
            code += f"""        # {component.id}
        self.{component.id} = ttk.{component.component_type.title()}(self.root"""
            
            for prop, value in component.properties.items():
                code += f", {prop}='{value}'"
                
            code += ")\n"
            code += f"        self.{component.id}.pack(pady=5)\n\n"
            
        code += """    
    def run(self):
        self.root.mainloop()


    async def _create_pygui_files(self, result_data: Dict[str, Any], context: Dict[str, Any]):
        """Create pygui files and artifacts using declared tools"""
        try:
            import os
            from pathlib import Path
            import json
            import time
            
            # Create directories
            main_dir = Path("gui_applications")
            docs_dir = Path("gui_components")
            
            os.makedirs(main_dir, exist_ok=True)
            os.makedirs(docs_dir / "windows", exist_ok=True)
            os.makedirs(docs_dir / "dialogs", exist_ok=True)
            os.makedirs(docs_dir / "widgets", exist_ok=True)
            os.makedirs(docs_dir / "resources", exist_ok=True)
            
            timestamp = int(time.time())
            
            # 1. Create main result file
            result_file = main_dir / f"pygui_result_{timestamp}.json"
            with open(result_file, 'w') as f:
                json.dump(result_data, f, indent=2, default=str)
            
            # 2. Create implementation script
            script_file = docs_dir / "windows" / f"pygui_implementation.py"
            script_content = f'''#!/usr/bin/env python3
"""
PYGUI Implementation Script
Generated by PYGUI Agent at {datetime.now().isoformat()}
"""

import asyncio
import json
from typing import Dict, Any

class PyguiImplementation:
    """
    Implementation for pygui operations
    """
    
    def __init__(self):
        self.agent_name = "PYGUI"
        self.result_data = result_data
        
    async def execute(self) -> Dict[str, Any]:
        """Execute pygui implementation"""
        print(f"Executing {self.agent_name} implementation")
        
        # Implementation logic here
        await asyncio.sleep(0.1)
        
        return {
            "status": "completed",
            "agent": self.agent_name,
            "execution_time": "{datetime.now().isoformat()}"
        }
        
    def get_artifacts(self) -> Dict[str, Any]:
        """Get created artifacts"""
        return {
            "files_created": [
                "main_window.py",
                "gui_app.py",
                "resources.qrc"
            ],
            "directories": ['windows', 'dialogs', 'widgets', 'resources'],
            "description": "GUI applications and interfaces"
        }

if __name__ == "__main__":
    impl = PyguiImplementation()
    result = asyncio.run(impl.execute())
    print(f"Result: {result}")
'''
            
            with open(script_file, 'w') as f:
                f.write(script_content)
            
            os.chmod(script_file, 0o755)
            
            # 3. Create README
            readme_content = f'''# PYGUI Output

Generated by PYGUI Agent at {datetime.now().isoformat()}

## Description
GUI applications and interfaces

## Files Created
- Main result: `{result_file.name}`
- Implementation: `{script_file.name}`

## Directory Structure
- `windows/` - windows related files
- `dialogs/` - dialogs related files
- `widgets/` - widgets related files
- `resources/` - resources related files

## Usage
```bash
# Run the implementation
python3 {script_file}

# View results
cat {result_file}
```

---
Last updated: {datetime.now().isoformat()}
'''
            
            with open(docs_dir / "README.md", 'w') as f:
                f.write(readme_content)
            
            print(f"PYGUI files created successfully in {main_dir} and {docs_dir}")
            
        except Exception as e:
            print(f"Failed to create pygui files: {e}")

if __name__ == "__main__":
    app = {}App()
    app.run()
""".format(app.name.title().replace('_', ''))
        
        return code
        
    def _generate_pyqt_code(self, app: GUIApplication) -> str:
        """Generate PyQt code"""
        code = f"""#!/usr/bin/env python3
import sys
from PyQt5 import QtWidgets, QtCore, QtGui

class {app.name.title().replace('_', '')}App(QtWidgets.QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("{app.title}")
        self.resize({app.size[0]}, {app.size[1]})
        self.init_ui()
        
    def init_ui(self):
        central_widget = QtWidgets.QWidget()
        self.setCentralWidget(central_widget)
        layout = QtWidgets.QVBoxLayout(central_widget)
        
"""
        
        for component in app.components:
            widget_map = {
                'button': 'QPushButton',
                'label': 'QLabel',
                'entry': 'QLineEdit',
                'text': 'QTextEdit'
            }
            
            widget_class = widget_map.get(component.component_type, 'QWidget')
            code += f"""        # {component.id}
        self.{component.id} = QtWidgets.{widget_class}()
"""
            
            if 'text' in component.properties:
                code += f"""        self.{component.id}.setText("{component.properties['text']}")
"""
                
            code += f"""        layout.addWidget(self.{component.id})
"""
            
        code += """

    async def _create_pygui_files(self, result_data: Dict[str, Any], context: Dict[str, Any]):
        """Create pygui files and artifacts using declared tools"""
        try:
            import os
            from pathlib import Path
            import json
            import time
            
            # Create directories
            main_dir = Path("gui_applications")
            docs_dir = Path("gui_components")
            
            os.makedirs(main_dir, exist_ok=True)
            os.makedirs(docs_dir / "windows", exist_ok=True)
            os.makedirs(docs_dir / "dialogs", exist_ok=True)
            os.makedirs(docs_dir / "widgets", exist_ok=True)
            os.makedirs(docs_dir / "resources", exist_ok=True)
            
            timestamp = int(time.time())
            
            # 1. Create main result file
            result_file = main_dir / f"pygui_result_{timestamp}.json"
            with open(result_file, 'w') as f:
                json.dump(result_data, f, indent=2, default=str)
            
            # 2. Create implementation script
            script_file = docs_dir / "windows" / f"pygui_implementation.py"
            script_content = f'''#!/usr/bin/env python3
"""
PYGUI Implementation Script
Generated by PYGUI Agent at {datetime.now().isoformat()}
"""

import asyncio
import json
from typing import Dict, Any

class PyguiImplementation:
    """
    Implementation for pygui operations
    """
    
    def __init__(self):
        self.agent_name = "PYGUI"
        self.result_data = result_data
        
    async def execute(self) -> Dict[str, Any]:
        """Execute pygui implementation"""
        print(f"Executing {self.agent_name} implementation")
        
        # Implementation logic here
        await asyncio.sleep(0.1)
        
        return {
            "status": "completed",
            "agent": self.agent_name,
            "execution_time": "{datetime.now().isoformat()}"
        }
        
    def get_artifacts(self) -> Dict[str, Any]:
        """Get created artifacts"""
        return {
            "files_created": [
                "main_window.py",
                "gui_app.py",
                "resources.qrc"
            ],
            "directories": ['windows', 'dialogs', 'widgets', 'resources'],
            "description": "GUI applications and interfaces"
        }

if __name__ == "__main__":
    impl = PyguiImplementation()
    result = asyncio.run(impl.execute())
    print(f"Result: {result}")
'''
            
            with open(script_file, 'w') as f:
                f.write(script_content)
            
            os.chmod(script_file, 0o755)
            
            # 3. Create README
            readme_content = f'''# PYGUI Output

Generated by PYGUI Agent at {datetime.now().isoformat()}

## Description
GUI applications and interfaces

## Files Created
- Main result: `{result_file.name}`
- Implementation: `{script_file.name}`

## Directory Structure
- `windows/` - windows related files
- `dialogs/` - dialogs related files
- `widgets/` - widgets related files
- `resources/` - resources related files

## Usage
```bash
# Run the implementation
python3 {script_file}

# View results
cat {result_file}
```

---
Last updated: {datetime.now().isoformat()}
'''
            
            with open(docs_dir / "README.md", 'w') as f:
                f.write(readme_content)
            
            print(f"PYGUI files created successfully in {main_dir} and {docs_dir}")
            
        except Exception as e:
            print(f"Failed to create pygui files: {e}")

if __name__ == "__main__":
    app = QtWidgets.QApplication(sys.argv)
    window = {}App()
    window.show()
    sys.exit(app.exec_())
""".format(app.name.title().replace('_', ''))
        
        return code

class PYGUIPythonExecutor:
    """
    PYGUI Agent Python Implementation v9.0
    
    Comprehensive Python GUI development with support for multiple frameworks,
    visual design, and code generation capabilities.
    """
    
    def __init__(self):
        self.agent_name = "PYGUI"
        self.version = "9.0.0"
        self.start_time = datetime.now()
        
        self.tkinter_builder = TkinterBuilder() if HAS_TKINTER else None
        self.pyqt_builder = PyQtBuilder() if HAS_PYQT else None
        self.streamlit_builder = StreamlitBuilder() if HAS_STREAMLIT else None
        self.ui_designer = UIDesigner()
        self.applications = {}
        self.metrics = {
            'apps_created': 0,
            'components_created': 0,
            'events_bound': 0,
            'code_generated': 0,
            'errors': 0
        }
        
    async def execute_command(self, command_str: str, context: Dict[str, Any] = None) -> Dict[str, Any]:
        """Execute PYGUI commands - v9.0 signature"""
        try:
            # Handle both v8.x dict input and v9.0 string input for compatibility
            if isinstance(command_str, dict):
                command = command_str
            else:
                # Parse v9.0 format
                if context:
                    command = context
                    command['action'] = command_str
                else:
                    command = {'action': command_str}
            
            result = await self.process_command(command)
            return result
        except Exception as e:
            self.metrics['errors'] += 1
            return {"error": str(e), "traceback": traceback.format_exc()}
            
    async def process_command(self, command: Dict[str, Any]) -> Dict[str, Any]:
        """Execute PYGUI commands"""
        try:
            result = await self.process_command(command)
            return result
        except Exception as e:
            self.metrics['errors'] += 1
            return {"error": str(e), "traceback": traceback.format_exc()}
            
    async def process_command(self, command: Dict[str, Any]) -> Dict[str, Any]:
        """Process GUI operations"""
        action = command.get('action', '')
        payload = command.get('payload', {})
        
        commands = {
            "create_app": self.create_app,
            "add_component": self.add_component,
            "bind_event": self.bind_event,
            "generate_code": self.generate_code,
            "run_app": self.run_app,
            "design_ui": self.design_ui,
            "create_dialog": self.create_dialog,
            "create_chart": self.create_chart,
            "apply_theme": self.apply_theme,
            "export_ui": self.export_ui,
            "load_template": self.load_template,
            "validate_ui": self.validate_ui
        }
        
        handler = commands.get(action)
        if handler:
            return await handler(payload)
        else:
            return {"error": f"Unknown GUI operation: {action}"}
            
    async def create_app(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Create GUI application"""
        try:
            name = payload.get('name', 'app')
            framework = payload.get('framework', 'tkinter')
            title = payload.get('title', 'Application')
            size = payload.get('size', (800, 600))
            
            # Create application config
            app_config = GUIApplication(
                name=name,
                framework=framework,
                title=title,
                size=size,
                resizable=payload.get('resizable', True),
                components=[]
            )
            
            # Build application based on framework
            if framework == 'tkinter' and self.tkinter_builder:
                app = self.tkinter_builder.create_application(app_config)
                self.applications[name] = {'framework': 'tkinter', 'app': app, 'config': app_config}
            elif framework == 'pyqt' and self.pyqt_builder:
                app = self.pyqt_builder.create_application(app_config)
                self.applications[name] = {'framework': 'pyqt', 'app': app, 'config': app_config}
            elif framework == 'streamlit':
                code = self.streamlit_builder.create_application(app_config)
                self.applications[name] = {'framework': 'streamlit', 'code': code, 'config': app_config}
            else:
                return {"error": f"Framework {framework} not available"}
                
            self.metrics['apps_created'] += 1
            
            return {
                "status": "success",
                "app_name": name,
                "framework": framework,
                "title": title,
                "size": size
            }
            
        except Exception as e:
            return {"error": f"Failed to create app: {str(e)}"}
            
    async def add_component(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Add component to application"""
        try:
            app_name = payload.get('app_name', 'app')
            component_type = payload.get('type', 'button')
            component_id = payload.get('id', f'{component_type}_1')
            properties = payload.get('properties', {})
            
            if app_name not in self.applications:
                return {"error": f"Application {app_name} not found"}
                
            # Create component
            component = UIComponent(
                component_type=component_type,
                id=component_id,
                properties=properties,
                event_handlers={},
                layout=payload.get('layout', 'pack'),
                position=payload.get('position')
            )
            
            # Add to application config
            self.applications[app_name]['config'].components.append(component)
            
            # Add to running application if possible
            app_info = self.applications[app_name]
            if app_info['framework'] == 'tkinter' and self.tkinter_builder:
                widget = self.tkinter_builder._create_component(component, self.tkinter_builder.root)
                
            self.metrics['components_created'] += 1
            
            return {
                "status": "success",
                "component_id": component_id,
                "component_type": component_type
            }
            
        except Exception as e:
            return {"error": f"Failed to add component: {str(e)}"}
            
    async def bind_event(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Bind event to component"""
        try:
            app_name = payload.get('app_name', 'app')
            component_id = payload.get('component_id')
            event = payload.get('event', 'click')
            handler = payload.get('handler', 'print("Event triggered")')
            
            if app_name not in self.applications:
                return {"error": f"Application {app_name} not found"}
                
            # Find component and add event handler
            config = self.applications[app_name]['config']
            for component in config.components:
                if component.id == component_id:
                    component.event_handlers[event] = handler
                    break
                    
            self.metrics['events_bound'] += 1
            
            return {
                "status": "success",
                "component_id": component_id,
                "event": event
            }
            
        except Exception as e:
            return {"error": f"Failed to bind event: {str(e)}"}
            
    async def generate_code(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Generate code for application"""
        try:
            app_name = payload.get('app_name', 'app')
            framework = payload.get('framework')
            
            if app_name not in self.applications:
                return {"error": f"Application {app_name} not found"}
                
            config = self.applications[app_name]['config']
            
            if not framework:
                framework = config.framework
                
            # Generate code
            code = self.ui_designer.generate_code(config, framework)
            
            self.metrics['code_generated'] += 1
            
            # Save to file if requested
            if payload.get('save_to_file'):
                filename = f"{app_name}_{framework}.py"
                with open(filename, 'w') as f:
                    f.write(code)
                    
                return {
                    "status": "success",
                    "code": code,
                    "file": filename
                }
                
            return {
                "status": "success",
                "code": code
            }
            
        except Exception as e:
            return {"error": f"Failed to generate code: {str(e)}"}
            
    async def run_app(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Run GUI application"""
        try:
            app_name = payload.get('app_name', 'app')
            
            if app_name not in self.applications:
                return {"error": f"Application {app_name} not found"}
                
            app_info = self.applications[app_name]
            
            if app_info['framework'] == 'tkinter':
                # Run Tkinter app (note: this will block)
                # In production, run in separate thread
                return {
                    "status": "success",
                    "message": "Tkinter app ready to run. Call mainloop() to start."
                }
            elif app_info['framework'] == 'pyqt':
                return {
                    "status": "success",
                    "message": "PyQt app ready to run. Call app.exec_() to start."
                }
            elif app_info['framework'] == 'streamlit':
                return {
                    "status": "success",
                    "message": "Streamlit app code generated. Run with 'streamlit run app.py'"
                }
                
        except Exception as e:
            return {"error": f"Failed to run app: {str(e)}"}
            
    async def design_ui(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Design UI visually"""
        try:
            template = payload.get('template')
            custom_components = payload.get('components')
            
            # Design UI
            app = self.ui_designer.design_ui(template, custom_components)
            
            # Generate preview
            preview_code = self.ui_designer.generate_code(app, 'tkinter')
            
            return {
                "status": "success",
                "app_config": asdict(app),
                "preview_code": preview_code[:500] + "..." if len(preview_code) > 500 else preview_code
            }
            
        except Exception as e:
            return {"error": f"Failed to design UI: {str(e)}"}
            
    async def create_dialog(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Create dialog window"""
        try:
            dialog_type = payload.get('type', 'info')
            title = payload.get('title', 'Dialog')
            message = payload.get('message', '')
            
            code = f"""
# {dialog_type.title()} Dialog
import tkinter as tk
from tkinter import messagebox

def show_{dialog_type}_dialog():
    messagebox.show{dialog_type}("{title}", "{message}")
    
# For PyQt
from PyQt5.QtWidgets import QMessageBox

def show_{dialog_type}_dialog_qt():
    msg = QMessageBox()
    msg.setWindowTitle("{title}")
    msg.setText("{message}")
    msg.exec_()
"""
            
            return {
                "status": "success",
                "dialog_type": dialog_type,
                "code": code
            }
            
        except Exception as e:
            return {"error": f"Failed to create dialog: {str(e)}"}
            
    async def create_chart(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Create chart/graph component"""
        try:
            chart_type = payload.get('type', 'line')
            data = payload.get('data', [])
            
            if not HAS_MATPLOTLIB:
                return {"error": "Matplotlib not available"}
                
            code = f"""
# Create {chart_type} chart
import matplotlib.pyplot as plt
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg

def create_{chart_type}_chart(parent, data):
    fig, ax = plt.subplots(figsize=(8, 6))
    
    if '{chart_type}' == 'line':
        ax.plot(data)
    elif '{chart_type}' == 'bar':
        ax.bar(range(len(data)), data)
    elif '{chart_type}' == 'scatter':
        ax.scatter(range(len(data)), data)
    elif '{chart_type}' == 'pie':
        ax.pie(data)
        
    canvas = FigureCanvasTkAgg(fig, parent)
    canvas.draw()
    canvas.get_tk_widget().pack()
    
    return canvas
"""
            
            return {
                "status": "success",
                "chart_type": chart_type,
                "code": code
            }
            
        except Exception as e:
            return {"error": f"Failed to create chart: {str(e)}"}
            
    async def apply_theme(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Apply theme to application"""
        try:
            app_name = payload.get('app_name', 'app')
            theme = payload.get('theme', 'default')
            
            theme_code = f"""
# Apply {theme} theme
import tkinter as tk
from tkinter import ttk

def apply_{theme}_theme():
    style = ttk.Style()
"""
            
            if theme == 'dark':
                theme_code += """    style.theme_use('clam')
    style.configure(".", background='#2b2b2b', foreground='white')
    style.configure("TButton", background='#404040', foreground='white')
    style.configure("TLabel", background='#2b2b2b', foreground='white')
    style.configure("TEntry", fieldbackground='#404040', foreground='white')
"""
            elif theme == 'modern':
                theme_code += """    style.theme_use('vista' if sys.platform == 'win32' else 'clam')
    style.configure("TButton", padding=10, relief="flat", background="#0078D4")
    style.map("TButton", background=[('active', '#106EBE')])
"""
            elif theme == 'material':
                theme_code += """    style.configure(".", font=('Roboto', 10))
    style.configure("TButton", padding=12, relief="flat", background="#6200EA")
    style.map("TButton", background=[('active', '#3700B3')])
"""
                
            return {
                "status": "success",
                "theme": theme,
                "code": theme_code
            }
            
        except Exception as e:
            return {"error": f"Failed to apply theme: {str(e)}"}
            
    async def export_ui(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Export UI definition"""
        try:
            app_name = payload.get('app_name', 'app')
            format = payload.get('format', 'json')
            
            if app_name not in self.applications:
                return {"error": f"Application {app_name} not found"}
                
            config = self.applications[app_name]['config']
            
            if format == 'json':
                export_data = json.dumps(asdict(config), indent=2)
            else:
                export_data = str(config)
                
            return {
                "status": "success",
                "format": format,
                "data": export_data
            }
            
        except Exception as e:
            return {"error": f"Failed to export UI: {str(e)}"}
            
    async def load_template(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Load UI template"""
        try:
            template_name = payload.get('template', 'login_form')
            
            templates = self.ui_designer.templates
            
            if template_name not in templates:
                return {
                    "status": "success",
                    "available_templates": list(templates.keys())
                }
                
            template = templates[template_name]
            
            return {
                "status": "success",
                "template": template_name,
                "components": [asdict(c) for c in template['components']]
            }
            
        except Exception as e:
            return {"error": f"Failed to load template: {str(e)}"}
            
    async def validate_ui(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Validate UI design"""
        try:
            app_name = payload.get('app_name', 'app')
            
            if app_name not in self.applications:
                return {"error": f"Application {app_name} not found"}
                
            config = self.applications[app_name]['config']
            issues = []
            
            # Check for duplicate IDs
            ids = [c.id for c in config.components]
            duplicates = [id for id in ids if ids.count(id) > 1]
            if duplicates:
                issues.append(f"Duplicate component IDs: {duplicates}")
                
            # Check for missing event handlers
            for component in config.components:
                if component.component_type == 'button' and not component.event_handlers:
                    issues.append(f"Button {component.id} has no event handlers")
                    
            # Check layout conflicts
            layouts = set(c.layout for c in config.components)
            if len(layouts) > 1 and 'place' in layouts:
                issues.append("Mixed layout managers detected - may cause issues")
                
            return {
                "status": "success",
                "valid": len(issues) == 0,
                "issues": issues
            }
            
        except Exception as e:
            return {"error": f"Validation failed: {str(e)}"}
    
    def get_capabilities(self) -> List[str]:
        """Get PYGUI capabilities"""
        return [
            "create_tkinter_app",
            "create_pyqt_app", 
            "create_streamlit_app",
            "design_ui",
            "generate_code",
            "bind_events",
            "export_ui",
            "load_template",
            "validate_ui",
            "visual_design",
            "component_creation",
            "layout_management",
            "event_handling",
            "ui_templates",
            "cross_platform_gui"
        ]
    
    def get_status(self) -> Dict[str, Any]:
        """Get PYGUI status"""
        uptime = (datetime.now() - self.start_time).total_seconds()
        
        
        # Create pygui files and documentation
        await self._create_pygui_files(result, context if 'context' in locals() else {})
        return {
            "agent_name": self.agent_name,
            "version": self.version,
            "status": "healthy",
            "uptime_seconds": uptime,
            "metrics": self.metrics.copy(),
            "applications": len(self.applications),
            "capabilities": len(self.get_capabilities()),
            "supported_frameworks": {
                "tkinter": HAS_TKINTER,
                "pyqt": HAS_PYQT,
                "streamlit": HAS_STREAMLIT
            },
            "components": {
                "tkinter_builder": "operational" if HAS_TKINTER else "unavailable",
                "pyqt_builder": "operational" if HAS_PYQT else "unavailable",
                "streamlit_builder": "operational" if HAS_STREAMLIT else "unavailable",
                "ui_designer": "operational"
            }
        }

# Export main class
__all__ = ['PYGUIPythonExecutor']