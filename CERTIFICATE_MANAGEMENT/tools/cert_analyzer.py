#!/usr/bin/env python3
"""
🔍 CERTIFICATE ANALYZER
Comprehensive X.509 certificate analysis tool
"""

import os
import sys
import re
import json
import hashlib
import argparse
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
import subprocess
from collections import defaultdict

class CertificateAnalyzer:
    """Advanced certificate analysis engine"""
    
    def __init__(self):
        self.certificates = []
        self.threats = []
        self.statistics = defaultdict(int)
        
        # Risk scoring weights
        self.risk_factors = {
            'weak_key_size': 10,
            'expired': 15,
            'self_signed': 5,
            'suspicious_cn': 20,
            'nation_state': 30,
            'critical_infrastructure': 25,
            'financial_system': 25,
            'wildcard': 10,
            'long_validity': 5,
            'weak_signature': 15
        }
        
        # Suspicious patterns
        self.suspicious_patterns = [
            r'\.gov\.cn$',
            r'\.mil$',
            r'\.gov$',
            r'swift\.com$',
            r'satellite',
            r'scada',
            r'critical',
            r'nuclear',
            r'defense'
        ]
        
        # Nation-state CAs
        self.nation_state_cas = [
            'BJCA', 'CFCA', 'GDCA', 'vTrus',  # China
            'Crypto-Pro', 'Russian Trusted',   # Russia
            'DPRK',                            # North Korea
            'IRGC'                             # Iran
        ]
    
    def parse_certificate(self, cert_text: str) -> Dict:
        """Parse X.509 certificate from OpenSSL output"""
        cert = {
            'raw': cert_text,
            'subject': '',
            'issuer': '',
            'serial': '',
            'not_before': None,
            'not_after': None,
            'signature_algorithm': '',
            'key_size': 0,
            'san': [],
            'key_usage': [],
            'is_ca': False,
            'risk_score': 0,
            'threats': []
        }
        
        # Extract fields using regex
        subject_match = re.search(r'Subject:\s*(.+)', cert_text)
        if subject_match:
            cert['subject'] = subject_match.group(1)
            
        issuer_match = re.search(r'Issuer:\s*(.+)', cert_text)
        if issuer_match:
            cert['issuer'] = issuer_match.group(1)
            
        serial_match = re.search(r'Serial Number:\s*([0-9a-f:]+)', cert_text)
        if serial_match:
            cert['serial'] = serial_match.group(1)
            
        # Parse validity dates
        not_before_match = re.search(r'Not Before:\s*(.+)', cert_text)
        if not_before_match:
            cert['not_before'] = not_before_match.group(1)
            
        not_after_match = re.search(r'Not After\s*:\s*(.+)', cert_text)
        if not_after_match:
            cert['not_after'] = not_after_match.group(1)
            
        # Signature algorithm
        sig_alg_match = re.search(r'Signature Algorithm:\s*(.+)', cert_text)
        if sig_alg_match:
            cert['signature_algorithm'] = sig_alg_match.group(1)
            
        # Key size
        key_size_match = re.search(r'Public-Key:\s*\((\d+)\s*bit\)', cert_text)
        if key_size_match:
            cert['key_size'] = int(key_size_match.group(1))
            
        # Subject Alternative Names
        san_match = re.search(r'X509v3 Subject Alternative Name:\s*\n\s*(.+)', cert_text)
        if san_match:
            cert['san'] = [s.strip() for s in san_match.group(1).split(',')]
            
        # CA flag
        if 'CA:TRUE' in cert_text:
            cert['is_ca'] = True
            
        return cert
    
    def assess_risk(self, cert: Dict) -> int:
        """Calculate risk score for certificate"""
        risk_score = 0
        threats = []
        
        # Check key size
        if cert['key_size'] > 0 and cert['key_size'] < 2048:
            risk_score += self.risk_factors['weak_key_size']
            threats.append(f"Weak key size: {cert['key_size']} bits")
            
        # Check expiration
        if cert['not_after']:
            try:
                # Simple date comparison (would need proper parsing in production)
                if '2023' in cert['not_after'] or '2022' in cert['not_after']:
                    risk_score += self.risk_factors['expired']
                    threats.append("Certificate expired or near expiration")
            except:
                pass
                
        # Check for self-signed
        if cert['subject'] == cert['issuer']:
            risk_score += self.risk_factors['self_signed']
            threats.append("Self-signed certificate")
            
        # Check for suspicious patterns
        subject_lower = cert['subject'].lower()
        for pattern in self.suspicious_patterns:
            if re.search(pattern, subject_lower):
                risk_score += self.risk_factors['suspicious_cn']
                threats.append(f"Suspicious pattern: {pattern}")
                break
                
        # Check for nation-state CAs
        for ca in self.nation_state_cas:
            if ca in cert['issuer']:
                risk_score += self.risk_factors['nation_state']
                threats.append(f"Nation-state CA: {ca}")
                break
                
        # Check for wildcards
        for san in cert['san']:
            if san.startswith('*.'):
                risk_score += self.risk_factors['wildcard']
                threats.append(f"Wildcard certificate: {san}")
                
        # Check signature algorithm
        if 'sha1' in cert['signature_algorithm'].lower():
            risk_score += self.risk_factors['weak_signature']
            threats.append("Weak signature algorithm: SHA1")
        elif 'md5' in cert['signature_algorithm'].lower():
            risk_score += self.risk_factors['weak_signature'] * 2
            threats.append("Very weak signature algorithm: MD5")
            
        cert['risk_score'] = risk_score
        cert['threats'] = threats
        
        return risk_score
    
    def analyze_file(self, filepath: str) -> List[Dict]:
        """Analyze certificates from file"""
        print(f"Analyzing {filepath}...")
        
        with open(filepath, 'r') as f:
            content = f.read()
            
        # Split by certificate boundaries
        cert_blocks = re.split(r'Certificate:', content)
        
        for block in cert_blocks[1:]:  # Skip first empty block
            cert = self.parse_certificate(block)
            self.assess_risk(cert)
            self.certificates.append(cert)
            
            # Update statistics
            self.statistics['total'] += 1
            if cert['is_ca']:
                self.statistics['ca_certs'] += 1
            if cert['risk_score'] > 30:
                self.statistics['high_risk'] += 1
            elif cert['risk_score'] > 15:
                self.statistics['medium_risk'] += 1
            else:
                self.statistics['low_risk'] += 1
                
        return self.certificates
    
    def generate_report(self, output_format: str = 'md') -> str:
        """Generate analysis report"""
        if output_format == 'md':
            return self._generate_markdown_report()
        elif output_format == 'json':
            return self._generate_json_report()
        else:
            return self._generate_text_report()
    
    def _generate_markdown_report(self) -> str:
        """Generate Markdown format report"""
        report = []
        report.append("# Certificate Analysis Report")
        report.append(f"\n**Generated**: {datetime.now().isoformat()}")
        report.append(f"\n## Summary Statistics\n")
        report.append(f"- **Total Certificates**: {self.statistics['total']}")
        report.append(f"- **CA Certificates**: {self.statistics['ca_certs']}")
        report.append(f"- **High Risk**: {self.statistics['high_risk']}")
        report.append(f"- **Medium Risk**: {self.statistics['medium_risk']}")
        report.append(f"- **Low Risk**: {self.statistics['low_risk']}")
        
        # High risk certificates
        report.append("\n## High Risk Certificates\n")
        high_risk = sorted([c for c in self.certificates if c['risk_score'] > 30], 
                          key=lambda x: x['risk_score'], reverse=True)
        
        for cert in high_risk[:10]:  # Top 10
            report.append(f"\n### Risk Score: {cert['risk_score']}")
            report.append(f"**Subject**: {cert['subject']}")
            report.append(f"**Issuer**: {cert['issuer']}")
            report.append(f"**Threats**:")
            for threat in cert['threats']:
                report.append(f"  - {threat}")
                
        # Nation-state certificates
        report.append("\n## Nation-State Certificates\n")
        nation_state = [c for c in self.certificates 
                       if any(ca in c['issuer'] for ca in self.nation_state_cas)]
        
        for cert in nation_state[:10]:
            report.append(f"\n**Subject**: {cert['subject']}")
            report.append(f"**Issuer**: {cert['issuer']}")
            report.append(f"**Risk**: {cert['risk_score']}")
            
        # Suspicious patterns
        report.append("\n## Suspicious Patterns Detected\n")
        pattern_counts = defaultdict(int)
        for cert in self.certificates:
            for threat in cert['threats']:
                if 'Suspicious pattern' in threat:
                    pattern_counts[threat] += 1
                    
        for pattern, count in sorted(pattern_counts.items(), 
                                    key=lambda x: x[1], reverse=True):
            report.append(f"- {pattern}: {count} occurrences")
            
        return '\n'.join(report)
    
    def _generate_json_report(self) -> str:
        """Generate JSON format report"""
        report = {
            'generated': datetime.now().isoformat(),
            'statistics': dict(self.statistics),
            'high_risk_certificates': [],
            'nation_state_certificates': [],
            'all_certificates': []
        }
        
        # Add high risk certs
        for cert in self.certificates:
            if cert['risk_score'] > 30:
                report['high_risk_certificates'].append({
                    'subject': cert['subject'],
                    'issuer': cert['issuer'],
                    'risk_score': cert['risk_score'],
                    'threats': cert['threats']
                })
                
        # Add nation-state certs
        for cert in self.certificates:
            if any(ca in cert['issuer'] for ca in self.nation_state_cas):
                report['nation_state_certificates'].append({
                    'subject': cert['subject'],
                    'issuer': cert['issuer'],
                    'risk_score': cert['risk_score']
                })
                
        # Add all certs summary
        for cert in self.certificates:
            report['all_certificates'].append({
                'subject': cert['subject'],
                'risk_score': cert['risk_score']
            })
            
        return json.dumps(report, indent=2)
    
    def _generate_text_report(self) -> str:
        """Generate plain text report"""
        lines = []
        lines.append("CERTIFICATE ANALYSIS REPORT")
        lines.append("=" * 50)
        lines.append(f"Generated: {datetime.now()}")
        lines.append("")
        lines.append(f"Total Certificates: {self.statistics['total']}")
        lines.append(f"High Risk: {self.statistics['high_risk']}")
        lines.append(f"Medium Risk: {self.statistics['medium_risk']}")
        lines.append(f"Low Risk: {self.statistics['low_risk']}")
        lines.append("")
        lines.append("HIGH RISK CERTIFICATES:")
        lines.append("-" * 30)
        
        high_risk = sorted([c for c in self.certificates if c['risk_score'] > 30], 
                          key=lambda x: x['risk_score'], reverse=True)
        
        for cert in high_risk[:10]:
            lines.append(f"\nRisk Score: {cert['risk_score']}")
            lines.append(f"Subject: {cert['subject']}")
            lines.append(f"Threats: {', '.join(cert['threats'])}")
            
        return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(description='Analyze X.509 certificates')
    parser.add_argument('--input', '-i', required=True, help='Input certificate file')
    parser.add_argument('--output', '-o', help='Output file (default: stdout)')
    parser.add_argument('--format', '-f', choices=['md', 'json', 'text'], 
                       default='md', help='Output format')
    parser.add_argument('--depth', '-d', choices=['basic', 'full', 'paranoid'],
                       default='full', help='Analysis depth')
    
    args = parser.parse_args()
    
    # Check input file
    if not os.path.exists(args.input):
        print(f"Error: Input file {args.input} not found")
        sys.exit(1)
        
    # Create analyzer
    analyzer = CertificateAnalyzer()
    
    # Analyze certificates
    analyzer.analyze_file(args.input)
    
    # Generate report
    report = analyzer.generate_report(args.format)
    
    # Output report
    if args.output:
        with open(args.output, 'w') as f:
            f.write(report)
        print(f"Report saved to {args.output}")
    else:
        print(report)
        
    # Print summary
    print(f"\n[Summary] Analyzed {analyzer.statistics['total']} certificates")
    print(f"High Risk: {analyzer.statistics['high_risk']}")
    print(f"Medium Risk: {analyzer.statistics['medium_risk']}")
    print(f"Low Risk: {analyzer.statistics['low_risk']}")


if __name__ == '__main__':
    main()