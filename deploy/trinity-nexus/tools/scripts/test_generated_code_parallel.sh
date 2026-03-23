#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════════
# VIBEE GENERATED CODE TESTER (PARALLEL)
# ═══════════════════════════════════════════════════════════════════════════════
# Parallelnaboute testing allkh .zig fileaboutin with GNU parallel
# φ² + 1/φ² = 3
# ═══════════════════════════════════════════════════════════════════════════════

set -e

OUTPUT_DIR="trinity/output"
REPORT_FILE="generated_code_test_report_parallel.txt"
JSON_REPORT="generated_code_test_report_parallel.json"

# Kaboutlandchewithtinabout pairllelnykh processaboutin (by atmaboutlchanandyu = toaboutl-inabout yader)
PARALLEL_JOBS=${1:-$(nproc)}
if [ -z "$PARALLEL_JOBS" ] || [ "$PARALLEL_JOBS" -lt 1 ]; then
    PARALLEL_JOBS=4
fi

# Tsinethat
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Emaboutdzand
EMOJI_SUCCESS="✅"
EMOJI_ERROR="❌"
EMOJI_WARNING="⚠️"
EMOJI_INFO="ℹ️"
EMOJI_ROCKET="🚀"
EMOJI_CHART="📊"
EMOJI_TIME="⏱️"
EMOJI_FILE="📁"

# ═══════════════════════════════════════════════════════════════════════════════
# ka GNU PARALLEL
# ═══════════════════════════════════════════════════════════════════════════════

if ! command -v parallel &> /dev/null; then
    echo -e "${RED}❌ Error: GNU parallel ne onyden${NC}"
    echo -e "${YELLOW}   Uwiththatnaboutinandthose:${NC}"
    echo -e "${YELLOW}   brew install parallel  (macOS)${NC}"
    echo -e "${YELLOW}   apt install parallel  (Ubuntu/Debian)${NC}"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════════════════════
# ka DIREKTORII
# ═══════════════════════════════════════════════════════════════════════════════

if [ ! -d "$OUTPUT_DIR" ]; then
    echo -e "${RED}❌ Error: Dandrewhorandya $OUTPUT_DIR ne onydeon${NC}"
    exit 1
fi

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║  🚀 VIBEE GENERATED CODE TESTER (PARALLEL)               ║${NC}"
echo -e "${CYAN}║  Parallelnaboute testing with ${BOLD}$PARALLEL_JOBS${NC}${CYAN} threadamand              ║${NC}"
echo -e "${CYAN}║  φ² + 1/φ² = 3                                               ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# SBOR FAYLOV
# ═══════════════════════════════════════════════════════════════════════════════

ZIG_FILES=($(ls -1 "$OUTPUT_DIR"/*.zig 2>/dev/null | sort))
TOTAL_FILES=${#ZIG_FILES[@]}

if [ $TOTAL_FILES -eq 0 ]; then
    echo -e "${RED}${EMOJI_ERROR} ${BOLD}Error: Ne onydenabout .zig fileaboutin in $OUTPUT_DIR${NC}"
    exit 1
fi

echo -e "${GREEN}${EMOJI_SUCCESS} ${BOLD}Naydenabout $TOTAL_FILES .zig fileaboutin${NC}"
echo -e "${CYAN}${EMOJI_ROCKET} ${BOLD}Zapatwithto pairllelnaboutgabout testandraboutinanandya ($PARALLEL_JOBS threadaboutin)${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# PARALLELNOE tion
# ═══════════════════════════════════════════════════════════════════════════════

# Saboutzdayom inremennatyu dandrewhorandyu for resultaboutin
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

# Zapatwithtoaem testing pairllelnabout
start_time=$(python3 -c "import time; print(int(time.time() * 1000))")

ls -1 "$OUTPUT_DIR"/*.zig 2>/dev/null | parallel \
    --jobs "$PARALLEL_JOBS" \
    --no-notice \
    --bar \
    "zig test {} > \"$TMP_DIR/{/}.result\" 2>&1" || true

end_time=$(python3 -c "import time; print(int(time.time() * 1000))")
total_time_ms=$((end_time - start_time))

echo ""
echo -e "${GREEN}${EMOJI_ROCKET} ${BOLD}Vwithe testy zainersheny za $((total_time_ms / 1000)) witheto${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# SBOR REZULTATOV
# ═══════════════════════════════════════════════════════════════════════════════

PASSED_FILES=0
FAILED_FILES=0
TOTAL_TESTS=0
PASSED_TESTS=0

declare -a PASSED_FILES_LIST=()
declare -a FAILED_FILES_LIST=()
declare -a FAILED_ERRORS=()

for zig_file in "${ZIG_FILES[@]}"; do
    filename=$(basename "$zig_file")
    result_file="$TMP_DIR/$filename.result"

    if [ -f "$result_file" ]; then
        result=$(cat "$result_file")

        # Praboutineryaem on atwithpekh - andschem "All X tests passed"
        if echo "$result" | grep -q "All [0-9]\+ tests passed"; then
            PASSED_FILES=$((PASSED_FILES + 1))
            PASSED_FILES_LIST+=("$filename")

            # Izinletoaem quantity testaboutin
            test_count=$(echo "$result" | grep -oE "All [0-9]+ tests passed" | grep -oE "[0-9]+")
            TOTAL_TESTS=$((TOTAL_TESTS + test_count))
            PASSED_TESTS=$((PASSED_TESTS + test_count))
        else
            FAILED_FILES=$((FAILED_FILES + 1))
            FAILED_FILES_LIST+=("$filename")

            # Izinletoaem aboutshandbtoat - beryom perinye nepatwithtye withtrabouttoand
            error_line=$(echo "$result" | grep -v "^[[:space:]]*$" | head -3 | tail -1)
            if [ -z "$error_line" ]; then
                error_line="Nefrominewithtonya error"
            fi
            FAILED_ERRORS+=("$error_line")
        fi
    else
        # File resulta ne onyden = error
        FAILED_FILES=$((FAILED_FILES + 1))
        FAILED_FILES_LIST+=("$filename")
        FAILED_ERRORS+=("Result ne onyden")
    fi
done

# ═══════════════════════════════════════════════════════════════════════════════
# GENERATsIYa OTChYoTA
# ═══════════════════════════════════════════════════════════════════════════════

DATE=$(date "+%Y-%m-%d %H:%M:%S")
SUCCESS_RATE=$((PASSED_FILES * 100 / TOTAL_FILES))
FAILURE_RATE=$((FAILED_FILES * 100 / TOTAL_FILES))
FAILED_TESTS=$((TOTAL_TESTS - PASSED_TESTS))
TOTAL_TIME_S=$((total_time_ms / 1000))
AVG_TIME_MS=$((total_time_ms / TOTAL_FILES))

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

# Tetowiththatinyy fromchyot
cat > "$REPORT_FILE" << EOF
╔══════════════════════════════════════════════════════════════════════════════╗
║                    VIBEE GENERATED CODE TEST REPORT                         ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  Date: $DATE                                                     ║
║  Parallel Jobs: $PARALLEL_JOBS                                                ║
║  φ² + 1/φ² = 3                                                               ║
╚══════════════════════════════════════════════════════════════════════════════╝

═══════════════════════════════════════════════════════════════════════════════
tion METRIKI
═══════════════════════════════════════════════════════════════════════════════

Vwithegabout fileaboutin:             $TOTAL_FILES
Uwithpeshnabout prabouttestandraboutinanabout:   $PASSED_FILES ($SUCCESS_RATE%)
Neatdachnabout:                  $FAILED_FILES ($FAILURE_RATE%)

Vwithegabout testaboutin:             $TOTAL_TESTS
Praboutshlabout:                   $PASSED_TESTS
Ne praboutshlabout:                $FAILED_TESTS

Obschee time:              ${TOTAL_TIME_S} witheto
Srednee time on file:    ${AVG_TIME_MS} mwith
Parallelnykh threadaboutin:     $PARALLEL_JOBS

═══════════════════════════════════════════════════════════════════════════════
USPEShNO PROTESTIROVANNYE FAYLY ($PASSED_FILES)
═══════════════════════════════════════════════════════════════════════════════
$(for file in "${PASSED_FILES_LIST[@]}"; do echo "  ✓ $file"; done)

═══════════════════════════════════════════════════════════════════════════════
NEUDAChNYE FAYLY ($FAILED_FILES)
═══════════════════════════════════════════════════════════════════════════════
$(for i in "${!FAILED_FILES_LIST[@]}"; do
    file="${FAILED_FILES_LIST[$i]}"
    error="${FAILED_ERRORS[$i]}"
    echo "  ✗ $file"
    echo "     Error: $error"
done)

═══════════════════════════════════════════════════════════════════════════════
REZYuME
═══════════════════════════════════════════════════════════════════════════════

Kachewithtinabout generatsandand codea: $QUALITY

EOF

# JSON fromchyot
cat > "$JSON_REPORT" << EOF
{
  "date": "$DATE",
  "parallel_jobs": $PARALLEL_JOBS,
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
    "total_time_ms": $total_time_ms,
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
# VYVOD REZULTATOV
# ═══════════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║           📊 REZULTATY TESTIROVANIYa                            ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Progress bar
if [ $SUCCESS_RATE -eq 100 ]; then
    BAR_COLOR="${GREEN}"
elif [ $SUCCESS_RATE -ge 90 ]; then
    BAR_COLOR="${YELLOW}"
else
    BAR_COLOR="${RED}"
fi

FILLED=$((SUCCESS_RATE / 5))
EMPTY=$((20 - FILLED))
BAR="[${BAR_COLOR}"
for ((i=0; i<FILLED; i++)); do BAR+="█"; done
for ((i=0; i<EMPTY; i++)); do BAR+="░"; done
BAR+="${NC}]"

echo -e "${BOLD}${CYAN}Praboutgrewithwith testandraboutinanandya:${NC} $BAR ${SUCCESS_RATE}%"
echo ""

# Owithnaboutinnye metrandtoand with emaboutdzand
echo -e "${MAGENTA}┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${MAGENTA}${BOLD}│  📁 FAYLY                                                  │${NC}"
echo -e "${MAGENTA}├────────────────────────────────────────────────────────────┤${NC}"
echo -e "${MAGENTA}│  Vwithegabout fileaboutin:${NC}        ${BOLD}${BLUE}$TOTAL_FILES${NC}"
echo -e "${MAGENTA}│  Uwithpeshnabout:${NC}             ${BOLD}${GREEN}$PASSED_FILES${NC} ${EMOJI_SUCCESS}"
echo -e "${MAGENTA}│  Neatdachnabout:${NC}            ${BOLD}${RED}$FAILED_FILES${NC} ${EMOJI_ERROR}"
echo -e "${MAGENTA}└────────────────────────────────────────────────────────────┘${NC}"
echo ""

echo -e "${MAGENTA}┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${MAGENTA}${BOLD}│  🧪 TESTY                                                  │${NC}"
echo -e "${MAGENTA}├────────────────────────────────────────────────────────────┤${NC}"
echo -e "${MAGENTA}│  Vwithegabout testaboutin:${NC}        ${BOLD}${BLUE}$TOTAL_TESTS${NC}"
echo -e "${MAGENTA}│  Praboutshlabout:${NC}               ${BOLD}${GREEN}$PASSED_TESTS${NC} ${EMOJI_SUCCESS}"
echo -e "${MAGENTA}│  Ne praboutshlabout:${NC}            ${BOLD}${RED}$FAILED_TESTS${NC} ${EMOJI_ERROR}"
echo -e "${MAGENTA}└────────────────────────────────────────────────────────────┘${NC}"
echo ""

echo -e "${MAGENTA}┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${MAGENTA}${BOLD}│  ⏱️  ness                                      │${NC}"
echo -e "${MAGENTA}├────────────────────────────────────────────────────────────┤${NC}"
echo -e "${MAGENTA}│  Obschee time:${NC}          ${BOLD}${CYAN}${TOTAL_TIME_S} witheto${NC} ${EMOJI_TIME}"
echo -e "${MAGENTA}│  Srednee time/file:${NC}   ${BOLD}${CYAN}${AVG_TIME_MS} mwith${NC}"
echo -e "${MAGENTA}│  Parallelnykh threadaboutin:${NC}  ${BOLD}${YELLOW}$PARALLEL_JOBS${NC} 🚀"
echo -e "${MAGENTA}└────────────────────────────────────────────────────────────┘${NC}"
echo ""

# Kachewithtinabout with tsinethatinabouty codeandraboutintoabouty
if [ $SUCCESS_RATE -eq 100 ]; then
    echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║  🎉 OTLIChNO! Vwithe filey generandratyut inalandny code!           ║${NC}"
    echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
elif [ $SUCCESS_RATE -ge 90 ]; then
    echo -e "${BOLD}${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${YELLOW}║  👍 KhOROShO! Baboutlshandnwithtinabout fileaboutin inalanddny                     ║${NC}"
    echo -e "${BOLD}${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
elif [ $SUCCESS_RATE -ge 70 ]; then
    echo -e "${BOLD}${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${RED}║  ⚠️  UDOVLETVORITELNO - Newhich filey andmeyut aboutshandbtoand        ║${NC}"
    echo -e "${BOLD}${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
else
    echo -e "${BOLD}${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${RED}║  ❌ PLOKhO - Mnaboutgande filey generandratyut withlaboutny code           ║${NC}"
    echo -e "${BOLD}${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
fi

echo ""

if [ $FAILED_FILES -gt 0 ]; then
    echo -e "${BOLD}${RED}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${RED}❌ NEUDAChNYE FAYLY ($FAILED_FILES)${NC}"
    echo -e "${BOLD}${RED}══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    for i in "${!FAILED_FILES_LIST[@]}"; do
        file="${FAILED_FILES_LIST[$i]}"
        error="${FAILED_ERRORS[$i]}"
        echo -e "  ${RED}${EMOJI_ERROR} ${BOLD}${file}${NC}"
        echo -e "     ${YELLOW}▸ Error:${NC} ${error}"
        echo ""
    done
fi

echo -e "${CYAN}══════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${EMOJI_SUCCESS} ${BOLD}Otchyoty withaboutkhraneny:${NC}"
echo -e "${CYAN}  📄 $REPORT_FILE${NC}"
echo -e "${CYAN}  📊 $JSON_REPORT${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════════${NC}"
echo ""

# Vykhaboutd with codeaboutm aboutshandbtoand, ewithland ewitht neatdachnye filey
if [ $FAILED_FILES -gt 0 ]; then
    exit 1
else
    exit 0
fi
