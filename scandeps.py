#!/usr/bin/env python3
"""
scan_all_deps.py — AST-based recursive dependency scanner for the current directory.

• Parses imports via ast (robust to multiline/aliases)
• Skips stdlib + common junk dirs (.git, __pycache__, venv/.venv, build, dist, node_modules, etc.)
• Excludes local packages (dirs with __init__.py) by default (toggle with --include-local)
• Maps common aliases → pip dists (jwt→PyJWT, socketio→python-socketio, websocket→websocket-client, etc.)
• Optionally pins versions from the current environment (--pin)
• Heuristically expands OpenTelemetry into api+sdk if bare “opentelemetry” is found
"""
import argparse, ast, logging, os, re, sys
from typing import Dict, Iterable, List, Set, Tuple

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

IGNORE_DIRS = {'.git', '.hg', '.svn', '__pycache__', 'build', 'dist',
               '.mypy_cache', '.pytest_cache', '.ruff_cache',
               '.venv', 'venv', 'env', '.env', 'node_modules'}

# Stdlib detection
try:
    STDLIB = set(sys.stdlib_module_names)  # 3.10+
except AttributeError:
    STDLIB = set(sys.builtin_module_names)

# Alias map: module -> distribution(s)
KNOWN_ALIASES: Dict[str, Iterable[str]] = {
    # Web / APIs
    "jwt": ["PyJWT"],
    "socketio": ["python-socketio"],
    "websocket": ["websocket-client"],
    "websockets": ["websockets"],
    "prometheus_client": ["prometheus-client"],
    "importlib_metadata": ["importlib-metadata"],
    "yaml": ["PyYAML"],
    "bs4": ["beautifulsoup4"],
    "cv2": ["opencv-python"],
    "PIL": ["Pillow"],
    "dateutil": ["python-dateutil"],
    "dotenv": ["python-dotenv"],
    # Telemetry (provide sane bases)
    "opentelemetry": ["opentelemetry-api", "opentelemetry-sdk"],
    # Security/Crypto
    "Crypto": ["pycryptodome"],
    # Keep identity for known pip names (explicitly listed for clarity)
    "fastapi": ["fastapi"],
    "starlette": ["starlette"],
    "uvicorn": ["uvicorn"],
    "uvloop": ["uvloop"],
    "aiohttp": ["aiohttp"],
    "aiofiles": ["aiofiles"],
    "asyncpg": ["asyncpg"],
    "redis": ["redis"],
    "requests": ["requests"],
    "rich": ["rich"],
    "psutil": ["psutil"],
    "docker": ["docker"],
    "kubernetes": ["kubernetes"],
    "pandas": ["pandas"],
    "numpy": ["numpy"],
    "numba": ["numba"],      # may imply llvmlite runtime
    "networkx": ["networkx"],
    "lz4": ["lz4"],
    "zstandard": ["zstandard"],
    "passlib": ["passlib"],
    "bcrypt": ["bcrypt"],
    "PyYAML": ["PyYAML"],    # if someone imports as distribution name
    "scikit-learn": ["scikit-learn"],  # safety for odd cases
    # Heuristics / ambiguous; left as-is if not overridden
    "perf": ["pyperf"],      # common intent; verify if you actually use pyperf
    "mkl": ["mkl"],          # pip package exists but often conda-only; verify
}

def is_stdlib(mod: str) -> bool:
    return mod in STDLIB

def discover_local_packages(root: str) -> Set[str]:
    locals_: Set[str] = set()
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in IGNORE_DIRS and not d.startswith('.')]
        if "__init__.py" in filenames:
            pkg = os.path.basename(dirpath)
            if re.match(r'^[A-Za-z_]\w*$', pkg):
                locals_.add(pkg)
    return locals_

def extract_imports_from_file(path: str) -> Set[str]:
    mods: Set[str] = set()
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            tree = ast.parse(f.read(), filename=path)
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                for n in node.names:
                    mods.add(n.name.split(".")[0])
            elif isinstance(node, ast.ImportFrom):
                if (getattr(node, "level", 0) or not node.module):
                    # relative or from . import X → local package; skip as external
                    continue
                mods.add(node.module.split(".")[0])
    except Exception as e:
        logging.warning(f"Parse failed: {path}: {e}")
    return mods

def map_modules_to_dists(mods: Set[str], pin: bool) -> Dict[str, str]:
    """Return dist->version (version empty if not pinning or unknown)."""
    try:
        from importlib import metadata as importlib_metadata
    except Exception:
        import importlib_metadata  # type: ignore

    # Installed top-level mapping (if available)
    try:
        top_to_dists = importlib_metadata.packages_distributions() or {}
    except Exception:
        top_to_dists = {}

    reqs: Dict[str, str] = {}
    unresolved: Set[str] = set()

    for mod in sorted(mods, key=str.lower):
        dist_names: List[str] = []

        # 1) alias table
        if mod in KNOWN_ALIASES:
            val = KNOWN_ALIASES[mod]
            dist_names.extend(list(val))

        # 2) installed distributions index
        if not dist_names and top_to_dists.get(mod):
            dist_names.append(top_to_dists[mod][0])

        # 3) fallback: assume module == dist
        if not dist_names:
            dist_names.append(mod)
            unresolved.add(mod)

        for dist in dist_names:
            if dist not in reqs:
                ver = ""
                if pin:
                    try:
                        ver = importlib_metadata.version(dist)
                    except Exception:
                        # last resort: try the module name directly if different
                        if dist != mod:
                            try:
                                ver = importlib_metadata.version(mod)
                            except Exception:
                                ver = ""
                reqs[dist] = ver

    if unresolved:
        logging.warning("Unresolved modules (verify on PyPI): %s", ", ".join(sorted(unresolved)))
    return reqs

def main():
    ap = argparse.ArgumentParser(description="Scan '.' for Python deps and write requirements.txt")
    ap.add_argument("--pin", action="store_true", help="Pin versions from current environment")
    ap.add_argument("--include-local", action="store_true", help="Include local packages (dirs with __init__.py)")
    ap.add_argument("--outfile", default="requirements.txt", help="Output filename (default: requirements.txt)")
    args = ap.parse_args()

    logging.info("Scanning recursively from current directory...")
    local_pkgs = set()
    if not args.include_local:
        local_pkgs = discover_local_packages(".")
        if local_pkgs:
            logging.info("Excluding local packages: %s", ", ".join(sorted(local_pkgs)))

    all_mods: Set[str] = set()
    for dirpath, dirnames, filenames in os.walk("."):
        dirnames[:] = [d for d in dirnames if d not in IGNORE_DIRS]
        for fname in filenames:
            if fname.endswith(".py"):
                all_mods |= extract_imports_from_file(os.path.join(dirpath, fname))

    # drop stdlib + locals (unless requested)
    all_mods = {m for m in all_mods if not is_stdlib(m)}
    if local_pkgs and not args.include_local:
        all_mods = {m for m in all_mods if m not in local_pkgs}

    reqs = map_modules_to_dists(all_mods, pin=args.pin)

    lines = []
    for dist in sorted(reqs, key=str.lower):
        ver = reqs[dist]
        lines.append(f"{dist}=={ver}" if args.pin and ver else dist)

    with open(args.outfile, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + ("\n" if lines else ""))

    logging.info("Wrote %s with %d dependencies", args.outfile, len(lines))
    if args.pin:
        missing = [d for d, v in reqs.items() if not v]
        if missing:
            logging.warning("Versions not pinned (not installed?): %s", ", ".join(sorted(missing)))

if __name__ == "__main__":
    main()
