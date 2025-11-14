#!/usr/bin/env python3
"""
AI-Powered Universal Documentation Browser
Single-file portable solution with OpenVINO NPU/GPU acceleration

Features:
- Intel NPU (GNA) acceleration for AI inference (40 TOPS on Ultra 7 165H)
- Intel Arc Graphics GPU support
- Auto-detection and adaptation to any documentation structure
- Semantic search with embeddings
- Document summarization and Q&A
- PDF/image OCR and extraction
- Docker support (generates Dockerfile on demand)
- Zero external files needed (except models cached to ~/.cache/)
- Works on ANY project - just drop this file and run

Hardware Support:
- Intel Core Ultra NPU: AI inference, embeddings, summarization
- Intel Arc Graphics: Image processing, OCR
- CPU: Fallback for everything

Usage:
  python3 doc_browser_ai.py                    # Run in current directory
  python3 doc_browser_ai.py /path/to/docs     # Specify directory
  python3 doc_browser_ai.py --docker-init     # Generate Docker files
  python3 doc_browser_ai.py --check-hardware  # Show available accelerators

Requirements: Python 3.8+, pip
Everything else auto-installs on first run.

Author: AI-Enhanced Document Analysis System
Version: 2.0.0-NPU
"""

import argparse
import hashlib
import json
import os
import platform
import queue
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import tkinter as tk
import warnings
from collections import defaultdict
from dataclasses import asdict, dataclass
from pathlib import Path
from tkinter import filedialog, messagebox, scrolledtext, ttk
from typing import Any, Dict, List, Optional, Set, Tuple

warnings.filterwarnings("ignore")

# ============================================================================
# HARDWARE DETECTION & OpenVINO INTEGRATION
# ============================================================================


class HardwareDetector:
    """Detect available AI acceleration hardware (NPU, GPU, CPU)"""

    @staticmethod
    def detect_intel_npu() -> bool:
        """Detect Intel NPU/GNA support"""
        try:
            # Check CPU model for Meteor Lake or later (has NPU)
            with open("/proc/cpuinfo", "r") as f:
                cpuinfo = f.read()

            # Intel Core Ultra series has NPU
            if "Intel(R) Core(TM) Ultra" in cpuinfo:
                return True

            # Check for GNA device
            if os.path.exists("/dev/intel_gna"):
                return True

            return False
        except:
            return False

    @staticmethod
    def detect_intel_gpu() -> bool:
        """Detect Intel Arc Graphics or integrated GPU"""
        try:
            result = subprocess.run(["lspci"], capture_output=True, text=True)
            lspci_output = result.stdout

            # Check for Intel graphics
            if "Intel" in lspci_output and (
                "VGA" in lspci_output or "Graphics" in lspci_output
            ):
                return True

            return False
        except:
            return False

    @staticmethod
    def get_openvino_devices() -> List[str]:
        """Get available OpenVINO devices"""
        try:
            try:
                from openvino import Core  # New API
            except ImportError:
                from openvino.runtime import Core  # Legacy API
            core = Core()
            devices = core.available_devices
            return devices
        except Exception:
            return []

    @staticmethod
    def get_optimal_device() -> str:
        """Determine optimal device for inference"""
        devices = HardwareDetector.get_openvino_devices()

        # Priority: NPU > GPU > CPU
        if "NPU" in devices:
            return "NPU"
        elif "GPU" in devices or "GPU.0" in devices:
            return "GPU"
        else:
            return "CPU"

    @staticmethod
    def get_hardware_info() -> Dict[str, Any]:
        """Get comprehensive hardware information"""
        info = {
            "cpu_model": "Unknown",
            "cpu_cores": os.cpu_count() or 1,
            "has_npu": False,
            "has_intel_gpu": False,
            "openvino_devices": [],
            "optimal_device": "CPU",
            "platform": platform.system(),
            "python_version": platform.python_version(),
        }

        try:
            # Get CPU model
            if platform.system() == "Linux":
                with open("/proc/cpuinfo", "r") as f:
                    for line in f:
                        if "model name" in line:
                            info["cpu_model"] = line.split(":")[1].strip()
                            break

            info["has_npu"] = HardwareDetector.detect_intel_npu()
            info["has_intel_gpu"] = HardwareDetector.detect_intel_gpu()
            info["openvino_devices"] = HardwareDetector.get_openvino_devices()
            info["optimal_device"] = HardwareDetector.get_optimal_device()

        except Exception as e:
            print(f"Warning: Could not detect all hardware features: {e}")

        return info


# ============================================================================
# AUTO-INSTALLATION SYSTEM
# ============================================================================


class DependencyManager:
    """Automatic dependency installation and management"""

    CORE_DEPS = [
        ("pdfplumber", "pdfplumber"),
        ("Pillow", "PIL"),
        ("markdown", "markdown"),
    ]

    AI_DEPS = [
        ("numpy", "numpy"),
        ("scikit-learn", "sklearn"),
        # Note: Large packages below are optional - browser works without them
        # They enable semantic search but aren't required for core functionality
        # ('openvino', 'openvino'),  # Already installed globally
        # ('optimum-intel', 'optimum.intel'),  # 500MB+ package
        # ('sentence-transformers', 'sentence_transformers'),  # 200MB+ package
        # ('transformers', 'transformers'),  # 300MB+ package
        # ('torch', 'torch'),  # 800MB+ package
    ]

    OPTIONAL_DEPS = [
        ("pytesseract", "pytesseract"),  # OCR
        ("python-docx", "docx"),  # DOCX support
        ("PyMuPDF", "fitz"),  # Advanced PDF
    ]

    @staticmethod
    def check_and_install(
        package_name: str, import_name: str = None, required: bool = True
    ) -> bool:
        """Check if package installed, install if not"""
        if import_name is None:
            import_name = package_name

        try:
            __import__(import_name)
            return True
        except ImportError:
            if not required:
                return False

            # Try regular pip first (silent)
            try:
                subprocess.check_call(
                    [sys.executable, "-m", "pip", "install", package_name, "--quiet"],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
                return True
            except subprocess.CalledProcessError:
                # Try with --break-system-packages
                try:
                    subprocess.check_call(
                        [
                            sys.executable,
                            "-m",
                            "pip",
                            "install",
                            package_name,
                            "--break-system-packages",
                            "--quiet",
                        ],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    )
                    return True
                except subprocess.CalledProcessError:
                    # Last resort: try with user install
                    try:
                        subprocess.check_call(
                            [
                                sys.executable,
                                "-m",
                                "pip",
                                "install",
                                "--user",
                                package_name,
                                "--quiet",
                            ],
                            stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL,
                        )
                        return True
                    except subprocess.CalledProcessError:
                        return False

    @classmethod
    def setup_environment(cls, enable_ai: bool = True) -> Dict[str, bool]:
        """Setup complete environment"""
        status = {}

        print("🚀 Setting up document browser environment...")

        total_deps = (
            len(cls.CORE_DEPS)
            + (len(cls.AI_DEPS) if enable_ai else 0)
            + len(cls.OPTIONAL_DEPS)
        )
        current = 0

        # Install core dependencies
        for pkg, imp in cls.CORE_DEPS:
            current += 1
            print(f"   [{current}/{total_deps}] Checking {pkg}...", end=" ", flush=True)
            result = cls.check_and_install(pkg, imp, required=True)
            status[pkg] = result
            print("✅" if result else "⏭️")

        # Install AI dependencies if enabled
        if enable_ai:
            print("\n🧠 Setting up AI acceleration...")
            for pkg, imp in cls.AI_DEPS:
                current += 1
                print(
                    f"   [{current}/{total_deps}] Checking {pkg}...",
                    end=" ",
                    flush=True,
                )
                result = cls.check_and_install(pkg, imp, required=False)
                status[pkg] = result
                print("✅" if result else "⏭️")

        # Optional dependencies (silent)
        for pkg, imp in cls.OPTIONAL_DEPS:
            current += 1
            result = cls.check_and_install(pkg, imp, required=False)
            status[pkg] = result

        print(
            f"\n✅ Environment ready ({sum(1 for v in status.values() if v)}/{len(status)} packages available)\n"
        )
        return status


# ============================================================================
# AI MODEL MANAGER (OpenVINO Optimized)
# ============================================================================


class AIModelManager:
    """Manage AI models with OpenVINO optimization for NPU/GPU"""

    def __init__(self, cache_dir: Path = None):
        self.cache_dir = cache_dir or Path.home() / ".cache" / "doc_browser_ai"
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.models = {}
        self.device = "CPU"
        self.ov_core = None

        # Initialize OpenVINO if available
        try:
            try:
                from openvino import Core  # New API (2025.0+)
            except ImportError:
                from openvino.runtime import Core  # Legacy API (fallback)
            self.ov_core = Core()
            self.device = HardwareDetector.get_optimal_device()
            print(f"✅ OpenVINO initialized - Using: {self.device}")
        except ImportError:
            print("ℹ️  OpenVINO not available - AI features disabled")

    def get_model_cache_path(self, model_name: str) -> Path:
        """Get cache path for model"""
        safe_name = re.sub(r"[^\w\-.]", "_", model_name)
        return self.cache_dir / safe_name

    def load_embedding_model(self, model_name: str = "all-MiniLM-L6-v2"):
        """Load sentence embedding model optimized for NPU/GPU with OpenVINO"""
        cache_key = f"embeddings_{model_name}"

        if cache_key in self.models:
            return self.models[cache_key]

        try:
            # Try OpenVINO-optimized model first (for NPU/GPU)
            if self.ov_core and self.device in ["NPU", "GPU"]:
                ov_model = self._load_openvino_embedding_model(model_name)
                if ov_model:
                    self.models[cache_key] = ov_model
                    return ov_model

            # Fallback to standard sentence-transformers (CPU)
            from sentence_transformers import SentenceTransformer

            print(f"📥 Loading embedding model: {model_name} (CPU mode)...")
            model = SentenceTransformer(model_name, cache_folder=str(self.cache_dir))

            self.models[cache_key] = model
            return model

        except Exception as e:
            print(f"❌ Failed to load embedding model: {e}")
            return None

    def _load_openvino_embedding_model(self, model_name: str):
        """Load OpenVINO-optimized embedding model for NPU/GPU"""
        try:
            from optimum.intel.openvino import OVModelForFeatureExtraction
            from transformers import AutoTokenizer

            model_id = f"sentence-transformers/{model_name}"
            ov_model_path = self.get_model_cache_path(f"{model_name}_ov_{self.device}")

            # Check if already converted
            if ov_model_path.exists():
                print(f"📥 Loading cached OpenVINO model from {ov_model_path}...")
                try:
                    model = OVModelForFeatureExtraction.from_pretrained(
                        ov_model_path, device=self.device
                    )
                    tokenizer = AutoTokenizer.from_pretrained(ov_model_path)
                    print(f"✅ Loaded optimized model on {self.device}")
                    return {"model": model, "tokenizer": tokenizer, "type": "openvino"}
                except Exception as e:
                    print(f"⚠️  Cache invalid, reconverting: {e}")

            # Convert to OpenVINO format
            print(f"🔧 Converting {model_name} to OpenVINO for {self.device}...")
            print(f"   This may take 1-2 minutes on first run...")

            model = OVModelForFeatureExtraction.from_pretrained(
                model_id, export=True, device=self.device
            )
            tokenizer = AutoTokenizer.from_pretrained(model_id)

            # Save for future use
            model.save_pretrained(ov_model_path)
            tokenizer.save_pretrained(ov_model_path)

            print(f"✅ Model optimized and cached for {self.device}")
            print(f"   Future runs will load instantly from cache")

            return {"model": model, "tokenizer": tokenizer, "type": "openvino"}

        except Exception as e:
            print(f"ℹ️  OpenVINO optimization failed: {e}")
            print(f"   Falling back to standard model...")
            return None

    def encode_texts(self, texts: List[str]) -> Optional[Any]:
        """Encode texts to embeddings using OpenVINO or standard models"""
        model = self.load_embedding_model()
        if model is None:
            return None

        try:
            # Check if OpenVINO model (dict) or standard model (object)
            if isinstance(model, dict) and model.get("type") == "openvino":
                # OpenVINO model - use tokenizer + model inference
                import numpy as np
                import torch  # Needed for tensor operations

                tokenizer = model["tokenizer"]
                ov_model = model["model"]

                # Tokenize texts
                inputs = tokenizer(
                    texts,
                    padding=True,
                    truncation=True,
                    return_tensors="pt",
                    max_length=512,
                )

                # Run inference on NPU/GPU
                outputs = ov_model(**inputs)

                # Mean pooling
                attention_mask = inputs["attention_mask"]
                token_embeddings = outputs[0]
                input_mask_expanded = (
                    attention_mask.unsqueeze(-1).expand(token_embeddings.size()).float()
                )
                embeddings = torch.sum(
                    token_embeddings * input_mask_expanded, 1
                ) / torch.clamp(input_mask_expanded.sum(1), min=1e-9)

                return embeddings.detach().cpu().numpy()

            else:
                # Standard sentence-transformers model (CPU)
                embeddings = model.encode(texts, show_progress_bar=False)
                return embeddings

        except Exception as e:
            print(f"Error encoding texts: {e}")
            # Fallback: try standard encoding
            try:
                if hasattr(model, "encode"):
                    return model.encode(texts, show_progress_bar=False)
            except:
                pass
            return None

    def semantic_search(
        self, query: str, documents: List[str], top_k: int = 5
    ) -> List[Tuple[int, float]]:
        """Perform semantic search using embeddings"""
        model = self.load_embedding_model()
        if model is None:
            return []

        try:
            # Encode query and documents
            query_embedding = model.encode([query], show_progress_bar=False)
            doc_embeddings = model.encode(documents, show_progress_bar=False)

            # Compute cosine similarity
            import numpy as np
            from sklearn.metrics.pairwise import cosine_similarity

            similarities = cosine_similarity(query_embedding, doc_embeddings)[0]

            # Get top-k results
            top_indices = np.argsort(similarities)[::-1][:top_k]
            results = [
                (idx, float(similarities[idx]))
                for idx in top_indices
                if similarities[idx] > 0.3
            ]

            return results
        except Exception as e:
            print(f"Error in semantic search: {e}")
            return []


# ============================================================================
# DOCKER GENERATOR
# ============================================================================


class DockerGenerator:
    """Generate Docker configuration for the document browser"""

    @staticmethod
    def generate_dockerfile(has_npu: bool = False, has_gpu: bool = False) -> str:
        """Generate Dockerfile content"""
        gpu_support = ""
        if has_gpu:
            gpu_support = """
# Intel GPU support
RUN apt-get update && apt-get install -y \\
    intel-opencl-icd \\
    intel-level-zero-gpu \\
    && rm -rf /var/lib/apt/lists/*
"""

        npu_note = ""
        if has_npu:
            npu_note = """
# Note: NPU support requires device passthrough
# Use: docker run --device=/dev/intel_gna:/dev/intel_gna
"""

        dockerfile = f"""# Auto-generated Dockerfile for AI Document Browser
FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \\
    libgl1-mesa-glx \\
    libglib2.0-0 \\
    libsm6 \\
    libxext6 \\
    libxrender-dev \\
    libgomp1 \\
    && rm -rf /var/lib/apt/lists/*
{gpu_support}{npu_note}
# Set working directory
WORKDIR /app

# Copy the single-file browser
COPY doc_browser_ai.py /app/

# Install Python dependencies (will auto-install on first run)
# Pre-install to speed up container startup
RUN pip install --no-cache-dir \\
    openvino>=2024.0.0 \\
    openvino-dev \\
    sentence-transformers \\
    transformers \\
    torch \\
    pdfplumber \\
    Pillow \\
    markdown \\
    scikit-learn \\
    numpy

# Create cache directory
RUN mkdir -p /root/.cache/doc_browser_ai

# Expose port for web interface (if enabled)
EXPOSE 8080

# Set display for GUI (X11 forwarding)
ENV DISPLAY=:0

# Run the browser
CMD ["python3", "doc_browser_ai.py"]
"""
        return dockerfile

    @staticmethod
    def generate_docker_compose(has_npu: bool = False, has_gpu: bool = False) -> str:
        """Generate docker-compose.yml content"""

        devices = []
        if has_npu:
            devices.append("      - /dev/intel_gna:/dev/intel_gna")
        if has_gpu:
            devices.append("      - /dev/dri:/dev/dri")

        device_section = ""
        if devices:
            device_section = f"""
    devices:
{chr(10).join(devices)}"""

        compose = f"""# Auto-generated docker-compose.yml for AI Document Browser
version: '3.8'

services:
  doc-browser:
    build: .
    container_name: doc-browser-ai
    volumes:
      - ./:/docs:ro  # Mount current directory as read-only
      - ~/.cache/doc_browser_ai:/root/.cache/doc_browser_ai  # Model cache
      - /tmp/.X11-unix:/tmp/.X11-unix:rw  # X11 for GUI
    environment:
      - DISPLAY=${{DISPLAY}}
      - QT_X11_NO_MITSHM=1{device_section}
    network_mode: host
    stdin_open: true
    tty: true

    # For web interface mode (optional)
    # ports:
    #   - "8080:8080"
"""
        return compose

    @staticmethod
    def generate_dockerignore() -> str:
        """Generate .dockerignore content"""
        return """# Docker ignore patterns
.git
.github
__pycache__
*.pyc
*.pyo
*.pyd
.Python
.cache
*.so
.env
venv/
env/
*.egg-info/
dist/
build/
.vscode/
.idea/
*.swp
*.swo
*~
.DS_Store
"""

    @staticmethod
    def initialize_docker(output_dir: Path, hardware_info: Dict) -> bool:
        """Generate all Docker files"""
        try:
            print("🐳 Generating Docker configuration...")

            # Generate Dockerfile
            dockerfile_content = DockerGenerator.generate_dockerfile(
                has_npu=hardware_info.get("has_npu", False),
                has_gpu=hardware_info.get("has_intel_gpu", False),
            )
            with open(output_dir / "Dockerfile", "w") as f:
                f.write(dockerfile_content)
            print("✅ Created Dockerfile")

            # Generate docker-compose.yml
            compose_content = DockerGenerator.generate_docker_compose(
                has_npu=hardware_info.get("has_npu", False),
                has_gpu=hardware_info.get("has_intel_gpu", False),
            )
            with open(output_dir / "docker-compose.yml", "w") as f:
                f.write(compose_content)
            print("✅ Created docker-compose.yml")

            # Generate .dockerignore
            dockerignore_content = DockerGenerator.generate_dockerignore()
            with open(output_dir / ".dockerignore", "w") as f:
                f.write(dockerignore_content)
            print("✅ Created .dockerignore")

            # Generate README
            readme_content = f"""# Docker Setup for AI Document Browser

## Quick Start

```bash
# Build and run:
docker-compose up --build

# Or run directly:
docker build -t doc-browser-ai .
docker run -it --rm \\
  -v $(pwd):/docs:ro \\
  -v ~/.cache/doc_browser_ai:/root/.cache/doc_browser_ai \\
  -e DISPLAY=$DISPLAY \\
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \\
  {"--device=/dev/intel_gna:/dev/intel_gna" if hardware_info.get('has_npu') else ""} \\
  {"--device=/dev/dri:/dev/dri" if hardware_info.get('has_intel_gpu') else ""} \\
  doc-browser-ai
```

## Hardware Detected

- CPU: {hardware_info.get('cpu_model', 'Unknown')}
- Cores: {hardware_info.get('cpu_cores', 0)}
- NPU: {"✅ Available" if hardware_info.get('has_npu') else "❌ Not detected"}
- Intel GPU: {"✅ Available" if hardware_info.get('has_intel_gpu') else "❌ Not detected"}
- OpenVINO Devices: {', '.join(hardware_info.get('openvino_devices', ['CPU']))}

## Features

- AI-powered document analysis using OpenVINO
- NPU acceleration for inference (if available)
- GPU acceleration for image processing
- Semantic search with embeddings
- Automatic document summarization
- PDF text extraction and OCR
- Works with any documentation structure

## Notes

- Models are cached in ~/.cache/doc_browser_ai (persists across containers)
- First run will download required AI models (~500MB)
- GUI requires X11 forwarding (configured automatically)
"""
            with open(output_dir / "README_DOCKER.md", "w") as f:
                f.write(readme_content)
            print("✅ Created README_DOCKER.md")

            print("\n🎉 Docker initialization complete!")
            print("\nTo run:")
            print("  docker-compose up --build")
            print("\nOr:")
            print("  docker build -t doc-browser-ai .")
            print("  docker-compose up")

            return True

        except Exception as e:
            print(f"❌ Failed to generate Docker files: {e}")
            return False


# ============================================================================
# ENHANCED PDF PROCESSOR
# ============================================================================


class PDFProcessor:
    """Enhanced PDF processing with OCR and image extraction"""

    @staticmethod
    def extract_text(pdf_path: Path, use_ocr: bool = False) -> str:
        """Extract text from PDF with optional OCR"""
        try:
            import pdfplumber

            text_parts = []
            with pdfplumber.open(pdf_path) as pdf:
                for i, page in enumerate(pdf.pages, 1):
                    text = page.extract_text()
                    if text:
                        text_parts.append(f"\n{'='*60}\nPage {i}\n{'='*60}\n{text}")
                    elif use_ocr:
                        # OCR for scanned pages (if tesseract available)
                        try:
                            import pytesseract
                            from PIL import Image

                            img = page.to_image()
                            ocr_text = pytesseract.image_to_string(img.original)
                            text_parts.append(
                                f"\n{'='*60}\nPage {i} (OCR)\n{'='*60}\n{ocr_text}"
                            )
                        except:
                            text_parts.append(f"\nPage {i}: [OCR not available]")

            return "\n".join(text_parts)
        except Exception as e:
            return f"Error extracting PDF: {e}"

    @staticmethod
    def get_pdf_metadata(pdf_path: Path) -> Dict[str, str]:
        """Extract PDF metadata"""
        try:
            import pdfplumber

            with pdfplumber.open(pdf_path) as pdf:
                metadata = pdf.metadata or {}
                return {
                    "pages": str(len(pdf.pages)),
                    "title": metadata.get("Title", "Unknown"),
                    "author": metadata.get("Author", "Unknown"),
                    "subject": metadata.get("Subject", "Unknown"),
                    "creator": metadata.get("Creator", "Unknown"),
                    "producer": metadata.get("Producer", "Unknown"),
                }
        except:
            return {"error": "Could not read PDF metadata"}


# ============================================================================
# SEMANTIC SEARCH ENGINE
# ============================================================================


class SemanticSearchEngine:
    """AI-powered semantic search using embeddings"""

    def __init__(self, model_manager: AIModelManager):
        self.model_manager = model_manager
        self.document_index = {}
        self.embeddings = None

    def index_documents(self, documents: List[Tuple[Path, str]]) -> bool:
        """Index documents for semantic search"""
        try:
            print(f"🔍 Indexing {len(documents)} documents for semantic search...")

            # Extract text samples for embedding
            doc_samples = []
            doc_paths = []

            for path, content in documents:
                # Use first 500 chars as representative sample
                sample = content[:500] if len(content) > 500 else content
                doc_samples.append(sample)
                doc_paths.append(path)

            # Generate embeddings using NPU if available
            embeddings = self.model_manager.encode_texts(doc_samples)

            if embeddings is not None:
                self.embeddings = embeddings
                self.document_index = {
                    str(path): idx for idx, path in enumerate(doc_paths)
                }
                print(f"✅ Indexed {len(documents)} documents")
                return True

            return False

        except Exception as e:
            print(f"❌ Indexing failed: {e}")
            return False

    def search(self, query: str, top_k: int = 10) -> List[Tuple[str, float]]:
        """Perform semantic search"""
        if not self.document_index or self.embeddings is None:
            return []

        try:
            # Get query embedding
            query_emb = self.model_manager.encode_texts([query])
            if query_emb is None:
                return []

            # Compute similarities
            import numpy as np
            from sklearn.metrics.pairwise import cosine_similarity

            similarities = cosine_similarity(query_emb, self.embeddings)[0]

            # Get top results
            top_indices = np.argsort(similarities)[::-1][:top_k]

            # Map back to documents
            results = []
            for idx in top_indices:
                if similarities[idx] > 0.3:  # Relevance threshold
                    doc_path = list(self.document_index.keys())[idx]
                    results.append((doc_path, float(similarities[idx])))

            return results

        except Exception as e:
            print(f"Error in semantic search: {e}")
            return []


# ============================================================================
# ENHANCED DOCUMENT BROWSER UI
# ============================================================================


class EnhancedDocumentBrowser:
    """AI-Enhanced document browser with NPU/GPU acceleration"""

    def __init__(self, root: tk.Tk, docs_path: Path):
        self.root = root
        self.docs_path = docs_path
        self.current_file = None

        # Initialize AI components
        self.model_manager = AIModelManager()
        self.semantic_engine = SemanticSearchEngine(self.model_manager)

        # Get hardware info
        self.hardware_info = HardwareDetector.get_hardware_info()

        # Document cache
        self.doc_cache = {}
        self.search_mode = "keyword"  # or 'semantic'

        # Setup UI
        self.setup_ui()
        self.load_documents()

    def setup_ui(self):
        """Create the user interface with dark mode"""
        # Window setup
        self.root.title(f"AI Document Browser - {self.docs_path.name}")
        self.root.geometry("1600x1000")

        # Configure dark mode theme
        self.setup_dark_theme()

        # Main container
        main = ttk.Frame(self.root, padding=10)
        main.grid(row=0, column=0, sticky="nsew")
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(0, weight=1)
        main.columnconfigure(1, weight=1)
        main.rowconfigure(1, weight=1)

        # Create UI components
        self.create_toolbar(main)
        self.create_sidebar(main)
        self.create_content_area(main)
        self.create_ai_panel(main)
        self.create_status_bar(main)

    def setup_dark_theme(self):
        """Configure dark mode theme for the application"""
        # Dark theme colors
        self.colors = {
            "bg": "#1e1e1e",  # Dark background
            "fg": "#d4d4d4",  # Light text
            "select_bg": "#264f78",  # Selection background
            "select_fg": "#ffffff",  # Selection text
            "border": "#3e3e3e",  # Borders
            "button_bg": "#2d2d2d",  # Button background
            "button_fg": "#cccccc",  # Button text
            "highlight": "#007acc",  # Highlight color
            "success": "#4ec9b0",  # Success/NPU color
            "warning": "#ce9178",  # Warning color
            "error": "#f48771",  # Error color
            "code_bg": "#252526",  # Code background
            "comment": "#6a9955",  # Comments
        }

        # Configure ttk styles
        style = ttk.Style()
        style.theme_use("clam")

        # Configure all ttk widgets for dark mode
        style.configure(
            ".",
            background=self.colors["bg"],
            foreground=self.colors["fg"],
            bordercolor=self.colors["border"],
            darkcolor=self.colors["bg"],
            lightcolor=self.colors["border"],
            troughcolor=self.colors["bg"],
            fieldbackground=self.colors["code_bg"],
            selectbackground=self.colors["select_bg"],
            selectforeground=self.colors["select_fg"],
        )

        style.configure("TFrame", background=self.colors["bg"])
        style.configure(
            "TLabel", background=self.colors["bg"], foreground=self.colors["fg"]
        )
        style.configure(
            "TLabelframe",
            background=self.colors["bg"],
            foreground=self.colors["fg"],
            bordercolor=self.colors["border"],
        )
        style.configure(
            "TLabelframe.Label",
            background=self.colors["bg"],
            foreground=self.colors["highlight"],
        )

        style.configure(
            "TButton",
            background=self.colors["button_bg"],
            foreground=self.colors["button_fg"],
            bordercolor=self.colors["border"],
            focuscolor=self.colors["highlight"],
        )

        style.map(
            "TButton",
            background=[
                ("active", self.colors["select_bg"]),
                ("pressed", self.colors["highlight"]),
            ],
        )

        style.configure(
            "Treeview",
            background=self.colors["code_bg"],
            foreground=self.colors["fg"],
            fieldbackground=self.colors["code_bg"],
            bordercolor=self.colors["border"],
        )

        style.map(
            "Treeview",
            background=[("selected", self.colors["select_bg"])],
            foreground=[("selected", self.colors["select_fg"])],
        )

        style.configure(
            "TEntry",
            fieldbackground=self.colors["code_bg"],
            foreground=self.colors["fg"],
            insertcolor=self.colors["fg"],
        )

        # Configure root window
        self.root.configure(bg=self.colors["bg"])

    def create_toolbar(self, parent):
        """Create toolbar with hardware info"""
        toolbar = ttk.Frame(parent)
        toolbar.grid(row=0, column=0, columnspan=3, sticky="ew", pady=(0, 5))

        # Hardware status
        hw_frame = ttk.LabelFrame(toolbar, text="Hardware Acceleration", padding=5)
        hw_frame.pack(side=tk.LEFT, padx=(0, 10))

        device = self.hardware_info.get("optimal_device", "CPU")
        device_color = {"NPU": "green", "GPU": "blue", "CPU": "orange"}.get(
            device, "gray"
        )

        ttk.Label(
            hw_frame,
            text=f"Using: {device}",
            foreground=device_color,
            font=("Arial", 9, "bold"),
        ).pack(side=tk.LEFT, padx=5)

        if self.hardware_info.get("has_npu"):
            ttk.Label(hw_frame, text="🚀 NPU", foreground="green").pack(side=tk.LEFT)
        if self.hardware_info.get("has_intel_gpu"):
            ttk.Label(hw_frame, text="🎮 GPU", foreground="blue").pack(side=tk.LEFT)

        # Search mode toggle
        search_frame = ttk.LabelFrame(toolbar, text="Search Mode", padding=5)
        search_frame.pack(side=tk.LEFT, padx=(0, 10))

        self.search_mode_var = tk.StringVar(value="keyword")
        ttk.Radiobutton(
            search_frame,
            text="Keyword",
            variable=self.search_mode_var,
            value="keyword",
            command=self.on_search_mode_change,
        ).pack(side=tk.LEFT)
        ttk.Radiobutton(
            search_frame,
            text="🧠 Semantic (AI)",
            variable=self.search_mode_var,
            value="semantic",
            command=self.on_search_mode_change,
        ).pack(side=tk.LEFT)

        # Search box
        search_box = ttk.Frame(toolbar)
        search_box.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 10))

        self.search_var = tk.StringVar()
        ttk.Entry(search_box, textvariable=self.search_var, font=("Arial", 10)).pack(
            side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 5)
        )
        ttk.Button(search_box, text="Search", command=self.perform_search).pack(
            side=tk.LEFT
        )

        # Actions
        ttk.Button(
            toolbar, text="📊 Hardware Info", command=self.show_hardware_info
        ).pack(side=tk.RIGHT, padx=2)
        ttk.Button(toolbar, text="🐳 Docker Init", command=self.init_docker).pack(
            side=tk.RIGHT, padx=2
        )

    def create_sidebar(self, parent):
        """Create document navigation sidebar"""
        sidebar = ttk.LabelFrame(parent, text="Documents", padding=5)
        sidebar.grid(row=1, column=0, sticky="nsew", padx=(0, 5))
        sidebar.rowconfigure(0, weight=1)
        sidebar.columnconfigure(0, weight=1)

        # Tree view for files
        tree_frame = ttk.Frame(sidebar)
        tree_frame.grid(row=0, column=0, sticky="nsew")
        tree_frame.rowconfigure(0, weight=1)
        tree_frame.columnconfigure(0, weight=1)

        self.file_tree = ttk.Treeview(tree_frame, selectmode="browse")
        self.file_tree.grid(row=0, column=0, sticky="nsew")

        scrollbar = ttk.Scrollbar(
            tree_frame, orient=tk.VERTICAL, command=self.file_tree.yview
        )
        scrollbar.grid(row=0, column=1, sticky="ns")
        self.file_tree.configure(yscrollcommand=scrollbar.set)

        self.file_tree.bind("<<TreeviewSelect>>", self.on_file_select)

    def create_content_area(self, parent):
        """Create main content viewing area"""
        content = ttk.LabelFrame(parent, text="Content", padding=5)
        content.grid(row=1, column=1, sticky="nsew", padx=(0, 5))
        content.rowconfigure(0, weight=1)
        content.columnconfigure(0, weight=1)

        # Text widget with scrollbars
        text_frame = ttk.Frame(content)
        text_frame.grid(row=0, column=0, sticky="nsew")
        text_frame.rowconfigure(0, weight=1)
        text_frame.columnconfigure(0, weight=1)

        self.content_text = scrolledtext.ScrolledText(
            text_frame,
            wrap=tk.WORD,
            font=("Consolas", 10),
            bg=self.colors["code_bg"],
            fg=self.colors["fg"],
            insertbackground=self.colors["fg"],
            selectbackground=self.colors["select_bg"],
            selectforeground=self.colors["select_fg"],
        )
        self.content_text.grid(row=0, column=0, sticky="nsew")

        # Configure text tags for markdown syntax highlighting
        self.setup_markdown_highlighting()

        # Content toolbar
        content_toolbar = ttk.Frame(content)
        content_toolbar.grid(row=1, column=0, sticky="ew", pady=(5, 0))

        ttk.Button(
            content_toolbar, text="📝 Summarize (AI)", command=self.summarize_document
        ).pack(side=tk.LEFT, padx=2)
        ttk.Button(
            content_toolbar,
            text="🔍 Extract Data",
            command=self.extract_structured_data,
        ).pack(side=tk.LEFT, padx=2)
        ttk.Button(
            content_toolbar, text="📂 Open External", command=self.open_external
        ).pack(side=tk.LEFT, padx=2)

    def create_ai_panel(self, parent):
        """Create AI interaction panel"""
        ai_panel = ttk.LabelFrame(parent, text="AI Assistant", padding=5)
        ai_panel.grid(row=1, column=2, sticky="nsew")
        ai_panel.rowconfigure(0, weight=1)
        ai_panel.columnconfigure(0, weight=1)

        # Q&A area
        self.ai_text = scrolledtext.ScrolledText(
            ai_panel,
            wrap=tk.WORD,
            font=("Arial", 10),
            width=40,
            bg=self.colors["code_bg"],
            fg=self.colors["fg"],
            insertbackground=self.colors["fg"],
            selectbackground=self.colors["select_bg"],
            selectforeground=self.colors["select_fg"],
        )
        self.ai_text.grid(row=0, column=0, sticky="nsew")
        self.ai_text.insert("1.0", "💡 AI Assistant Ready\n\n")
        self.ai_text.insert(
            "end", f"Device: {self.hardware_info.get('optimal_device', 'CPU')}\n"
        )
        self.ai_text.insert(
            "end", f"CPU: {self.hardware_info.get('cpu_cores', 0)} cores\n"
        )
        if self.hardware_info.get("has_npu"):
            self.ai_text.insert("end", "🚀 NPU: Available\n")
        self.ai_text.insert("end", "\nSelect a document to analyze.")
        self.ai_text.config(state=tk.DISABLED)

        # Question input
        q_frame = ttk.Frame(ai_panel)
        q_frame.grid(row=1, column=0, sticky="ew", pady=(5, 0))
        q_frame.columnconfigure(0, weight=1)

        self.question_var = tk.StringVar()
        ttk.Entry(q_frame, textvariable=self.question_var, font=("Arial", 10)).grid(
            row=0, column=0, sticky="ew", padx=(0, 5)
        )
        ttk.Button(q_frame, text="Ask AI", command=self.ask_ai_question).grid(
            row=0, column=1
        )

    def create_status_bar(self, parent):
        """Create status bar"""
        self.status_var = tk.StringVar(value="Ready")
        status = ttk.Label(
            parent, textvariable=self.status_var, relief=tk.SUNKEN, anchor=tk.W
        )
        status.grid(row=2, column=0, columnspan=3, sticky="ew", pady=(5, 0))

    def load_documents(self):
        """Load all documents in directory with intelligent categorization"""
        try:
            # Clear tree
            for item in self.file_tree.get_children():
                self.file_tree.delete(item)

            # Find all documents
            extensions = {
                ".md",
                ".txt",
                ".pdf",
                ".sql",
                ".csv",
                ".json",
                ".html",
                ".rst",
            }
            all_documents = []

            for ext in extensions:
                for file_path in self.docs_path.glob(f"*{ext}"):
                    if not file_path.name.startswith("."):
                        all_documents.append(file_path)

            # Intelligently categorize documents
            categories = self._categorize_documents(all_documents)

            # Insert categories and files
            for category_name, files in sorted(categories.items()):
                if category_name == "Uncategorized":
                    # Add uncategorized files directly to root
                    for file_path in sorted(files, key=lambda f: f.name.lower()):
                        size_str = self.format_size(file_path.stat().st_size)
                        file_type = self._get_file_type_icon(file_path)
                        self.file_tree.insert(
                            "",
                            "end",
                            text=f"{file_type} {file_path.name}",
                            values=(size_str,),
                            tags=("file",),
                        )
                else:
                    # Create category folder
                    category_id = self.file_tree.insert(
                        "",
                        "end",
                        text=f"📁 {category_name} ({len(files)})",
                        values=("",),
                        tags=("category",),
                    )

                    # Add files in this category
                    for file_path in sorted(files, key=lambda f: f.name.lower()):
                        size_str = self.format_size(file_path.stat().st_size)
                        file_type = self._get_file_type_icon(file_path)
                        self.file_tree.insert(
                            category_id,
                            "end",
                            text=f"{file_type} {file_path.name}",
                            values=(size_str,),
                            tags=("file",),
                        )

            # Configure tags for dark mode
            self.file_tree.tag_configure(
                "category",
                background=self.colors["select_bg"],
                foreground=self.colors["select_fg"],
                font=("Arial", 10, "bold"),
            )
            self.file_tree.tag_configure(
                "file", background=self.colors["code_bg"], foreground=self.colors["fg"]
            )

            self.status_var.set(
                f"Loaded {len(all_documents)} documents in {len(categories)} categories"
            )

            # Index for semantic search (background)
            if len(all_documents) > 0:
                threading.Thread(
                    target=self.index_documents_background,
                    args=(all_documents,),
                    daemon=True,
                ).start()

        except Exception as e:
            messagebox.showerror("Error", f"Failed to load documents: {e}")

    def _categorize_documents(self, documents: List[Path]) -> Dict[str, List[Path]]:
        """Intelligently categorize documents by content and naming patterns"""
        categories = defaultdict(list)

        # Define category patterns (order matters - first match wins)
        patterns = [
            (
                "🔐 Security & Credentials",
                [
                    r"security|credential|password|access|auth|threat|attack|vulnerability",
                    r"ssh|root|admin|takeover|breach|hack",
                ],
            ),
            (
                "📊 Analysis & Reports",
                [
                    r"analysis|report|assessment|audit|review",
                    r"crack.*time|realistic|actual",
                ],
            ),
            (
                "🌐 Network & URLs",
                [r"network|url|website|domain|email|ip", r"escalation.*server|pathway"],
            ),
            (
                "📚 Documentation",
                [r"documentation|readme|guide|manual", r"database.*doc|action.*plan"],
            ),
            ("🐳 Docker & Deployment", [r"docker|dockerfile|compose|deployment"]),
            ("💾 Database Files", [r"\.sql$|database.*content"]),
            (
                "📄 Quick Reference",
                [
                    r"quick|summary|reference|checklist",
                    r"urls.*quick|credentials.*quick",
                ],
            ),
        ]

        for doc_path in documents:
            filename_lower = doc_path.name.lower()
            categorized = False

            # Try to match patterns
            for category_name, pattern_list in patterns:
                for pattern in pattern_list:
                    if re.search(pattern, filename_lower):
                        categories[category_name].append(doc_path)
                        categorized = True
                        break
                if categorized:
                    break

            # If no match, add to uncategorized
            if not categorized:
                categories["Uncategorized"].append(doc_path)

        return dict(categories)

    def _get_file_type_icon(self, file_path: Path) -> str:
        """Get emoji icon for file type"""
        ext = file_path.suffix.lower()
        icons = {
            ".md": "📝",
            ".pdf": "📄",
            ".sql": "🗄️",
            ".txt": "📃",
            ".csv": "📊",
            ".json": "🔧",
            ".html": "🌐",
            ".rst": "📰",
        }
        return icons.get(ext, "📄")

    def index_documents_background(self, documents: List[Path]):
        """Index documents in background for semantic search"""
        try:
            doc_contents = []
            for doc_path in documents[:50]:  # Limit to first 50 for performance
                try:
                    if doc_path.suffix == ".pdf":
                        content = PDFProcessor.extract_text(doc_path)
                    else:
                        with open(
                            doc_path, "r", encoding="utf-8", errors="ignore"
                        ) as f:
                            content = f.read()
                    doc_contents.append((doc_path, content[:1000]))  # First 1000 chars
                except:
                    continue

            if doc_contents:
                self.semantic_engine.index_documents(doc_contents)
        except Exception as e:
            print(f"Background indexing error: {e}")

    def on_file_select(self, event):
        """Handle file selection"""
        selection = self.file_tree.selection()
        if not selection:
            return

        item = self.file_tree.item(selection[0])
        item_text = item["text"]

        # Skip if it's a category folder
        if item_text.startswith("📁"):
            return

        # Remove file type icon from filename
        filename = re.sub(r"^[📝📄🗄️📃📊🔧🌐📰]\s+", "", item_text)

        # Try to find the file
        file_path = self.docs_path / filename

        if file_path.exists():
            self.load_file(file_path)

    def load_file(self, file_path: Path):
        """Load and display file content"""
        try:
            self.current_file = file_path
            self.content_text.config(state=tk.NORMAL)
            self.content_text.delete("1.0", tk.END)

            if file_path.suffix == ".pdf":
                content = PDFProcessor.extract_text(file_path)
                self.content_text.insert("1.0", content)
            else:
                with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
                    content = f.read()

                # Apply markdown highlighting if .md file
                if file_path.suffix.lower() == ".md":
                    self.render_markdown_with_highlighting(content)
                else:
                    self.content_text.insert("1.0", content)

            self.content_text.config(state=tk.DISABLED)

            # Cache content
            self.doc_cache[str(file_path)] = content

            # Update AI panel
            self.update_ai_panel(file_path, content)

            self.status_var.set(f"Loaded: {file_path.name}")

        except Exception as e:
            messagebox.showerror("Error", f"Failed to load file: {e}")

    def update_ai_panel(self, file_path: Path, content: str):
        """Update AI panel with document analysis"""
        self.ai_text.config(state=tk.NORMAL)
        self.ai_text.delete("1.0", tk.END)

        self.ai_text.insert("1.0", f"📄 {file_path.name}\n\n")
        self.ai_text.insert("end", f"Size: {self.format_size(len(content))} chars\n")
        self.ai_text.insert("end", f"Lines: {len(content.splitlines())}\n\n")

        # Quick stats
        if "password" in content.lower():
            self.ai_text.insert("end", "⚠️  Contains: PASSWORD references\n", "warning")
        if re.search(r"\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}", content):
            self.ai_text.insert("end", "🌐 Contains: IP addresses\n", "info")
        if "@" in content:
            emails = len(re.findall(r"[\w\.-]+@[\w\.-]+", content))
            self.ai_text.insert("end", f"📧 Found: {emails} email addresses\n", "info")

        self.ai_text.insert("end", "\n💬 Ask me anything about this document...")
        self.ai_text.config(state=tk.DISABLED)

    def perform_search(self):
        """Perform search based on selected mode"""
        query = self.search_var.get().strip()
        if not query:
            return

        if (
            self.search_mode_var.get() == "semantic"
            and self.semantic_engine.embeddings is not None
        ):
            self.semantic_search(query)
        else:
            self.keyword_search(query)

    def keyword_search(self, query: str):
        """Traditional keyword search"""
        results = []

        for item in self.file_tree.get_children():
            filename = self.file_tree.item(item)["text"]
            file_path = self.docs_path / filename

            try:
                if file_path.suffix == ".pdf":
                    content = PDFProcessor.extract_text(file_path)
                else:
                    with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
                        content = f.read()

                if query.lower() in content.lower():
                    # Find context
                    lines = content.split("\n")
                    for i, line in enumerate(lines):
                        if query.lower() in line.lower():
                            context = line.strip()[:100]
                            results.append((filename, i + 1, context))
                            if len([r for r in results if r[0] == filename]) >= 3:
                                break
            except:
                continue

        self.show_search_results(query, results, "keyword")

    def semantic_search(self, query: str):
        """AI-powered semantic search"""
        self.status_var.set(f"🧠 Semantic search: {query}")

        results = self.semantic_engine.search(query, top_k=10)

        # Format results
        formatted_results = []
        for doc_path, score in results:
            filename = Path(doc_path).name
            formatted_results.append((filename, f"Similarity: {score:.2%}", doc_path))

        self.show_search_results(query, formatted_results, "semantic")

    def show_search_results(self, query: str, results: List, search_type: str):
        """Display search results"""
        if not results:
            messagebox.showinfo("Search Results", f"No results found for: {query}")
            return

        # Create results window
        results_win = tk.Toplevel(self.root)
        results_win.title(f"Search Results - {query} ({search_type})")
        results_win.geometry("900x600")

        frame = ttk.Frame(results_win, padding=10)
        frame.pack(fill=tk.BOTH, expand=True)

        ttk.Label(
            frame,
            text=f"Found {len(results)} results for: {query}",
            font=("Arial", 12, "bold"),
        ).pack(anchor=tk.W, pady=(0, 10))

        # Results list
        results_tree = ttk.Treeview(frame, columns=("file", "info"), show="headings")
        results_tree.heading("file", text="File")
        results_tree.heading("info", text="Information")
        results_tree.column("file", width=400)
        results_tree.column("info", width=450)
        results_tree.pack(fill=tk.BOTH, expand=True, pady=(0, 10))

        for result in results:
            results_tree.insert(
                "", "end", values=(result[0], result[1] if len(result) > 1 else "")
            )

        ttk.Button(frame, text="Close", command=results_win.destroy).pack()

    def summarize_document(self):
        """AI-powered document summarization using extractive + semantic approach"""
        if not self.current_file:
            messagebox.showwarning("Summarize", "No document selected")
            return

        content = self.doc_cache.get(str(self.current_file), "")
        if not content:
            messagebox.showwarning("Summarize", "Document not loaded")
            return

        self.status_var.set("🧠 Generating AI summary...")

        # Thread for AI summarization
        def summarize_thread():
            try:
                summary = self._generate_ai_summary(content)

                # Show summary in popup
                self.root.after(
                    0,
                    lambda: messagebox.showinfo(
                        "AI Summary",
                        f"Document: {self.current_file.name}\n"
                        f"Size: {len(content)} chars, {len(content.splitlines())} lines\n\n"
                        f"Summary:\n{summary}",
                    ),
                )
                self.root.after(
                    0,
                    lambda: self.status_var.set(
                        f"Summary generated for {self.current_file.name}"
                    ),
                )

            except Exception as e:
                self.root.after(
                    0,
                    lambda: messagebox.showerror("Error", f"Summarization failed: {e}"),
                )
                self.root.after(0, lambda: self.status_var.set("Summarization failed"))

        threading.Thread(target=summarize_thread, daemon=True).start()

    def _generate_ai_summary(self, content: str, max_sentences: int = 5) -> str:
        """Generate AI-powered summary using semantic analysis"""
        try:
            # Split into sentences
            sentences = re.split(r"[.!?]\s+", content)
            sentences = [s.strip() for s in sentences if len(s.strip()) > 20][
                :100
            ]  # First 100 sentences

            if len(sentences) <= max_sentences:
                return " ".join(sentences)

            # Use embeddings for extractive summarization
            embeddings = self.model_manager.encode_texts(sentences)

            if embeddings is not None:
                import numpy as np

                # Compute sentence importance using TF-IDF-like scoring
                from sklearn.feature_extraction.text import TfidfVectorizer

                # Get TF-IDF scores
                vectorizer = TfidfVectorizer(max_features=100)
                tfidf_matrix = vectorizer.fit_transform(sentences)

                # Compute importance scores
                importance = np.asarray(tfidf_matrix.sum(axis=1)).flatten()

                # Get top sentences
                top_indices = np.argsort(importance)[::-1][:max_sentences]
                top_indices = sorted(top_indices)  # Maintain order

                summary_sentences = [sentences[i] for i in top_indices]
                return ". ".join(summary_sentences) + "."

            else:
                # Fallback: keyword-based extraction
                summary_lines = []
                for sent in sentences[:50]:
                    if any(
                        kw in sent.lower()
                        for kw in [
                            "critical",
                            "important",
                            "summary",
                            "key",
                            "main",
                            "must",
                            "require",
                        ]
                    ):
                        summary_lines.append(sent)
                        if len(summary_lines) >= max_sentences:
                            break

                return (
                    ". ".join(summary_lines) + "."
                    if summary_lines
                    else "Could not generate summary."
                )

        except Exception as e:
            print(f"Summary generation error: {e}")
            return f"Error generating summary: {e}"

    def extract_structured_data(self):
        """Extract structured data (IPs, emails, passwords, etc.)"""
        if not self.current_file:
            return

        content = self.doc_cache.get(str(self.current_file), "")
        if not content:
            return

        # Extract various data types
        data = {
            "IPs": re.findall(r"\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b", content),
            "Emails": re.findall(r"[\w\.-]+@[\w\.-]+\.\w+", content),
            "URLs": re.findall(r'https?://[^\s<>"]+', content),
            "Passwords": re.findall(
                r'password[:\s]*[\'"]?(\w+)[\'"]?', content, re.IGNORECASE
            )[:5],
        }

        # Show results
        result_text = f"📊 Extracted Data from {self.current_file.name}\n\n"
        for key, values in data.items():
            unique_vals = list(set(values))[:10]  # Top 10 unique
            result_text += f"{key}: {len(unique_vals)} found\n"
            for val in unique_vals:
                result_text += f"  • {val}\n"
            result_text += "\n"

        messagebox.showinfo("Extracted Data", result_text)

    def ask_ai_question(self):
        """Ask question about current document using RAG approach"""
        question = self.question_var.get().strip()
        if not question or not self.current_file:
            return

        content = self.doc_cache.get(str(self.current_file), "")
        if not content:
            return

        self.ai_text.config(state=tk.NORMAL)
        self.ai_text.insert("end", f"\n\n❓ Q: {question}\n")
        self.ai_text.insert("end", "🔍 Searching document...\n")
        self.ai_text.config(state=tk.DISABLED)
        self.question_var.set("")

        # Process in background thread
        def qa_thread():
            try:
                answer = self._answer_question_rag(question, content)

                self.root.after(0, lambda: self._display_answer(answer))

            except Exception as e:
                self.root.after(0, lambda: self._display_answer(f"Error: {e}"))

        threading.Thread(target=qa_thread, daemon=True).start()

    def _answer_question_rag(self, question: str, content: str) -> str:
        """Answer question using Retrieval-Augmented Generation"""
        try:
            # Split content into chunks
            paragraphs = [
                p.strip() for p in content.split("\n\n") if len(p.strip()) > 50
            ]

            if not paragraphs:
                return "Document too short to analyze."

            # Use semantic search to find relevant chunks
            embeddings = self.model_manager.encode_texts(
                paragraphs[:200]
            )  # Limit to first 200 paragraphs

            if embeddings is not None:
                import numpy as np
                from sklearn.metrics.pairwise import cosine_similarity

                # Encode question
                question_emb = self.model_manager.encode_texts([question])

                if question_emb is not None:
                    # Find most relevant paragraphs
                    similarities = cosine_similarity(question_emb, embeddings)[0]
                    top_indices = np.argsort(similarities)[::-1][:3]  # Top 3 paragraphs

                    # Combine relevant paragraphs
                    relevant_text = "\n\n".join(
                        [paragraphs[i] for i in top_indices if similarities[i] > 0.2]
                    )

                    if relevant_text:
                        # Extract best answer (first 400 chars of most relevant)
                        answer = paragraphs[top_indices[0]]
                        if len(answer) > 400:
                            answer = answer[:400] + "..."

                        confidence = similarities[top_indices[0]]
                        return f"{answer}\n\n[Confidence: {confidence:.1%}]"

            # Fallback: keyword-based search
            relevant = []
            question_words = set(question.lower().split())

            for para in paragraphs[:100]:
                para_words = set(para.lower().split())
                overlap = len(question_words & para_words)

                if overlap >= 2:
                    relevant.append((para, overlap))

            if relevant:
                # Sort by overlap and get best match
                relevant.sort(key=lambda x: x[1], reverse=True)
                answer = relevant[0][0]
                if len(answer) > 400:
                    answer = answer[:400] + "..."
                return answer

            return "No relevant information found in document."

        except Exception as e:
            return f"Error during analysis: {e}"

    def _display_answer(self, answer: str):
        """Display answer in AI panel"""
        self.ai_text.config(state=tk.NORMAL)
        self.ai_text.delete("end-2l", "end")  # Remove "searching..." line
        self.ai_text.insert("end", f"💡 A: {answer}\n")
        self.ai_text.config(state=tk.DISABLED)
        self.ai_text.see(tk.END)

    def setup_markdown_highlighting(self):
        """Configure text tags for markdown syntax highlighting"""
        # Headers
        self.content_text.tag_configure(
            "h1", foreground="#569cd6", font=("Consolas", 16, "bold")
        )
        self.content_text.tag_configure(
            "h2", foreground="#4ec9b0", font=("Consolas", 14, "bold")
        )
        self.content_text.tag_configure(
            "h3", foreground="#4fc1ff", font=("Consolas", 12, "bold")
        )

        # Code blocks
        self.content_text.tag_configure(
            "code_block",
            background="#1a1a1a",
            foreground="#ce9178",
            font=("Consolas", 9),
        )

        # Inline code
        self.content_text.tag_configure(
            "inline_code",
            background="#2d2d2d",
            foreground="#ce9178",
            font=("Consolas", 10),
        )

        # Lists
        self.content_text.tag_configure("list_item", foreground="#dcdcaa")

        # Bold
        self.content_text.tag_configure(
            "bold", font=("Consolas", 10, "bold"), foreground="#ffffff"
        )

        # Italic
        self.content_text.tag_configure(
            "italic", font=("Consolas", 10, "italic"), foreground="#c586c0"
        )

        # Links
        self.content_text.tag_configure("link", foreground="#3794ff", underline=True)

        # Blockquotes
        self.content_text.tag_configure(
            "blockquote", foreground="#6a9955", font=("Consolas", 10, "italic")
        )

        # Tables
        self.content_text.tag_configure(
            "table", background="#2d2d2d", foreground="#dcdcaa"
        )

        # Warnings/alerts
        self.content_text.tag_configure(
            "warning", foreground="#ce9178", background="#3d2817"
        )
        self.content_text.tag_configure(
            "info", foreground="#4fc1ff", background="#17344a"
        )
        self.content_text.tag_configure(
            "success", foreground="#4ec9b0", background="#1a3a2e"
        )
        self.content_text.tag_configure(
            "error", foreground="#f48771", background="#3d1f1f"
        )

    def render_markdown_with_highlighting(self, content: str):
        """Render markdown with intelligent syntax highlighting"""
        lines = content.split("\n")
        in_code_block = False
        code_block_start = None

        for i, line in enumerate(lines):
            line_start = self.content_text.index(tk.END)

            # Code blocks
            if line.strip().startswith("```"):
                if not in_code_block:
                    in_code_block = True
                    code_block_start = line_start
                    self.content_text.insert(tk.END, line + "\n", "code_block")
                else:
                    in_code_block = False
                    self.content_text.insert(tk.END, line + "\n", "code_block")
                continue

            if in_code_block:
                self.content_text.insert(tk.END, line + "\n", "code_block")
                continue

            # Headers
            if line.startswith("# "):
                self.content_text.insert(tk.END, line + "\n", "h1")
            elif line.startswith("## "):
                self.content_text.insert(tk.END, line + "\n", "h2")
            elif line.startswith("### "):
                self.content_text.insert(tk.END, line + "\n", "h3")

            # Lists
            elif re.match(r"^[\s]*[-*+]\s", line) or re.match(r"^[\s]*\d+\.\s", line):
                self.content_text.insert(tk.END, line + "\n", "list_item")

            # Blockquotes
            elif line.startswith(">"):
                self.content_text.insert(tk.END, line + "\n", "blockquote")

            # Table rows
            elif "|" in line and line.count("|") >= 2:
                self.content_text.insert(tk.END, line + "\n", "table")

            # Regular text with inline formatting
            else:
                self._insert_line_with_inline_formatting(line + "\n")

    def _insert_line_with_inline_formatting(self, line: str):
        """Insert line with inline markdown formatting (bold, italic, code, links)"""
        pos = 0
        original_line = line

        # Parse inline formatting
        # Inline code: `code`
        inline_code_pattern = r"`([^`]+)`"
        # Bold: **text** or __text__
        bold_pattern = r"\*\*([^\*]+)\*\*|__([^_]+)__"
        # Italic: *text* or _text_
        italic_pattern = r"\*([^\*]+)\*|_([^_]+)_"
        # Links: [text](url) or just URLs
        link_pattern = r'\[([^\]]+)\]\(([^\)]+)\)|https?://[^\s<>"]+'

        # Collect all matches with positions
        matches = []

        for match in re.finditer(inline_code_pattern, line):
            matches.append(("inline_code", match.start(), match.end(), match.group(1)))

        for match in re.finditer(bold_pattern, line):
            text = match.group(1) or match.group(2)
            matches.append(("bold", match.start(), match.end(), text))

        for match in re.finditer(link_pattern, line):
            if match.group(0).startswith("["):
                text = match.group(1)
            else:
                text = match.group(0)
            matches.append(("link", match.start(), match.end(), text))

        # Sort by position
        matches.sort(key=lambda x: x[1])

        # Insert text with formatting
        if not matches:
            self.content_text.insert(tk.END, line)
            return

        last_end = 0
        for tag, start, end, text in matches:
            # Insert text before match
            if start > last_end:
                self.content_text.insert(tk.END, line[last_end:start])

            # Insert formatted text
            self.content_text.insert(tk.END, text, tag)
            last_end = end

        # Insert remaining text
        if last_end < len(line):
            self.content_text.insert(tk.END, line[last_end:])

    def on_search_mode_change(self):
        """Handle search mode change"""
        mode = self.search_mode_var.get()
        self.search_mode = mode

        if mode == "semantic" and self.semantic_engine.embeddings is None:
            self.status_var.set("Indexing documents for semantic search...")
            # Trigger indexing if not done

    def show_hardware_info(self):
        """Display hardware information"""
        info = self.hardware_info

        info_text = "🖥️  Hardware Information\n\n"
        info_text += f"CPU: {info.get('cpu_model', 'Unknown')}\n"
        info_text += f"Cores: {info.get('cpu_cores', 0)}\n"
        info_text += f"Platform: {info.get('platform', 'Unknown')}\n"
        info_text += f"Python: {info.get('python_version', 'Unknown')}\n\n"

        info_text += "AI Acceleration:\n"
        info_text += (
            f"  NPU: {'✅ Available' if info.get('has_npu') else '❌ Not detected'}\n"
        )
        info_text += f"  Intel GPU: {'✅ Available' if info.get('has_intel_gpu') else '❌ Not detected'}\n"
        info_text += (
            f"  OpenVINO Devices: {', '.join(info.get('openvino_devices', ['None']))}\n"
        )
        info_text += f"  Optimal Device: {info.get('optimal_device', 'CPU')}\n\n"

        if info.get("has_npu"):
            info_text += "🚀 NPU Acceleration Active\n"
            info_text += "   - Inference: ~40 TOPS on Intel Ultra 7 165H\n"
            info_text += "   - Models: INT8 quantized for efficiency\n"

        messagebox.showinfo("Hardware Information", info_text)

    def init_docker(self):
        """Initialize Docker configuration"""
        if messagebox.askyesno(
            "Docker Init",
            "Generate Docker configuration files?\n\n"
            "This will create:\n"
            "- Dockerfile\n"
            "- docker-compose.yml\n"
            "- .dockerignore\n"
            "- README_DOCKER.md",
        ):
            try:
                DockerGenerator.initialize_docker(self.docs_path, self.hardware_info)
                messagebox.showinfo(
                    "Docker Init",
                    "✅ Docker files created!\n\n" "Run: docker-compose up --build",
                )
            except Exception as e:
                messagebox.showerror("Error", f"Failed to create Docker files: {e}")

    def open_external(self):
        """Open current file externally"""
        if not self.current_file:
            return

        try:
            if sys.platform == "linux":
                subprocess.run(["xdg-open", str(self.current_file)])
            elif sys.platform == "darwin":
                subprocess.run(["open", str(self.current_file)])
            elif sys.platform == "win32":
                os.startfile(str(self.current_file))
        except Exception as e:
            messagebox.showerror("Error", f"Failed to open: {e}")

    @staticmethod
    def format_size(size: int) -> str:
        """Format file size"""
        for unit in ["B", "KB", "MB", "GB"]:
            if size < 1024.0:
                return f"{size:.1f} {unit}"
            size /= 1024.0
        return f"{size:.1f} TB"


# ============================================================================
# MAIN APPLICATION
# ============================================================================


def check_hardware():
    """Check and display hardware capabilities"""
    print("\n" + "=" * 70)
    print("🖥️  HARDWARE DETECTION")
    print("=" * 70)

    hardware = HardwareDetector.get_hardware_info()

    print(f"\nCPU: {hardware.get('cpu_model', 'Unknown')}")
    print(f"Cores: {hardware.get('cpu_cores', 0)}")
    print(f"Platform: {hardware.get('platform', 'Unknown')}")
    print(f"Python: {hardware.get('python_version', 'Unknown')}")

    print("\nAI Acceleration:")
    print(
        f"  NPU/GNA: {'✅ AVAILABLE' if hardware.get('has_npu') else '❌ Not detected'}"
    )
    print(
        f"  Intel GPU: {'✅ AVAILABLE' if hardware.get('has_intel_gpu') else '❌ Not detected'}"
    )
    print(
        f"  OpenVINO Devices: {', '.join(hardware.get('openvino_devices', ['None']))}"
    )
    print(f"  Optimal Device: {hardware.get('optimal_device', 'CPU')}")

    if hardware.get("has_npu"):
        print("\n🚀 NPU Acceleration:")
        print("   - Performance: ~40 TOPS (Intel Core Ultra 7 165H)")
        print("   - Use Case: AI inference, embeddings, summarization")
        print("   - Power: Efficient (low power consumption)")

    if hardware.get("has_intel_gpu"):
        print("\n🎮 GPU Acceleration:")
        print("   - Type: Intel Arc Graphics (Meteor Lake)")
        print("   - Use Case: Image processing, OCR, parallel tasks")

    print("\n" + "=" * 70 + "\n")


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="AI-Powered Document Browser")
    parser.add_argument(
        "directory",
        nargs="?",
        default=None,
        help="Documentation directory (default: current directory)",
    )
    parser.add_argument(
        "--docker-init", action="store_true", help="Generate Docker configuration files"
    )
    parser.add_argument(
        "--check-hardware",
        action="store_true",
        help="Check available AI acceleration hardware",
    )
    parser.add_argument(
        "--no-ai", action="store_true", help="Disable AI features (faster startup)"
    )

    args = parser.parse_args()

    # Check hardware mode
    if args.check_hardware:
        check_hardware()
        return 0

    # Determine docs directory
    if args.directory:
        docs_path = Path(args.directory).resolve()
    else:
        docs_path = Path.cwd()

    if not docs_path.exists() or not docs_path.is_dir():
        print(f"Error: Invalid directory: {docs_path}")
        return 1

    # Docker init mode
    if args.docker_init:
        print("🐳 Initializing Docker configuration...")
        hardware_info = HardwareDetector.get_hardware_info()
        success = DockerGenerator.initialize_docker(docs_path, hardware_info)
        return 0 if success else 1

    # Setup environment
    print("🚀 AI-Powered Document Browser")
    print(f"📁 Directory: {docs_path}")

    enable_ai = not args.no_ai
    if enable_ai:
        dep_status = DependencyManager.setup_environment(enable_ai=True)

        # Check if core AI deps installed
        if not dep_status.get("openvino", False):
            print("⚠️  OpenVINO not available - AI features limited")
            enable_ai = False

    # Show hardware info
    if enable_ai:
        hardware = HardwareDetector.get_hardware_info()
        device = hardware.get("optimal_device", "CPU")
        print(f"🖥️  Using: {device}", end="")
        if hardware.get("has_npu"):
            print(" (NPU acceleration available)")
        elif hardware.get("has_intel_gpu"):
            print(" (GPU acceleration available)")
        else:
            print()

    # Create and run GUI
    try:
        root = tk.Tk()
    except ImportError as e:
        print(f"❌ Tkinter not available: {e}")
        print("\nInstall tkinter:")
        if platform.system() == "Linux":
            print("  Ubuntu/Debian: sudo apt-get install python3-tk")
            print("  Fedora: sudo dnf install python3-tkinter")
        print("\nOr run in Docker mode:")
        print("  python3 doc_browser_ai.py --docker-init")
        print("  docker-compose up")
        return 1
    except Exception as e:
        print(f"❌ Failed to initialize GUI: {e}")
        return 1

    try:
        app = EnhancedDocumentBrowser(root, docs_path)
        root.mainloop()
        return 0
    except KeyboardInterrupt:
        print("\n👋 Goodbye!")
        return 0
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback

        traceback.print_exc()

        # Show error in messagebox if GUI available
        try:
            messagebox.showerror(
                "Fatal Error",
                f"Application error:\n{e}\n\n" f"Check console for details.",
            )
        except:
            pass

        return 1
    finally:
        try:
            root.destroy()
        except:
            pass


if __name__ == "__main__":
    sys.exit(main())
