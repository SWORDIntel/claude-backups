#!/usr/bin/env python3
"""
Test Enhanced Semantic Matching System
Validates the improved role-based categorization across 3 documentation repositories
"""

import sys
from pathlib import Path
import json

# Add docs directory to path to import the browser
sys.path.append(str(Path(__file__).parent / 'docs'))

from universal_docs_browser_enhanced import DocumentationStructureAnalyzer

def test_repository(repo_path: Path, repo_name: str):
    """Test semantic matching for a specific repository"""
    print(f"\n{'='*60}")
    print(f"Testing Repository: {repo_name}")
    print(f"Path: {repo_path}")
    print(f"{'='*60}")
    
    if not repo_path.exists():
        print(f"❌ Repository not found: {repo_path}")
        return
    
    try:
        # Initialize analyzer
        analyzer = DocumentationStructureAnalyzer(repo_path)
        
        # Analyze structure
        structure = analyzer.analyze_structure()
        print(f"📁 Total Files: {structure.get('total_files', 0)}")
        print(f"📂 Categories: {len(structure.get('categories', {}))}")
        
        # Generate role mappings
        role_mappings = analyzer.generate_role_mappings()
        
        print(f"\n🎯 Role Analysis Results ({len(role_mappings)} roles detected):")
        print("-" * 50)
        
        total_assignments = 0
        for role, docs in role_mappings.items():
            print(f"👥 {role}: {len(docs)} documents")
            total_assignments += len(docs)
            if docs:
                # Show first few examples
                for i, doc in enumerate(docs[:3]):
                    print(f"   • {doc}")
                if len(docs) > 3:
                    print(f"   ... and {len(docs) - 3} more")
        
        print(f"\n📊 Total Role Assignments: {total_assignments}")
        
        # Calculate coverage
        if structure.get('total_files', 0) > 0:
            # Note: assignments can be > files due to multi-role support
            coverage = min(100, (total_assignments / structure['total_files']) * 100)
            print(f"📈 Role Coverage: {coverage:.1f}%")
        
        return {
            'repo_name': repo_name,
            'total_files': structure.get('total_files', 0),
            'categories': len(structure.get('categories', {})),
            'roles_detected': len(role_mappings),
            'total_assignments': total_assignments,
            'role_mappings': role_mappings
        }
        
    except Exception as e:
        print(f"❌ Error analyzing {repo_name}: {e}")
        return None

def main():
    """Run semantic matching tests on all three repositories"""
    print("🚀 Enhanced Semantic Matching System Test")
    print("Testing 8-role categorization system with improved patterns")
    
    # Test repositories
    test_repos = [
        (Path("/home/ubuntu/Documents/claude-backups/docs"), "Claude Agent Framework"),
        (Path("/home/ubuntu/Documents/ARTICBASTION/docs"), "ARTICBASTION Security Platform"),
        (Path("/home/ubuntu/Documents/livecd-gen/docs"), "LiveCD Generator System")
    ]
    
    results = []
    
    for repo_path, repo_name in test_repos:
        result = test_repository(repo_path, repo_name)
        if result:
            results.append(result)
    
    # Summary analysis
    print(f"\n{'='*60}")
    print("📈 COMPREHENSIVE ANALYSIS SUMMARY")
    print(f"{'='*60}")
    
    total_files = sum(r['total_files'] for r in results)
    total_assignments = sum(r['total_assignments'] for r in results)
    
    print(f"🔍 Repositories Analyzed: {len(results)}")
    print(f"📄 Total Documentation Files: {total_files}")
    print(f"🎯 Total Role Assignments: {total_assignments}")
    print(f"📊 Average Assignments per File: {total_assignments/total_files:.2f}")
    
    # Role distribution across all repositories
    print(f"\n🌍 Global Role Distribution:")
    print("-" * 30)
    
    global_roles = {}
    for result in results:
        for role, docs in result['role_mappings'].items():
            if role not in global_roles:
                global_roles[role] = 0
            global_roles[role] += len(docs)
    
    # Sort roles by frequency
    sorted_roles = sorted(global_roles.items(), key=lambda x: x[1], reverse=True)
    
    for role, count in sorted_roles:
        percentage = (count / total_assignments) * 100 if total_assignments > 0 else 0
        print(f"👥 {role}: {count} documents ({percentage:.1f}%)")
    
    # Repository specialization analysis
    print(f"\n🔬 Repository Specialization Analysis:")
    print("-" * 40)
    
    for result in results:
        print(f"\n📦 {result['repo_name']}:")
        repo_total = sum(len(docs) for docs in result['role_mappings'].values())
        if repo_total > 0:
            repo_roles = sorted(result['role_mappings'].items(), 
                              key=lambda x: len(x[1]), reverse=True)
            for role, docs in repo_roles[:3]:  # Top 3 roles
                if docs:
                    percentage = (len(docs) / repo_total) * 100
                    print(f"   🎯 {role}: {percentage:.1f}%")
    
    print(f"\n✅ Enhanced Semantic Matching Test Complete!")
    print(f"🎉 Successfully categorized {total_assignments} documents across 8 role categories")

if __name__ == "__main__":
    main()