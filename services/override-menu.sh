#!/bin/bash
#
# Service Menu Override - Replaces hardcoded menu with registry-driven menu
# Source this file AFTER install.sh
#

# Override show_service_menu to use registry
show_service_menu() {
    clear
    echo -e "${BLUE}=======================================${NC}"
    echo -e "${BLUE}  HOMELAB SERVICE SELECTION${NC}"
    echo -e "${BLUE}=======================================${NC}"
    echo ""
    echo "Select services to install (space to toggle, enter to confirm)"
    echo ""
    
    # Source the registry for service info
    source "$SERVICE_DIR/registry.sh" 2>/dev/null
    
    # Helper to format service name
    format_name() {
        echo "$1" | sed 's/-/ /g' | sed 's/\b\(.\)/\U\1/g'
    }
    
    # Print services by category based on stage
    echo -e "${YELLOW}📡 Core${NC}"
    for svc in "${STAGE1_CORE[@]}"; do
        [[ "$svc" == "traefik" ]] && echo "  [ ] $(format_name $svc)          - $(get_service_description $svc)"
    done
    echo ""
    
    echo -e "${YELLOW}🔐 Auth${NC}"
    for svc in "${STAGE2_AUTH[@]}"; do
        echo "  [ ] $(format_name $svc)          - $(get_service_description $svc)"
    done
    echo ""
    
    echo -e "${YELLOW}🎬 Media${NC}"
    for svc in "${STAGE4_MEDIA_SERVERS[@]}" "${STAGE3_MEDIA_ARR[@]}"; do
        echo "  [ ] $(format_name $svc)          - $(get_service_description $svc)"
    done
    echo ""
    
    echo -e "${YELLOW}🔐 Security${NC}"
    for svc in "${STAGE8_SECURITY[@]}"; do
        echo "  [ ] $(format_name $svc)          - $(get_service_description $svc)"
    done
    echo ""
    
    echo -e "${YELLOW}📊 Monitoring${NC}"
    for svc in "${STAGE7_MONITORING[@]}"; do
        echo "  [ ] $(format_name $svc)          - $(get_service_description $svc)"
    done
    echo ""
    
    echo -e "${YELLOW}💾 Storage${NC}"
    for svc in "${STAGE9_STORAGE[@]}"; do
        echo "  [ ] $(format_name $svc)          - $(get_service_description $svc)"
    done
    echo ""
    
    echo -e "${YELLOW}🤖 AI${NC}"
    for svc in "${STAGE10_AI[@]}"; do
        echo "  [ ] $(format_name $svc)          - $(get_service_description $svc)"
    done
    echo ""
    
    echo -e "${GREEN}=======================================${NC}"
}
