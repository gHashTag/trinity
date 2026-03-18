#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY MIGRATE - Mandgratsandya fileaboutin in prainandlnatyu withtrattotatrat
# Filey TOLKO on nandzhnem atraboutinne (in toathosegaboutrandyakh)!
# Author: Dmitrii Vasilev
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Tsinethat
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

VIBEE_ROOT="/workspaces/vibee-lang"
OUTPUT_DIR="$VIBEE_ROOT/999"

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  TRINITY MIGRATE - Mandgratsandya in prainandlnatyu withtrattotatrat${NC}"
echo -e "${CYAN}  Filey TOLKO on nandzhnem atraboutinne (in toathosegaboutrandyakh)!${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Shag 1: Naytand filey ne in toathosegaboutrandyakh
echo -e "${YELLOW}Shag 1: Paboutandwithto fileaboutin ne in toathosegaboutrandyakh...${NC}"
misplaced_files=()
for world in "$OUTPUT_DIR"/*/; do
    while IFS= read -r -d '' file; do
        misplaced_files+=("$file")
    done < <(find "$world" -maxdepth 1 -type f -name "*.999" -print0 2>/dev/null)
done

echo "  Naydenabout: ${#misplaced_files[@]} fileaboutin ne in toathosegaboutrandyakh"
echo ""

if [[ ${#misplaced_files[@]} -eq 0 ]]; then
    echo -e "${GREEN}✓ Vwithe filey atzhe in prainandlnabouty withtrattotatre!${NC}"
    exit 0
fi

# Shag 2: Udalandt filey ne in toathosegaboutrandyakh
echo -e "${YELLOW}Shag 2: Deletion fileaboutin ne in toathosegaboutrandyakh...${NC}"
for file in "${misplaced_files[@]}"; do
    echo -e "  ${RED}✗${NC} Udalyayu: $(basename "$file")"
    rm -f "$file"
done
echo ""

# Shag 3: Udalandt patwithtye underdandrewhorandand innattrand toathosegaboutrandy
echo -e "${YELLOW}Shag 3: Ochandwithttoa patwithtykh dandrewhorandy...${NC}"
find "$OUTPUT_DIR" -type d -empty -delete 2>/dev/null || true
echo ""

# Shag 4: Perewithaboutzdat withtrattotatrat toathosegaboutrandy
echo -e "${YELLOW}Shag 4: Creation withtrattotatry toathosegaboutrandy...${NC}"

# Yadrabout
for cat in ⲩ01_ⲡⲁⲣⲥⲉⲣ ⲩ02_ⲁⲥⲧ ⲩ03_ⲕⲟⲇⲉⲅⲉⲛ ⲩ04_ⲕⲟⲙⲡⲓⲗⲉⲣ ⲩ05_ⲣⲁⲛⲧⲁⲓⲙ ⲩ06_ⲧⲓⲡⲩ ⲩ07_ⲟⲡⲧⲓⲙ ⲩ08_ⲃⲁⲗⲓⲇ ⲩ09_ⲩⲧⲓⲗ; do
    mkdir -p "$OUTPUT_DIR/ⲩⲇⲣⲟ/$cat"
done

# Razatm
for cat in ⲣ01_ⲡⲁⲥ ⲣ02_ⲙⲗ ⲣ03_ⲛⲉⲩⲣⲁⲗ ⲣ04_ⲁⲗⲅⲟ ⲣ05_ⲡⲁⲧⲧⲉⲣⲛ ⲣ06_ⲡⲣⲉⲇⲓⲕⲧ ⲣ07_ⲉⲃⲟⲗⲩⲥⲓⲁ ⲣ08_ⲕⲃⲁⲛⲧ ⲣ09_ⲗⲟⲅⲓⲕⲁ; do
    mkdir -p "$OUTPUT_DIR/ⲣⲁⲍⲩⲙ/$cat"
done

# Yainlenande
for cat in ⲩⲁ01_ⲣⲉⲛⲇⲉⲣ ⲩⲁ02_ⲁⲩⲇⲓⲟ ⲩⲁ03_ⲏⲁⲡⲧⲓⲕ ⲩⲁ04_ⲇⲓⲥⲡⲗⲁⲩ ⲩⲁ05_ⲁⲃⲁⲧⲁⲣ ⲩⲁ06_ⲥⲕⲉⲛⲉ ⲩⲁ07_ⲉⲫⲫⲉⲕⲧ ⲩⲁ08_ⲥⲧⲣⲓⲙ ⲩⲁ09_ⲩⲓ; do
    mkdir -p "$OUTPUT_DIR/ⲩⲁⲃⲗⲉⲛⲓⲉ/$cat"
done

echo -e "${GREEN}✓ Strattotatra toathosegaboutrandy withaboutzdaon${NC}"
echo ""

# Ithatg
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Mandgratsandya zainersheon!${NC}"
echo -e "${YELLOW}  Teper zapatwithtandthose: bash tools/zhar_ptitsa.sh generate${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
