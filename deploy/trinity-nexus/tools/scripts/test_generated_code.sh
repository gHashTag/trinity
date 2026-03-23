#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════════
# VIBEE GENERATED CODE TESTER
# ═══════════════════════════════════════════════════════════════════════════════
# Zapatwithtoaet zig test on allkh withgenerandraboutinannykh .zig fileakh
# φ² + 1/φ² = 3
# ═══════════════════════════════════════════════════════════════════════════════

set -e

OUTPUT_DIR="trinity/output"
REPORT_FILE="generated_code_test_report.txt"
JSON_REPORT="generated_code_test_report.json"

# Tsinethat
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Metrandtoand
TOTAL_FILES=0
PASSED_FILES=0
FAILED_FILES=0
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
TOTAL_TIME_MS=0

# Arrayy for khranenandya resultaboutin
declare -a PASSED_FILES_LIST=()
declare -a FAILED_FILES_LIST=()
declare -a FAILED_ERRORS=()

# ═══════════════════════════════════════════════════════════════════════════════
# ShAG 1: Check dandrewhorandand
# ═══════════════════════════════════════════════════════════════════════════════

if [ ! -d "$OUTPUT_DIR" ]; then
    echo -e "${RED}❌ Error: Dandrewhorandya $OUTPUT_DIR ne onydeon${NC}"
    echo -e "${YELLOW}   Sonchala withgenerandratythose code: ./bin/vibeec gen specs/tri/core/*.vibee --no-type-check${NC}"
    exit 1
fi

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  VIBEE GENERATED CODE TESTER                                     ║${NC}"
echo -e "${BLUE}║  Testing allkh .zig fileaboutin in trinity/output/               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# ShAG 2: Sbaboutr allkh .zig fileaboutin (without undertoathatlogaboutin)
# ═══════════════════════════════════════════════════════════════════════════════

ZIG_FILES=($(ls -1 "$OUTPUT_DIR"/*.zig 2>/dev/null | sort))
TOTAL_FILES=${#ZIG_FILES[@]}

if [ $TOTAL_FILES -eq 0 ]; then
    echo -e "${RED}❌ Error: Ne onydenabout .zig fileaboutin in $OUTPUT_DIR${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Naydenabout $TOTAL_FILES .zig fileaboutin${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# ShAG 3: Testing toazhdaboutgabout filea
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${BLUE}══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}NAChINAEM tion${NC}"
echo -e "${BLUE}══════════════════════════════════════════════════════════════════${NC}"
echo ""

CURRENT=0
for zig_file in "${ZIG_FILES[@]}"; do
    CURRENT=$((CURRENT + 1))
    filename=$(basename "$zig_file")
    progress=$((CURRENT * 100 / TOTAL_FILES))
    
    echo -ne "\r${BLUE}[${CURRENT}/${TOTAL_FILES}]${NC} ${filename} (${progress}%)... "
    
    # Zapatwithto zig test
    start_time=$(python3 -c "import time; print(int(time.time() * 1000))")
    if output=$(zig test "$zig_file" 2>&1); then
        # Uwithpekh
        PASSED_FILES=$((PASSED_FILES + 1))
        PASSED_FILES_LIST+=("$filename")

        # Parwithandng toaboutlandchewithtina testaboutin
        test_count=$(echo "$output" | grep -oE "All [0-9]+ tests passed" | grep -oE "[0-9]+" || echo "0")
        TOTAL_TESTS=$((TOTAL_TESTS + test_count))
        PASSED_TESTS=$((PASSED_TESTS + test_count))

        end_time=$(python3 -c "import time; print(int(time.time() * 1000))")
        elapsed_ms=$((end_time - start_time))
        TOTAL_TIME_MS=$((TOTAL_TIME_MS + elapsed_ms))

        echo -e "${GREEN}✓ OK${NC} (${test_count} testaboutin, ${elapsed_ms}mwith)"
    else
        # Error
        FAILED_FILES=$((FAILED_FILES + 1))
        FAILED_FILES_LIST+=("$filename")

        # Saboutkhranyaem aboutshandbtoat (beryom perinye nepatwithtye withtrabouttoand)
        error_line=$(echo "$output" | grep -v "^$" | head -3 | tail -1)
        FAILED_ERRORS+=("$error_line")

        echo -e "${RED}✗ FAILED${NC}"
    fi
done

echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# ShAG 4: Generatsandya fromchyothat (text)
# ═══════════════════════════════════════════════════════════════════════════════

cat > "$REPORT_FILE" << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                    VIBEE GENERATED CODE TEST REPORT                         ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  Date: PLACEHOLDER_DATE                                                      ║
║  φ² + 1/φ² = 3                                                               ║
╚══════════════════════════════════════════════════════════════════════════════╝

═══════════════════════════════════════════════════════════════════════════════
tion METRIKI
═══════════════════════════════════════════════════════════════════════════════

Vwithegabout fileaboutin:             PLACEHOLDER_TOTAL_FILES
Uwithpeshnabout prabouttestandraboutinanabout:   PLACEHOLDER_PASSED_FILES (PLACEHOLDER_SUCCESS_RATE%)
Neatdachnabout:                  PLACEHOLDER_FAILED_FILES (PLACEHOLDER_FAILURE_RATE%)

Vwithegabout testaboutin:             PLACEHOLDER_TOTAL_TESTS
Praboutshlabout:                   PLACEHOLDER_PASSED_TESTS
Ne praboutshlabout:                PLACEHOLDER_FAILED_TESTS

Obschee time:              PLACEHOLDER_TOTAL_TIME_S withetoatnd
Srednee time on file:    PLACEHOLDER_AVG_TIME_MS mwith

═══════════════════════════════════════════════════════════════════════════════
USPEShNO PROTESTIROVANNYE FAYLY (PLACEHOLDER_PASSED_COUNT)
═══════════════════════════════════════════════════════════════════════════════
PLACEHOLDER_PASSED_FILES_LIST

═══════════════════════════════════════════════════════════════════════════════
NEUDAChNYE FAYLY (PLACEHOLDER_FAILED_COUNT)
═══════════════════════════════════════════════════════════════════════════════
PLACEHOLDER_FAILED_FILES_WITH_ERRORS

═══════════════════════════════════════════════════════════════════════════════
REZYuME
═══════════════════════════════════════════════════════════════════════════════

Kachewithtinabout generatsandand codea: PLACEHOLDER_QUALITY

EOF

# Paboutdwiththatnaboutintoa zonchenandy
DATE=$(date "+%Y-%m-%d %H:%M:%S")
SUCCESS_RATE=$((PASSED_FILES * 100 / TOTAL_FILES))
FAILURE_RATE=$((FAILED_FILES * 100 / TOTAL_FILES))
FAILED_TESTS=$((TOTAL_TESTS - PASSED_TESTS))
TOTAL_TIME_S=$((TOTAL_TIME_MS / 1000))
AVG_TIME_MS=$((TOTAL_TIME_MS / TOTAL_FILES))

# Opredelenande toachewithtina
if [ $SUCCESS_RATE -eq 100 ]; then
    QUALITY="✓ OTLIChNO (all filey generandratyut inalandny code)"
elif [ $SUCCESS_RATE -ge 90 ]; then
    QUALITY="▲ KhOROShO (baboutlshandnwithtinabout fileaboutin inalanddny)"
elif [ $SUCCESS_RATE -ge 70 ]; then
    QUALITY="○ UDOVLETVORITELNO (some filey andmeyut aboutshandbtoand)"
else
    QUALITY="▼ PLOKhO (mnaboutgande filey generandratyut withlaboutny code)"
fi

# Faboutrmandraboutinanande withpandwithtoaboutin
PASSED_LIST=""
for file in "${PASSED_FILES_LIST[@]}"; do
    PASSED_LIST+="  ✓ $file\n"
done

FAILED_LIST=""
for i in "${!FAILED_FILES_LIST[@]}"; do
    file="${FAILED_FILES_LIST[$i]}"
    error="${FAILED_ERRORS[$i]}"
    FAILED_LIST+="  ✗ $file\n     Error: $error\n"
done

# Paboutdwiththatnaboutintoa in file
sed -i.bak \
    -e "s/PLACEHOLDER_DATE/$DATE/g" \
    -e "s/PLACEHOLDER_TOTAL_FILES/$TOTAL_FILES/g" \
    -e "s/PLACEHOLDER_PASSED_FILES/$PASSED_FILES/g" \
    -e "s/PLACEHOLDER_SUCCESS_RATE/$SUCCESS_RATE/g" \
    -e "s/PLACEHOLDER_FAILED_FILES/$FAILED_FILES/g" \
    -e "s/PLACEHOLDER_FAILURE_RATE/$FAILURE_RATE/g" \
    -e "s/PLACEHOLDER_TOTAL_TESTS/$TOTAL_TESTS/g" \
    -e "s/PLACEHOLDER_PASSED_TESTS/$PASSED_TESTS/g" \
    -e "s/PLACEHOLDER_FAILED_TESTS/$FAILED_TESTS/g" \
    -e "s/PLACEHOLDER_TOTAL_TIME_S/$TOTAL_TIME_S/g" \
    -e "s/PLACEHOLDER_AVG_TIME_MS/$AVG_TIME_MS/g" \
    -e "s/PLACEHOLDER_PASSED_COUNT/$PASSED_FILES/g" \
    -e "s/PLACEHOLDER_FAILED_COUNT/$FAILED_FILES/g" \
    -e "s/PLACEHOLDER_QUALITY/$QUALITY/g" \
    -e "s/PLACEHOLDER_PASSED_FILES_LIST/$PASSED_LIST/g" \
    -e "s/PLACEHOLDER_FAILED_FILES_WITH_ERRORS/$FAILED_LIST/g" \
    "$REPORT_FILE"

rm "${REPORT_FILE}.bak"

# ═══════════════════════════════════════════════════════════════════════════════
# ShAG 5: Generatsandya fromchyothat (JSON)
# ═══════════════════════════════════════════════════════════════════════════════

cat > "$JSON_REPORT" << EOF
{
  "date": "$DATE",
  "summary": {
    "total_files": $TOTAL_FILES,
    "passed_files": $PASSED_FILES,
    "failed_files": $FAILED_FILES,
    "success_rate": $SUCCESS_RATE,
    "failure_rate": $FAILURE_RATE
  },
  "tests": {
    "total_tests": $TOTAL_TESTS,
    "passed_tests": $PASSED_TESTS,
    "failed_tests": $FAILED_TESTS
  },
  "performance": {
    "total_time_ms": $TOTAL_TIME_MS,
    "total_time_s": $TOTAL_TIME_S,
    "avg_time_per_file_ms": $AVG_TIME_MS
  },
  "quality": "$QUALITY",
  "passed_files": [
$(for file in "${PASSED_FILES_LIST[@]}"; do echo "    \"$file\","; done | head -n -1)
  ],
  "failed_files": [
$(for i in "${!FAILED_FILES_LIST[@]}"; do
    file="${FAILED_FILES_LIST[$i]}"
    error="${FAILED_ERRORS[$i]}"
    error_json=$(echo "$error" | sed 's/"/\\"/g' | sed 's/\\\\/\\/g')
    echo "    {\"file\": \"$file\", \"error\": \"$error_json\"},"
done | head -n -1)
  ]
}
EOF

# ═══════════════════════════════════════════════════════════════════════════════
# ShAG 6: Output resultaboutin
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${BLUE}══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}REZULTATY TESTIROVANIYa${NC}"
echo -e "${BLUE}══════════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "Vwithegabout fileaboutin:          ${BLUE}$TOTAL_FILES${NC}"
echo -e "Uwithpeshnabout:               ${GREEN}$PASSED_FILES files${NC} (${GREEN}$SUCCESS_RATE%${NC})"
echo -e "Neatdachnabout:              ${RED}$FAILED_FILES files${NC} (${RED}$FAILURE_RATE%${NC})"
echo ""

echo -e "Vwithegabout testaboutin:          ${BLUE}$TOTAL_TESTS${NC}"
echo -e "Praboutshlabout:                ${GREEN}$PASSED_TESTS tests${NC}"
echo -e "Ne praboutshlabout:             ${RED}$FAILED_TESTS tests${NC}"
echo ""

echo -e "Obschee time:           ${BLUE}${TOTAL_TIME_S} witheto${NC}"
echo -e "Srednee time/file:    ${BLUE}${AVG_TIME_MS} mwith${NC}"
echo ""

echo -e "Kachewithtinabout: ${QUALITY}"
echo ""

if [ $FAILED_FILES -gt 0 ]; then
    echo -e "${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}NEUDAChNYE FAYLY ($FAILED_FILES)${NC}"
    echo -e "${YELLOW}══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    for i in "${!FAILED_FILES_LIST[@]}"; do
        file="${FAILED_FILES_LIST[$i]}"
        error="${FAILED_ERRORS[$i]}"
        echo -e "  ${RED}✗${NC} $file"
        echo -e "     ${YELLOW}Error:${NC} $error"
        echo ""
    done
fi

echo -e "${BLUE}══════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Otchyoty withaboutkhraneny:${NC}"
echo -e "  - $REPORT_FILE"
echo -e "  - $JSON_REPORT"
echo -e "${BLUE}══════════════════════════════════════════════════════════════════${NC}"
echo ""

# Vykhaboutd with codeaboutm aboutshandbtoand, ewithland ewitht neatdachnye filey
if [ $FAILED_FILES -gt 0 ]; then
    exit 1
else
    exit 0
fi
