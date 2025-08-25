#!/usr/bin/env python3
"""
PDF Text Extractor with TUI
Extract text from born-digital PDFs with a terminal user interface
"""

import os
import sys
from pathlib import Path
from typing import List, Optional
import textwrap

# Check for required packages
try:
    import pdfplumber
except ImportError:
    print("Error: pdfplumber not installed")
    print("Install with: pip install pdfplumber")
    sys.exit(1)

try:
    from rich.console import Console
    from rich.table import Table
    from rich.panel import Panel
    from rich.prompt import Prompt, IntPrompt
    from rich.progress import Progress, SpinnerColumn, TextColumn
    from rich.syntax import Syntax
    from rich.text import Text
    RICH_AVAILABLE = True
except ImportError:
    RICH_AVAILABLE = False
    print("Warning: 'rich' library not installed for enhanced UI")
    print("Install with: pip install rich")
    print("Falling back to basic interface...\n")

def get_pdf_files(directory: str = ".") -> List[Path]:
    """Get all PDF files in the specified directory."""
    path = Path(directory)
    pdf_files = sorted(path.glob("*.pdf"))
    return pdf_files

def extract_text_pdfplumber(pdf_path: Path) -> str:
    """Extract text from PDF using pdfplumber (better for born-digital PDFs)."""
    text_content = []
    
    try:
        with pdfplumber.open(pdf_path) as pdf:
            total_pages = len(pdf.pages)
            
            for i, page in enumerate(pdf.pages, 1):
                if RICH_AVAILABLE:
                    console.print(f"[cyan]Processing page {i}/{total_pages}...[/cyan]", end="\r")
                else:
                    print(f"Processing page {i}/{total_pages}...", end="\r")
                
                page_text = page.extract_text()
                if page_text:
                    text_content.append(f"\n--- Page {i} ---\n")
                    text_content.append(page_text)
            
            if RICH_AVAILABLE:
                console.print(" " * 50, end="\r")  # Clear the line
    except Exception as e:
        error_msg = f"Error reading PDF: {str(e)}"
        if RICH_AVAILABLE:
            console.print(f"[red]{error_msg}[/red]")
        else:
            print(error_msg)
        return ""
    
    return "\n".join(text_content)

def save_text(text: str, original_path: Path, output_dir: str = ".") -> Path:
    """Save extracted text to a file."""
    output_path = Path(output_dir) / f"{original_path.stem}_extracted.txt"
    
    try:
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(text)
        return output_path
    except Exception as e:
        raise Exception(f"Error saving file: {str(e)}")

def display_pdf_list_rich(pdf_files: List[Path]) -> Optional[Path]:
    """Display PDF list using rich library with enhanced UI."""
    console.clear()
    
    # Header
    header = Panel.fit(
        "[bold cyan]PDF Text Extractor[/bold cyan]\n"
        "[dim]Select a PDF file to extract text[/dim]",
        border_style="cyan"
    )
    console.print(header)
    console.print()
    
    if not pdf_files:
        console.print("[yellow]No PDF files found in current directory.[/yellow]")
        return None
    
    # Create table
    table = Table(show_header=True, header_style="bold magenta", 
                  border_style="cyan", show_lines=True)
    table.add_column("#", style="cyan", width=4)
    table.add_column("Filename", style="white", width=40)
    table.add_column("Size", justify="right", style="green", width=10)
    table.add_column("Pages", justify="center", style="yellow", width=8)
    
    # Add files to table
    for idx, pdf_file in enumerate(pdf_files, 1):
        size = pdf_file.stat().st_size
        size_str = format_file_size(size)
        
        # Try to get page count
        page_count = "?"
        try:
            with pdfplumber.open(pdf_file) as pdf:
                page_count = str(len(pdf.pages))
        except:
            pass
        
        table.add_row(
            str(idx),
            pdf_file.name[:40],
            size_str,
            page_count
        )
    
    console.print(table)
    console.print()
    
    # Get user choice
    console.print("[bold]Options:[/bold]")
    console.print("  • Enter a number to select a PDF")
    console.print("  • Enter 'q' to quit")
    console.print()
    
    choice = Prompt.ask("[bold cyan]Your choice[/bold cyan]")
    
    if choice.lower() == 'q':
        return None
    
    try:
        idx = int(choice) - 1
        if 0 <= idx < len(pdf_files):
            return pdf_files[idx]
        else:
            console.print("[red]Invalid selection. Please try again.[/red]")
            console.input("\nPress Enter to continue...")
            return display_pdf_list_rich(pdf_files)
    except ValueError:
        console.print("[red]Invalid input. Please enter a number or 'q'.[/red]")
        console.input("\nPress Enter to continue...")
        return display_pdf_list_rich(pdf_files)

def display_pdf_list_basic(pdf_files: List[Path]) -> Optional[Path]:
    """Display PDF list using basic terminal interface."""
    print("\n" + "="*50)
    print("PDF TEXT EXTRACTOR")
    print("="*50 + "\n")
    
    if not pdf_files:
        print("No PDF files found in current directory.")
        return None
    
    print("Available PDF files:\n")
    for idx, pdf_file in enumerate(pdf_files, 1):
        size = pdf_file.stat().st_size
        size_str = format_file_size(size)
        print(f"  [{idx}] {pdf_file.name} ({size_str})")
    
    print("\nOptions:")
    print("  • Enter a number to select a PDF")
    print("  • Enter 'q' to quit\n")
    
    choice = input("Your choice: ").strip()
    
    if choice.lower() == 'q':
        return None
    
    try:
        idx = int(choice) - 1
        if 0 <= idx < len(pdf_files):
            return pdf_files[idx]
        else:
            print("\nInvalid selection. Please try again.")
            input("Press Enter to continue...")
            return display_pdf_list_basic(pdf_files)
    except ValueError:
        print("\nInvalid input. Please enter a number or 'q'.")
        input("Press Enter to continue...")
        return display_pdf_list_basic(pdf_files)

def format_file_size(size_bytes: int) -> str:
    """Format file size in human-readable format."""
    for unit in ['B', 'KB', 'MB', 'GB']:
        if size_bytes < 1024.0:
            return f"{size_bytes:.1f} {unit}"
        size_bytes /= 1024.0
    return f"{size_bytes:.1f} TB"

def display_extraction_result(text: str, output_path: Path, pdf_name: str):
    """Display the extraction result with preview."""
    if RICH_AVAILABLE:
        console.print("\n[green]✓ Extraction Complete![/green]\n")
        
        # Statistics
        stats_table = Table(show_header=False, border_style="green", show_edge=False)
        stats_table.add_column("Property", style="cyan")
        stats_table.add_column("Value", style="white")
        
        stats_table.add_row("Source PDF:", pdf_name)
        stats_table.add_row("Output file:", str(output_path))
        stats_table.add_row("Characters extracted:", f"{len(text):,}")
        stats_table.add_row("Lines extracted:", f"{len(text.splitlines()):,}")
        
        console.print(Panel(stats_table, title="[bold]Extraction Summary[/bold]", 
                           border_style="green"))
        
        # Preview
        console.print("\n[bold]Text Preview (first 500 characters):[/bold]")
        preview = text[:500] + "..." if len(text) > 500 else text
        console.print(Panel(preview, border_style="dim"))
    else:
        print("\n✓ Extraction Complete!\n")
        print(f"Source PDF: {pdf_name}")
        print(f"Output file: {output_path}")
        print(f"Characters extracted: {len(text):,}")
        print(f"Lines extracted: {len(text.splitlines()):,}")
        print("\n" + "-"*50)
        print("Text Preview (first 500 characters):")
        print("-"*50)
        preview = text[:500] + "..." if len(text) > 500 else text
        print(preview)
        print("-"*50)

def main():
    """Main function to run the PDF text extractor."""
    global console
    
    if RICH_AVAILABLE:
        console = Console()
    
    while True:
        # Get PDF files in current directory
        pdf_files = get_pdf_files()
        
        # Display file list and get selection
        if RICH_AVAILABLE:
            selected_pdf = display_pdf_list_rich(pdf_files)
        else:
            selected_pdf = display_pdf_list_basic(pdf_files)
        
        if selected_pdf is None:
            if RICH_AVAILABLE:
                console.print("\n[yellow]Exiting...[/yellow]")
            else:
                print("\nExiting...")
            break
        
        # Extract text
        if RICH_AVAILABLE:
            console.print(f"\n[cyan]Extracting text from: {selected_pdf.name}[/cyan]\n")
            
            with Progress(
                SpinnerColumn(),
                TextColumn("[progress.description]{task.description}"),
                console=console
            ) as progress:
                task = progress.add_task("Extracting text...", total=None)
                extracted_text = extract_text_pdfplumber(selected_pdf)
                progress.update(task, completed=100)
        else:
            print(f"\nExtracting text from: {selected_pdf.name}\n")
            extracted_text = extract_text_pdfplumber(selected_pdf)
        
        if not extracted_text:
            if RICH_AVAILABLE:
                console.print("[red]No text could be extracted from this PDF.[/red]")
            else:
                print("No text could be extracted from this PDF.")
        else:
            # Save extracted text
            try:
                output_path = save_text(extracted_text, selected_pdf)
                display_extraction_result(extracted_text, output_path, selected_pdf.name)
            except Exception as e:
                if RICH_AVAILABLE:
                    console.print(f"[red]Error saving file: {str(e)}[/red]")
                else:
                    print(f"Error saving file: {str(e)}")
        
        # Ask if user wants to continue
        if RICH_AVAILABLE:
            another = Prompt.ask("\n[cyan]Extract another PDF? (y/n)[/cyan]", 
                               choices=["y", "n"], default="n")
        else:
            another = input("\nExtract another PDF? (y/n): ").strip().lower()
        
        if another != 'y':
            if RICH_AVAILABLE:
                console.print("\n[green]Thank you for using PDF Text Extractor![/green]")
            else:
                print("\nThank you for using PDF Text Extractor!")
            break

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        if RICH_AVAILABLE:
            console.print("\n\n[yellow]Interrupted by user.[/yellow]")
        else:
            print("\n\nInterrupted by user.")
        sys.exit(0)
    except Exception as e:
        if RICH_AVAILABLE:
            console.print(f"\n[red]Unexpected error: {str(e)}[/red]")
        else:
            print(f"\nUnexpected error: {str(e)}")
        sys.exit(1)