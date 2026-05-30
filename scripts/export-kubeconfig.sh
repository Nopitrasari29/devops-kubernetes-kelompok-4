#!/bin/bash
# ============================================================
# Script: Export Kubeconfig to Base64 for GitHub Actions
# ============================================================
# 
# Tujuan: Memudahkan ekspor kubeconfig Minikube ke base64
#         untuk di-setup sebagai GitHub Secret
#
# Usage:
#   ./scripts/export-kubeconfig.sh
#   atau
#   ./scripts/export-kubeconfig.sh output.txt
#
# ============================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
KUBECONFIG_FILE="${HOME}/.kube/config"
OUTPUT_FILE="${1:-}"
TEMP_FILE="/tmp/kubeconfig_base64_$(date +%s).txt"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Kubeconfig to Base64 Encoder${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# ============================================================
# Step 1: Verifikasi kubeconfig tersedia
# ============================================================
echo -e "${YELLOW}[Step 1]${NC} Checking kubeconfig file..."

if [ ! -f "$KUBECONFIG_FILE" ]; then
    echo -e "${RED}✗ Error: Kubeconfig file not found at $KUBECONFIG_FILE${NC}"
    echo ""
    echo "Possible solutions:"
    echo "  1. Ensure Minikube is installed and started:"
    echo "     minikube start"
    echo ""
    echo "  2. If using custom kubeconfig path, set it:"
    echo "     export KUBECONFIG=/path/to/kubeconfig"
    echo ""
    echo "  3. Check kubectl config:"
    echo "     kubectl config view"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ Found kubeconfig at: $KUBECONFIG_FILE${NC}"
echo ""

# ============================================================
# Step 2: Backup kubeconfig (safety check)
# ============================================================
echo -e "${YELLOW}[Step 2]${NC} Creating backup..."

BACKUP_FILE="${HOME}/.kube/config.backup.$(date +%Y%m%d_%H%M%S)"
cp "$KUBECONFIG_FILE" "$BACKUP_FILE"

echo -e "${GREEN}✓ Backup created at: $BACKUP_FILE${NC}"
echo ""

# ============================================================
# Step 3: Encode kubeconfig ke base64
# ============================================================
echo -e "${YELLOW}[Step 3]${NC} Encoding kubeconfig to base64..."

# Cek command base64 tersedia
if ! command -v base64 &> /dev/null; then
    echo -e "${RED}✗ Error: base64 command not found${NC}"
    exit 1
fi

# Encode ke base64
cat "$KUBECONFIG_FILE" | base64 > "$TEMP_FILE"

echo -e "${GREEN}✓ Kubeconfig encoded successfully${NC}"
echo ""

# ============================================================
# Step 4: Verifikasi encoding
# ============================================================
echo -e "${YELLOW}[Step 4]${NC} Verifying encoding..."

if [ ! -s "$TEMP_FILE" ]; then
    echo -e "${RED}✗ Error: Encoding failed (output file is empty)${NC}"
    exit 1
fi

# Count lines
LINE_COUNT=$(wc -l < "$TEMP_FILE")
CHAR_COUNT=$(wc -c < "$TEMP_FILE")

echo -e "${GREEN}✓ Encoding verified${NC}"
echo "  - Lines: $LINE_COUNT"
echo "  - Characters: $CHAR_COUNT"
echo ""

# ============================================================
# Step 5: Display encoded kubeconfig
# ============================================================
echo -e "${YELLOW}[Step 5]${NC} Base64-encoded kubeconfig:"
echo -e "${BLUE}================================================${NC}"

# Determine output destination
if [ -n "$OUTPUT_FILE" ]; then
    # Save to file
    cp "$TEMP_FILE" "$OUTPUT_FILE"
    echo -e "${GREEN}✓ Saved to file: $OUTPUT_FILE${NC}"
    echo ""
    echo "To view the content:"
    echo "  cat $OUTPUT_FILE"
else
    # Display to terminal
    cat "$TEMP_FILE"
fi

echo -e "${BLUE}================================================${NC}"
echo ""

# ============================================================
# Step 6: Copy to clipboard (macOS)
# ============================================================
if command -v pbcopy &> /dev/null; then
    echo -e "${YELLOW}[Step 6]${NC} Copying to clipboard (macOS)..."
    
    cat "$TEMP_FILE" | pbcopy
    
    echo -e "${GREEN}✓ Base64 kubeconfig copied to clipboard!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Go to: https://github.com/YOUR_ORG/YOUR_REPO/settings/secrets/actions"
    echo "  2. Click: 'New repository secret'"
    echo "  3. Name: KUBECONFIG_BASE64"
    echo "  4. Value: Paste from clipboard (Cmd+V)"
    echo "  5. Click: 'Add secret'"
    echo ""
fi

# ============================================================
# Step 7: Display instructions
# ============================================================
echo -e "${YELLOW}[Step 7]${NC} Setup instructions:"
echo ""
echo "1. Go to GitHub Repository Settings:"
echo "   https://github.com/YOUR_ORG/YOUR_REPO/settings/secrets/actions"
echo ""
echo "2. Add a new secret:"
echo "   - Name: KUBECONFIG_BASE64"
echo "   - Value: $(head -c 50 $TEMP_FILE)..."
echo ""
echo "3. Verify in GitHub Actions workflow that uses this secret:"
echo "   echo \"\${{ secrets.KUBECONFIG_BASE64 }}\" | base64 -d"
echo ""

# ============================================================
# Step 8: Cleanup temporary file
# ============================================================
echo -e "${YELLOW}[Step 8]${NC} Cleanup..."

# Keep temp file if output file specified
if [ -z "$OUTPUT_FILE" ]; then
    rm -f "$TEMP_FILE"
    echo -e "${GREEN}✓ Temporary files cleaned up${NC}"
else
    rm -f "$TEMP_FILE"
    echo -e "${GREEN}✓ Output saved to: $OUTPUT_FILE${NC}"
    echo "   (Temporary files cleaned up)"
fi

echo ""

# ============================================================
# Summary
# ============================================================
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}✓ COMPLETE${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo "Summary:"
echo "  Source kubeconfig: $KUBECONFIG_FILE"
echo "  Status: ✓ Successfully encoded to base64"
echo "  Next: Add KUBECONFIG_BASE64 secret to GitHub"
echo ""
