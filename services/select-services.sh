#!/bin/bash
#
# Service Selection - Registry-driven service selection
# This overrides the select_services function in install.sh
#

# Override select_services to use registry
select_services() {
    clear
    echo -e "${BLUE}=======================================${NC}"
    echo -e "${BLUE}  HOMELAB SERVICE SELECTION${NC}"
    echo -e "${BLUE}=======================================${NC}"
    echo ""
    echo "Select services to install (a for all, d to confirm)"
    echo ""
    
    # Source the registry for service info
    source "$SERVICE_DIR/registry.sh" 2>/dev/null
    
    # Helper to format service name
    format_name() {
        echo "$1" | sed 's/-/ /g' | sed 's/\b\(.\)/\U\1/g'
    }
    
    # Build service list from registry
    local services_list=()
    local stages_list=("STAGE1_CORE" "STAGE2_AUTH" "STAGE3_MEDIA_ARR" "STAGE4_MEDIA_SERVERS" "STAGE5_REQUESTS" "STAGE6_DASHBOARD" "STAGE7_MONITORING" "STAGE8_SECURITY" "STAGE9_STORAGE" "STAGE10_AI")
    
    echo "Available services:"
    echo ""
    
    for stage in "${stages_list[@]}"; do
        local category=$(echo "$stage" | cut -d'_' -f2)
        eval "local stage_services=(\"\${${stage}[@]}\")"
        
        case "$category" in
            CORE) category="📡 Core" ;;
            AUTH) category="🔐 Auth" ;;
            MEDIA_ARR) category="🎬 Media" ;;
            MEDIA_SERVERS) category="🎬 Media" ;;
            REQUESTS) category="🎬 Requests" ;;
            DASHBOARD) category="🖥️ Dashboard" ;;
            MONITORING) category="📊 Monitoring" ;;
            SECURITY) category="🔐 Security" ;;
            STORAGE) category="💾 Storage" ;;
            AI) category="🤖 AI" ;;
        esac
        
        echo -e "${YELLOW}$category${NC}"
        for svc in "${stage_services[@]}"; do
            local desc=$(get_service_description "$svc")
            echo "  - $(format_name $svc): $desc"
        done
        echo ""
    done
    
    echo "========================================"
    echo "Press 'a' for all services, 'd' to confirm"
    echo "========================================"
    echo ""
    
    # Read user input
    read -p "Selection: " selection
    case "$selection" in
        [aA])
            # Select all services
            SELECTED_SERVICES=""
            for svc in "${!SERVICE_REGISTRY[@]}"; do
                SELECTED_SERVICES="$SELECTED_SERVICES $svc"
            done
            ;;
        [dD]|*)
            # Use default selected from registry
            SELECTED_SERVICES=""
            for svc in "${DEFAULT_SELECTED[@]}"; do
                SELECTED_SERVICES="$SELECTED_SERVICES $svc"
            done
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}Selected services:${NC}"
    for svc in $SELECTED_SERVICES; do
        echo "  - $svc"
    done
    echo ""
}
