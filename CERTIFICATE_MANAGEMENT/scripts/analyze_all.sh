#!/bin/bash

# 🔍 ANALYZE ALL CERTIFICATES
# Comprehensive certificate analysis script

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Paths
CERT_DIR="/home/ubuntu/Documents/Claude/CERTIFICATE_MANAGEMENT"
DATA_DIR="$CERT_DIR/data"
ANALYSIS_DIR="$CERT_DIR/analysis"
TOOLS_DIR="$CERT_DIR/tools"

# Timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}    CERTIFICATE ANALYSIS SYSTEM${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo ""

# Check if data exists
if [ ! -f "$DATA_DIR/certs.txt" ]; then
    echo -e "${RED}Error: Certificate data not found at $DATA_DIR/certs.txt${NC}"
    exit 1
fi

# Create output directory
OUTPUT_DIR="$ANALYSIS_DIR/report_${TIMESTAMP}"
mkdir -p "$OUTPUT_DIR"

echo -e "${YELLOW}[1/5] Analyzing certificates...${NC}"
python3 "$TOOLS_DIR/cert_analyzer.py" \
    --input "$DATA_DIR/certs.txt" \
    --output "$OUTPUT_DIR/analysis.md" \
    --format md \
    --depth full

echo -e "${YELLOW}[2/5] Generating JSON report...${NC}"
python3 "$TOOLS_DIR/cert_analyzer.py" \
    --input "$DATA_DIR/certs.txt" \
    --output "$OUTPUT_DIR/analysis.json" \
    --format json \
    --depth full

echo -e "${YELLOW}[3/5] Extracting high-risk certificates...${NC}"
grep -A 5 "Risk Score: [4-9][0-9]" "$OUTPUT_DIR/analysis.md" > "$OUTPUT_DIR/high_risk.txt" || true

echo -e "${YELLOW}[4/5] Identifying nation-state certificates...${NC}"
grep -E "BJCA|CFCA|GDCA|vTrus|Crypto-Pro|Russian Trusted" "$DATA_DIR/certs.txt" > "$OUTPUT_DIR/nation_state.txt" || true

echo -e "${YELLOW}[5/5] Creating summary statistics...${NC}"
cat > "$OUTPUT_DIR/summary.txt" << EOF
CERTIFICATE ANALYSIS SUMMARY
Generated: $(date)
=====================================

Total Certificates: $(grep -c "Certificate:" "$DATA_DIR/certs.txt" || echo "0")

BY COUNTRY (Top 10):
$(grep "C =" "$DATA_DIR/certs.txt" | cut -d'=' -f2 | cut -d',' -f1 | sort | uniq -c | sort -rn | head -10)

BY ORGANIZATION (Top 10):
$(grep "O =" "$DATA_DIR/certs.txt" | cut -d'=' -f2 | cut -d',' -f1 | sort | uniq -c | sort -rn | head -10)

CERTIFICATE AUTHORITIES:
$(grep "CA:TRUE" "$DATA_DIR/certs.txt" | wc -l) CA certificates found

KEY SIZES:
$(grep "Public-Key:" "$DATA_DIR/certs.txt" | sort | uniq -c)

SIGNATURE ALGORITHMS:
$(grep "Signature Algorithm:" "$DATA_DIR/certs.txt" | sort | uniq -c)

HIGH RISK INDICATORS:
- Weak keys (<2048 bits): $(grep -E "Public-Key:.*\((512|1024)" "$DATA_DIR/certs.txt" | wc -l)
- SHA1 signatures: $(grep -i "sha1" "$DATA_DIR/certs.txt" | wc -l)
- Self-signed: $(grep -B2 -A2 "Issuer:.*Subject:" "$DATA_DIR/certs.txt" | grep -c "Issuer:.*Subject:" || echo "0")
EOF

echo ""
echo -e "${GREEN}✓ Analysis complete!${NC}"
echo ""
echo "Reports generated in: $OUTPUT_DIR"
echo "  - analysis.md      : Full Markdown report"
echo "  - analysis.json    : JSON format report"
echo "  - high_risk.txt    : High-risk certificates"
echo "  - nation_state.txt : Nation-state CA certificates"
echo "  - summary.txt      : Statistical summary"
echo ""

# Create symlink to latest report
ln -sfn "$OUTPUT_DIR" "$ANALYSIS_DIR/latest"
echo "Latest report linked at: $ANALYSIS_DIR/latest"

# Show high-risk count
HIGH_RISK_COUNT=$(grep -c "Risk Score: [4-9][0-9]" "$OUTPUT_DIR/analysis.md" 2>/dev/null || echo "0")
if [ "$HIGH_RISK_COUNT" -gt 0 ]; then
    echo ""
    echo -e "${RED}⚠ WARNING: $HIGH_RISK_COUNT high-risk certificates detected!${NC}"
    echo "Review: $OUTPUT_DIR/high_risk.txt"
fi