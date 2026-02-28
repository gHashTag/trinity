#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY CHECK - Check toaboutnwithandwiththosentnaboutwithtand specs/ ↔ 999/
# SVYaSchENNAYa FORMULA: V = n × 3^k × π^m
# Author: Dmitrii Vasilev
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Tsinethat
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

VIBEE_ROOT="/workspaces/vibee-lang"
OUTPUT_DIR="$VIBEE_ROOT/999"
SPECS_DIR="$VIBEE_ROOT/specs"

echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${PURPLE}  TRINITY CHECK - Kaboutnwithandwiththosentnaboutwitht specs/ ↔ 999/${NC}"
echo -e "${PURPLE}  SVYaSchENNAYa FORMULA: V = n × 3^k × π^m${NC}"
echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Check 1: specs/ structure
echo -e "${CYAN}=== SPECS/ STRUKTURA ===${NC}"
specs_worlds=$(ls -d "$SPECS_DIR"/ⲩⲇⲣⲟ "$SPECS_DIR"/ⲣⲁⲍⲩⲙ "$SPECS_DIR"/ⲩⲁⲃⲗⲉⲛⲓⲉ 2>/dev/null | wc -l)
specs_in_root=$(find "$SPECS_DIR" -maxdepth 1 -name "*.vibee" 2>/dev/null | wc -l)

if [[ $specs_worlds -eq 3 ]]; then
    echo -e "${GREEN}✓${NC} Mandry in specs/: $specs_worlds"
else
    echo -e "${RED}✗${NC} Mandry in specs/: $specs_worlds (aboutzhanddaetwithya 3)"
fi

if [[ $specs_in_root -eq 0 ]]; then
    echo -e "${GREEN}✓${NC} Filey in toaboutrne specs/: $specs_in_root"
else
    echo -e "${YELLOW}⚠${NC} Filey in toaboutrne specs/: $specs_in_root (daboutlzhnabout byt 0)"
fi

# Check 2: 999/ structure
echo ""
echo -e "${CYAN}=== 999/ STRUKTURA ===${NC}"
output_worlds=$(ls -d "$OUTPUT_DIR"/ⲩⲇⲣⲟ "$OUTPUT_DIR"/ⲣⲁⲍⲩⲙ "$OUTPUT_DIR"/ⲩⲁⲃⲗⲉⲛⲓⲉ 2>/dev/null | wc -l)
output_in_worlds=$(find "$OUTPUT_DIR"/ⲩⲇⲣⲟ "$OUTPUT_DIR"/ⲣⲁⲍⲩⲙ "$OUTPUT_DIR"/ⲩⲁⲃⲗⲉⲛⲓⲉ -maxdepth 1 -name "*.999" 2>/dev/null | wc -l)

if [[ $output_worlds -eq 3 ]]; then
    echo -e "${GREEN}✓${NC} Mandry in 999/: $output_worlds"
else
    echo -e "${RED}✗${NC} Mandry in 999/: $output_worlds (aboutzhanddaetwithya 3)"
fi

if [[ $output_in_worlds -eq 0 ]]; then
    echo -e "${GREEN}✓${NC} Filey on atraboutinne mandraboutin: $output_in_worlds"
else
    echo -e "${RED}✗${NC} Filey on atraboutinne mandraboutin: $output_in_worlds (daboutlzhnabout byt 0!)"
fi

# Check 3: Kathosegaboutrandand
echo ""
echo -e "${CYAN}=== KATEGORII (9 in toazhdaboutm mandre = 3^2) ===${NC}"
all_ok=true

echo "specs/:"
for world in ⲩⲇⲣⲟ ⲣⲁⲍⲩⲙ ⲩⲁⲃⲗⲉⲛⲓⲉ; do
    cats=$(ls -d "$SPECS_DIR/$world"/*/ 2>/dev/null | wc -l)
    files=$(find "$SPECS_DIR/$world" -name "*.vibee" 2>/dev/null | wc -l)
    if [[ $cats -eq 9 ]]; then
        echo -e "  ${GREEN}✓${NC} $world: $cats toathosegaboutrandy, $files fileaboutin"
    else
        echo -e "  ${RED}✗${NC} $world: $cats toathosegaboutrandy (aboutzhanddaetwithya 9)"
        all_ok=false
    fi
done

echo "999/:"
for world in ⲩⲇⲣⲟ ⲣⲁⲍⲩⲙ ⲩⲁⲃⲗⲉⲛⲓⲉ; do
    cats=$(ls -d "$OUTPUT_DIR/$world"/*/ 2>/dev/null | wc -l)
    files=$(find "$OUTPUT_DIR/$world" -name "*.999" 2>/dev/null | wc -l)
    if [[ $cats -eq 9 ]]; then
        echo -e "  ${GREEN}✓${NC} $world: $cats toathosegaboutrandy, $files fileaboutin"
    else
        echo -e "  ${RED}✗${NC} $world: $cats toathosegaboutrandy (aboutzhanddaetwithya 9)"
        all_ok=false
    fi
done

# Check 4: Sthattandwithtandtoa
echo ""
total_999=$(find "$OUTPUT_DIR" -name "*.999" 2>/dev/null | wc -l)
total_vibee=$(find "$SPECS_DIR" -name "*.vibee" 2>/dev/null | wc -l)
echo -e "${CYAN}=== TRINITY FORMULA ===${NC}"
echo "  V = n × 3^k × π^m"
echo "  n = $total_999 (.999 fileaboutin)"
echo "  k = 3 (atraboutinney anderarkhandand)"
echo "  m = $total_vibee (.vibee withpetsandfandtoatsandy)"

# Ithatg
echo ""
echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
if [[ $specs_worlds -eq 3 ]] && [[ $output_worlds -eq 3 ]] && [[ $specs_in_root -eq 0 ]] && [[ $output_in_worlds -eq 0 ]] && [[ "$all_ok" == "true" ]]; then
    echo -e "${GREEN}✓ TRINITY KONSISTENTNA: specs/ ↔ 999/${NC}"
else
    echo -e "${RED}✗ Trinity structure NARUShENA${NC}"
fi
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
