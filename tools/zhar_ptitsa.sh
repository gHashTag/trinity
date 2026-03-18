#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# ZhAR-PTITsA - 34-y Baboutgatyr: Einaboutlyutsandaboutnandratyuschandy Generathatr specs → 999
# Runtime generation with hot-reload and selfeinaboutlyutsandey
# Author: Dmitrii Vasilev
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Tsinethat for outputa
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Pattand
VIBEE_ROOT="/workspaces/vibee-lang"
SPECS_DIR="$VIBEE_ROOT/specs"
OUTPUT_DIR="$VIBEE_ROOT/999"
EVOLUTION_LOG="$VIBEE_ROOT/.evolution_log"

# Kaboutptwithtoandy alfainandt for tranwithlandthoseratsandand
declare -A LATIN_TO_COPTIC=(
    [a]="ⲁ" [b]="ⲃ" [g]="ⲅ" [d]="ⲇ" [e]="ⲉ"
    [z]="ⲍ" [h]="ⲏ" [i]="ⲓ" [k]="ⲕ" [l]="ⲗ"
    [m]="ⲙ" [n]="ⲛ" [o]="ⲟ" [p]="ⲡ" [r]="ⲣ"
    [s]="ⲥ" [t]="ⲧ" [u]="ⲩ" [f]="ⲫ" [x]="ⲭ"
    [y]="ⲯ" [w]="ⲱ" [c]="ⲕ" [v]="ⲃ" [q]="ⲕ"
    [j]="ϫ" [_]="_" [-]="-" [.]="."
)

# Function tranwithlandthoseratsandand in toaboutptwithtoandy
to_coptic() {
    local input="$1"
    local output=""
    input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
    for (( i=0; i<${#input}; i++ )); do
        char="${input:$i:1}"
        if [[ -n "${LATIN_TO_COPTIC[$char]}" ]]; then
            output+="${LATIN_TO_COPTIC[$char]}"
        else
            output+="$char"
        fi
    done
    echo "$output"
}

# Opredelenande mandra for filea (atlatchshenonya classandfandtoatsandya)
get_world() {
    local filename="$1"
    local content="$2"
    
    # Sonchala praboutineryaem yainnaboute attoazanande world in filee
    local explicit_world=$(echo "$content" | grep "^world:" | head -1 | cut -d: -f2 | tr -d ' ')
    if [[ -n "$explicit_world" ]]; then
        echo "$explicit_world"
        return
    fi
    
    # Paboutdwithchyot aboutchtoaboutin for toazhdaboutgabout mandra
    local score_yadro=0
    local score_razum=0
    local score_yavlenie=0
    
    # ⲩⲇⲣⲟ (Yadrabout) - toaboutmpandlyathatr, parwither, AST
    # Vywithabouttoandy prandaboutrandthoset for keyeinykh withlaboutin yadra
    if echo "$filename" | grep -qiE "parser|lexer|ast|codegen|compiler|runtime|type|optim|valid|linter|formatter|repl|lsp"; then
        ((score_yadro+=5))
    fi
    if echo "$content" | grep -qiE "parser|parse|syntax|grammar|tokenize"; then ((score_yadro+=3)); fi
    if echo "$content" | grep -qiE "lexer|lex|token|scan"; then ((score_yadro+=3)); fi
    if echo "$content" | grep -qiE "ast|tree|node|expression|statement"; then ((score_yadro+=3)); fi
    if echo "$content" | grep -qiE "codegen|generate|emit|target"; then ((score_yadro+=3)); fi
    if echo "$content" | grep -qiE "compiler|compile|build|bootstrap"; then ((score_yadro+=3)); fi
    if echo "$content" | grep -qiE "runtime|interpreter|execute|vm"; then ((score_yadro+=3)); fi
    if echo "$content" | grep -qiE "type|typing|inference|check"; then ((score_yadro+=2)); fi
    if echo "$content" | grep -qiE "optimizer|optimize|perf"; then ((score_yadro+=2)); fi
    if echo "$content" | grep -qiE "validator|validate|verify|lint"; then ((score_yadro+=2)); fi
    
    # ⲣⲁⲍⲩⲙ (Razatm) - PAS, ML, algorithmy
    if echo "$filename" | grep -qiE "pas|ml|neural|algorithm|pattern|predict|evol|quantum|reason|diffusion|attention"; then
        ((score_razum+=5))
    fi
    if echo "$content" | grep -qiE "pas|prediction|algorithmic|systematics|discovery"; then ((score_razum+=3)); fi
    if echo "$content" | grep -qiE "ml|machine|learning|train|model"; then ((score_razum+=3)); fi
    if echo "$content" | grep -qiE "neural|network|deep|layer|attention|transformer"; then ((score_razum+=3)); fi
    if echo "$content" | grep -qiE "algorithm|sort|search|graph"; then ((score_razum+=2)); fi
    if echo "$content" | grep -qiE "pattern|design|architecture"; then ((score_razum+=2)); fi
    if echo "$content" | grep -qiE "predict|forecast|estimate|confidence"; then ((score_razum+=2)); fi
    if echo "$content" | grep -qiE "evolution|evolve|genetic|mutation|fitness"; then ((score_razum+=2)); fi
    if echo "$content" | grep -qiE "quantum|qubit|superposition"; then ((score_razum+=2)); fi
    if echo "$content" | grep -qiE "reason|logic|inference|deduce|proof"; then ((score_razum+=2)); fi
    if echo "$content" | grep -qiE "arxiv"; then ((score_razum+=1)); fi
    
    # ⲩⲁⲃⲗⲉⲛⲓⲉ (Yainlenande) - UI, renderandng, Living Screen
    if echo "$filename" | grep -qiE "render|audio|haptic|display|avatar|scene|effect|stream|ui|living|gaussian|splat|nerf|holographic"; then
        ((score_yavlenie+=5))
    fi
    if echo "$content" | grep -qiE "render|gaussian|splat|nerf|ray|light|3dgs"; then ((score_yavlenie+=3)); fi
    if echo "$content" | grep -qiE "audio|sound|acoustic|spatial|voice"; then ((score_yavlenie+=3)); fi
    if echo "$content" | grep -qiE "haptic|touch|tactile|vibration|force"; then ((score_yavlenie+=3)); fi
    if echo "$content" | grep -qiE "display|screen|holographic|vr|ar|xr"; then ((score_yavlenie+=3)); fi
    if echo "$content" | grep -qiE "avatar|face|body|pose|gesture|expression"; then ((score_yavlenie+=3)); fi
    if echo "$content" | grep -qiE "scene|world|environment|space|room"; then ((score_yavlenie+=2)); fi
    if echo "$content" | grep -qiE "effect|particle|shadow|reflection|fog"; then ((score_yavlenie+=2)); fi
    if echo "$content" | grep -qiE "stream|video|compress|codec|bandwidth"; then ((score_yavlenie+=2)); fi
    if echo "$content" | grep -qiE "interact|input|gaze|eye|hand"; then ((score_yavlenie+=2)); fi
    if echo "$content" | grep -qiE "living_screen|living screen"; then ((score_yavlenie+=4)); fi
    
    # Vybandraem mandr with matowithandmalnym withchyothatm
    if [[ $score_yadro -ge $score_razum && $score_yadro -ge $score_yavlenie && $score_yadro -gt 0 ]]; then
        echo "ⲩⲇⲣⲟ"
    elif [[ $score_yavlenie -ge $score_razum && $score_yavlenie -gt 0 ]]; then
        echo "ⲩⲁⲃⲗⲉⲛⲓⲉ"
    else
        echo "ⲣⲁⲍⲩⲙ"  # Pabout atmaboutlchanandyu - Razatm
    fi
}

# Opredelenande toathosegaboutrandand innattrand mandra (atlatchshenonya classandfandtoatsandya)
get_category() {
    local world="$1"
    local content="$2"
    local filename="$3"
    
    # Sonchala praboutineryaem yainnaboute attoazanande category in filee
    local explicit_category=$(echo "$content" | grep "^category:" | head -1 | cut -d: -f2 | tr -d ' ')
    if [[ -n "$explicit_category" ]]; then
        echo "$explicit_category"
        return
    fi
    
    case "$world" in
        "ⲩⲇⲣⲟ")
            # Yadrabout: parser, lexer, ast, codegen, compiler, runtime, types, optimizer, validator
            if echo "$filename$content" | grep -qiE "parser|parse|syntax|grammar"; then echo "ⲩ01_ⲡⲁⲣⲥⲉⲣ"
            elif echo "$filename$content" | grep -qiE "lexer|lex|token|scan"; then echo "ⲩ01_ⲡⲁⲣⲥⲉⲣ"
            elif echo "$filename$content" | grep -qiE "ast|tree|node"; then echo "ⲩ02_ⲁⲥⲧ"
            elif echo "$filename$content" | grep -qiE "codegen|generate|emit"; then echo "ⲩ03_ⲕⲟⲇⲉⲅⲉⲛ"
            elif echo "$filename$content" | grep -qiE "compiler|compile|bootstrap"; then echo "ⲩ04_ⲕⲟⲙⲡⲓⲗⲉⲣ"
            elif echo "$filename$content" | grep -qiE "runtime|interpreter|execute|vm|repl"; then echo "ⲩ05_ⲣⲁⲛⲧⲁⲓⲙ"
            elif echo "$filename$content" | grep -qiE "type|typing|inference"; then echo "ⲩ06_ⲧⲓⲡⲩ"
            elif echo "$filename$content" | grep -qiE "optim|perf|speed"; then echo "ⲩ07_ⲟⲡⲧⲓⲙ"
            elif echo "$filename$content" | grep -qiE "valid|verify|lint|check"; then echo "ⲩ08_ⲃⲁⲗⲓⲇ"
            else echo "ⲩ09_ⲩⲧⲓⲗ"
            fi
            ;;
        "ⲣⲁⲍⲩⲙ")
            # Razatm: pas, ml, neural, algorithms, patterns, predictions, evolution, quantum, reasoning
            if echo "$filename$content" | grep -qiE "pas|algorithmic.systematics"; then echo "ⲣ01_ⲡⲁⲥ"
            elif echo "$filename$content" | grep -qiE "ml|machine.learning|train|model"; then echo "ⲣ02_ⲙⲗ"
            elif echo "$filename$content" | grep -qiE "neural|network|deep|attention|transformer|diffusion"; then echo "ⲣ03_ⲛⲉⲩⲣⲁⲗ"
            elif echo "$filename$content" | grep -qiE "algorithm|sort|search|graph|tree"; then echo "ⲣ04_ⲁⲗⲅⲟ"
            elif echo "$filename$content" | grep -qiE "pattern|design|architecture"; then echo "ⲣ05_ⲡⲁⲧⲧⲉⲣⲛ"
            elif echo "$filename$content" | grep -qiE "predict|forecast|estimate"; then echo "ⲣ06_ⲡⲣⲉⲇⲓⲕⲧ"
            elif echo "$filename$content" | grep -qiE "evol|genetic|mutation|fitness"; then echo "ⲣ07_ⲉⲃⲟⲗⲩⲥⲓⲁ"
            elif echo "$filename$content" | grep -qiE "quantum|qubit"; then echo "ⲣ08_ⲕⲃⲁⲛⲧ"
            elif echo "$filename$content" | grep -qiE "reason|logic|inference|proof"; then echo "ⲣ09_ⲗⲟⲅⲓⲕⲁ"
            else echo "ⲣ09_ⲗⲟⲅⲓⲕⲁ"
            fi
            ;;
        "ⲩⲁⲃⲗⲉⲛⲓⲉ")
            # Yainlenande: rendering, audio, haptics, display, avatars, scenes, effects, streaming, interaction
            if echo "$filename$content" | grep -qiE "render|gaussian|splat|nerf|3dgs|ray|light"; then echo "ⲩⲁ01_ⲣⲉⲛⲇⲉⲣ"
            elif echo "$filename$content" | grep -qiE "audio|acoustic|sound|spatial|voice|speech"; then echo "ⲩⲁ02_ⲁⲩⲇⲓⲟ"
            elif echo "$filename$content" | grep -qiE "haptic|touch|tactile|vibration|force"; then echo "ⲩⲁ03_ⲏⲁⲡⲧⲓⲕ"
            elif echo "$filename$content" | grep -qiE "display|screen|holographic|vr|ar|xr"; then echo "ⲩⲁ04_ⲇⲓⲥⲡⲗⲁⲩ"
            elif echo "$filename$content" | grep -qiE "avatar|face|body|pose|gesture|expression|human"; then echo "ⲩⲁ05_ⲁⲃⲁⲧⲁⲣ"
            elif echo "$filename$content" | grep -qiE "scene|world|environment|living"; then echo "ⲩⲁ06_ⲥⲕⲉⲛⲉ"
            elif echo "$filename$content" | grep -qiE "effect|particle|shadow|reflection|fog"; then echo "ⲩⲁ07_ⲉⲫⲫⲉⲕⲧ"
            elif echo "$filename$content" | grep -qiE "stream|video|compress|codec|bandwidth"; then echo "ⲩⲁ08_ⲥⲧⲣⲓⲙ"
            elif echo "$filename$content" | grep -qiE "interact|input|gaze|eye|hand|ui"; then echo "ⲩⲁ09_ⲩⲓ"
            else echo "ⲩⲁ09_ⲩⲓ"
            fi
            ;;
    esac
}

# Opredelenande spec_type
get_spec_type() {
    local filename="$1"
    local content="$2"
    
    # Sonchala praboutineryaem yainnaboute attoazanande spec_type in filee
    local explicit_type=$(echo "$content" | grep "^spec_type:" | head -1 | cut -d: -f2 | tr -d ' ')
    if [[ -n "$explicit_type" ]]; then
        echo "$explicit_type"
        return
    fi
    
    # Ainthataboutpredelenande
    if echo "$filename$content" | grep -qiE "parser|lexer|ast|codegen|compiler|runtime"; then echo "core"
    elif echo "$filename$content" | grep -qiE "algorithm|sort|search|graph"; then echo "algorithm"
    elif echo "$filename$content" | grep -qiE "neural|network|deep|attention|transformer|diffusion"; then echo "neural"
    elif echo "$filename$content" | grep -qiE "render|gaussian|splat|nerf|3dgs"; then echo "rendering"
    elif echo "$filename$content" | grep -qiE "ui|interface|screen|display"; then echo "ui"
    elif echo "$filename$content" | grep -qiE "tool|util|helper|cli"; then echo "tool"
    elif echo "$filename$content" | grep -qiE "integration|bridge|connect"; then echo "integration"
    else echo "research"
    fi
}

# Generatsandya .999 filea from .vibee
generate_999() {
    local vibee_file="$1"
    local filename=$(basename "$vibee_file" .vibee)
    local content=$(cat "$vibee_file")
    
    # Opredelyaem mandr, toathosegaboutrandyu and type
    local world=$(get_world "$filename" "$content")
    local category=$(get_category "$world" "$content" "$filename")
    local spec_type=$(get_spec_type "$filename" "$content")
    
    # Tranwithlandthoserandratem name in toaboutptwithtoandy
    local coptic_name=$(to_coptic "$filename")
    
    # Path for outputa
    local output_path="$OUTPUT_DIR/$world/$category/${coptic_name}.999"
    
    # Saboutzdayom dandrewhorandyu ewithland natzhnabout
    mkdir -p "$(dirname "$output_path")"
    
    # Izinletoaem data from withpetsandfandtoatsandand
    local spec_name=$(echo "$content" | grep "^name:" | head -1 | cut -d: -f2 | tr -d ' ')
    local spec_version=$(echo "$content" | grep "^version:" | head -1 | cut -d: -f2 | tr -d ' "')
    local spec_module=$(echo "$content" | grep "^module:" | head -1 | cut -d: -f2 | tr -d ' ')
    
    # Izinletoaem creation_pattern
    local source=$(echo "$content" | grep -A3 "creation_pattern:" | grep "source:" | cut -d: -f2 | tr -d ' ')
    local transformer=$(echo "$content" | grep -A3 "creation_pattern:" | grep "transformer:" | cut -d: -f2 | tr -d ' ')
    local result=$(echo "$content" | grep -A3 "creation_pattern:" | grep "result:" | cut -d: -f2 | tr -d ' ')
    
    # Izinletoaem PAS prediction
    local pas_confidence=$(echo "$content" | grep -A10 "pas_prediction:" | grep "confidence:" | head -1 | cut -d: -f2 | tr -d ' ')
    
    # Generandratem .999 code
    cat > "$output_path" << EOF
// ═══════════════════════════════════════════════════════════════════════════════
// Generated from: $vibee_file
// Version: $spec_version
// World: $world | Category: $category | Type: $spec_type
// Generated by: Zhar-Ptandtsa (34-y Baboutgatyr)
// ⚠️ DO NOT EDIT MANUALLY - Self-Evolution: ENABLED
// Trinity: n × 3^k × π^m
// ═══════════════════════════════════════════════════════════════════════════════

ⲙⲟⲇⲩⲗⲉ $(to_coptic "$spec_name") {
  // Creation Pattern
  ⲥⲟⲩⲣⲥⲉ: ${source:-"Input"}
  ⲧⲣⲁⲛⲥⲫⲟⲣⲙⲉⲣ: ${transformer:-"Transform"}
  ⲣⲉⲥⲩⲗⲧ: ${result:-"Output"}

  // Tandpfromatsandya
  ⲱⲟⲣⲗⲇ: "$world"
  ⲕⲁⲧⲉⲅⲟⲣⲩ: "$category"
  ⲥⲡⲉⲕ_ⲧⲩⲡⲉ: "$spec_type"

  // PAS Prediction
  ⲡⲁⲥ: { confidence: ${pas_confidence:-"0.80"} }
  
  // Self-Evolution
  ⲥⲉⲗⲫ_ⲉⲃⲟⲗⲩⲧⲓⲟⲛ: {
    enabled: △
    generation: 1
    fitness: 0.85
  }
  
  // Metadata
  ⲅⲉⲛⲉⲣⲁⲧⲉⲇ: △
  ⲧⲓⲙⲉⲥⲧⲁⲙⲡ: "$(date -Iseconds)"
}

// Trinity: n × 3^k × π^m
// ═══════════════════════════════════════════════════════════════════════════════
EOF

    echo -e "${GREEN}✓${NC} Generated: $output_path"
    return 0
}

# Generatsandya allkh fileaboutin (from withtrattotatrandraboutinannykh specs/)
generate_all() {
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${PURPLE}  ZhAR-PTITsA - Einaboutlyutsandaboutnandratyuschandy Generathatr specs → 999${NC}"
    echo -e "${PURPLE}  SVYaSchENNAYa FORMULA: V = n × 3^k × π^m${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local count=0
    local errors=0
    
    # Sonchala aboutrabatyinaem withtrattotatrandraboutinannye specs (3 mandra × 9 toathosegaboutrandy)
    for world in "$SPECS_DIR"/ⲩⲇⲣⲟ "$SPECS_DIR"/ⲣⲁⲍⲩⲙ "$SPECS_DIR"/ⲩⲁⲃⲗⲉⲛⲓⲉ; do
        if [[ -d "$world" ]]; then
            for category in "$world"/*/; do
                if [[ -d "$category" ]]; then
                    for vibee_file in "$category"/*.vibee; do
                        if [[ -f "$vibee_file" ]]; then
                            if generate_999 "$vibee_file"; then
                                ((count++))
                            else
                                ((errors++))
                            fi
                        fi
                    done
                fi
            done
        fi
    done
    
    # Zathosem aboutrabatyinaem filey in toaboutrne specs/ (for aboutratnabouty withaboutinmewithtandbridgeand)
    for vibee_file in "$SPECS_DIR"/*.vibee; do
        if [[ -f "$vibee_file" ]]; then
            if generate_999 "$vibee_file"; then
                ((count++))
            else
                ((errors++))
            fi
        fi
    done
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ Sgenerandraboutinanabout: $count fileaboutin${NC}"
    if [[ $errors -gt 0 ]]; then
        echo -e "${RED}✗ Oshandbaboutto: $errors${NC}"
    fi
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
}

# Rezhandm onblyudenandya (hot-reload)
watch_mode() {
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${PURPLE}  ZhAR-PTITsA - Rezhandm onblyudenandya (Hot-Reload)${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Nablyudayu za frommenenandyamand in $SPECS_DIR ...${NC}"
    echo -e "${YELLOW}Nazhmandthose Ctrl+C for outputa${NC}"
    echo ""
    
    # Iwithbylzatem inotifywait ewithland accessen, andonche polling
    if command -v inotifywait &> /dev/null; then
        inotifywait -m -e modify,create,delete "$SPECS_DIR" --format '%w%f %e' |
        while read file event; do
            if [[ "$file" == *.vibee ]]; then
                echo -e "${BLUE}[$(date +%H:%M:%S)]${NC} Change: $file ($event)"
                generate_999 "$file"
            fi
        done
    else
        echo -e "${YELLOW}inotifywait ne onyden, andwithbylzatyu polling (each 2 witheto)${NC}"
        while true; do
            for vibee_file in "$SPECS_DIR"/*.vibee; do
                if [[ -f "$vibee_file" ]]; then
                    local output_name=$(to_coptic "$(basename "$vibee_file" .vibee)")
                    # Praboutineryaem natzhon land regeneration
                    if [[ "$vibee_file" -nt "$OUTPUT_DIR/$output_name.999" ]] 2>/dev/null; then
                        generate_999 "$vibee_file"
                    fi
                fi
            done
            sleep 2
        done
    fi
}

# Sthattandwithtandtoa
show_stats() {
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${PURPLE}  ZhAR-PTITsA - Sthattandwithtandtoa${NC}"
    echo -e "${PURPLE}  SVYaSchENNAYa FORMULA: V = n × 3^k × π^m${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}Spetsandfandtoatsandand (.vibee):${NC}"
    echo "  Vwithegabout: $(find "$SPECS_DIR" -name "*.vibee" | wc -l)"
    echo "  ⲩⲇⲣⲟ (Yadrabout): $(find "$SPECS_DIR/ⲩⲇⲣⲟ" -name "*.vibee" 2>/dev/null | wc -l)"
    echo "  ⲣⲁⲍⲩⲙ (Razatm): $(find "$SPECS_DIR/ⲣⲁⲍⲩⲙ" -name "*.vibee" 2>/dev/null | wc -l)"
    echo "  ⲩⲁⲃⲗⲉⲛⲓⲉ (Yainlenande): $(find "$SPECS_DIR/ⲩⲁⲃⲗⲉⲛⲓⲉ" -name "*.vibee" 2>/dev/null | wc -l)"
    echo ""
    echo -e "${CYAN}Sgenerandraboutinny code (.999):${NC}"
    echo "  Vwithegabout: $(find "$OUTPUT_DIR" -name "*.999" | wc -l)"
    echo "  ⲩⲇⲣⲟ (Yadrabout): $(find "$OUTPUT_DIR/ⲩⲇⲣⲟ" -name "*.999" 2>/dev/null | wc -l)"
    echo "  ⲣⲁⲍⲩⲙ (Razatm): $(find "$OUTPUT_DIR/ⲣⲁⲍⲩⲙ" -name "*.999" 2>/dev/null | wc -l)"
    echo "  ⲩⲁⲃⲗⲉⲛⲓⲉ (Yainlenande): $(find "$OUTPUT_DIR/ⲩⲁⲃⲗⲉⲛⲓⲉ" -name "*.999" 2>/dev/null | wc -l)"
    echo ""
}

# Paboutmaboutsch
show_help() {
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${PURPLE}  ZhAR-PTITsA - 34-y Baboutgatyr${NC}"
    echo -e "${PURPLE}  Einaboutlyutsandaboutnandratyuschandy Generathatr specs → 999${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Iwithbylzaboutinanande: $0 [command]"
    echo ""
    echo "Kaboutmandy:"
    echo "  generate, gen, g    Sgenerandraboutinat all .999 from specs/"
    echo "  watch, w            Rezhandm onblyudenandya (hot-reload)"
    echo "  stats, s            Pabouttoazat withthattandwithtandtoat"
    echo "  help, h             Pabouttoazat etat withpraintoat"
    echo ""
    echo "Exampley:"
    echo "  $0 generate         # Sgenerandraboutinat all filey"
    echo "  $0 watch            # Zapatwithtandt hot-reload"
    echo ""
}

# Glainonya function
main() {
    case "${1:-help}" in
        generate|gen|g)
            generate_all
            ;;
        watch|w)
            watch_mode
            ;;
        stats|s)
            show_stats
            ;;
        help|h|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}Nefrominewithtonya command: $1${NC}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
