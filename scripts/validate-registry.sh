#!/bin/bash
#
# Registry Validator - Validates service registry consistency
#

set -e

REGISTRY_FILE="$1"
if [[ -z "$REGISTRY_FILE" ]]; then
    REGISTRY_FILE="/home/hallmikey/homelab-install-backup/services/registry.sh"
fi

log_info() { echo "[INFO] $1"; }
log_error() { echo "[ERROR] $1"; }
log_success() { echo "[OK] $1"; }

# Source the registry
source "$REGISTRY_FILE"

errors=0
warnings=0

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  SERVICE REGISTRY VALIDATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Special services that don't have compose files
NO_COMPOSE_FILE=("docker" "portainer" "traefik")

# Extract all service names from SERVICE_REGISTRY
declare -A ALL_SERVICES
for key in "${!SERVICE_REGISTRY[@]}"; do
    # Extract service name - split by colon and get first part
    IFS=':' read -r service_name rest <<< "$key"
    ALL_SERVICES["$service_name"]=1
done

# Check 1: Verify all stages are defined
log_info "Checking stage definitions..."
for stage in "${ALL_STAGES[@]}"; do
    eval "if [[ -n \"\${${stage}+isset}\" ]]; then log_success \"$stage defined\"; else log_error \"$stage NOT defined\"; ((errors++)); fi"
done

# Check 2: Verify SERVICE_REGISTRY has all services
log_info "Checking SERVICE_REGISTRY..."
for service_name in "${!ALL_SERVICES[@]}"; do
    log_success "Found: $service_name"
    
    # Skip special services without compose files
    skip=false
    for special in "${NO_COMPOSE_FILE[@]}"; do
        if [[ "$special" == "$service_name" ]]; then
            log_success "${service_name} (no compose file - special service)"
            skip=true
            break
        fi
    done
    
    if [[ "$skip" == "true" ]]; then
        continue
    fi
    
    # Verify compose file exists
    compose_file="/home/hallmikey/homelab-install-backup/services/${service_name}.yml"
    if [[ -f "$compose_file" ]]; then
        log_success "${service_name}.yml exists"
    else
        # Try with underscore
        underscore_service="${service_name//-/_}"
        compose_file="/home/hallmikey/homelab-install-backup/services/${underscore_service}.yml"
        if [[ -f "$compose_file" ]]; then
            log_success "${underscore_service}.yml exists (found via underscore)"
        else
            log_error "${service_name}.yml NOT FOUND"
            ((errors++))
        fi
    fi
done

# Check 3: Validate dependency references
log_info "Checking dependencies..."
for service in "${!SERVICE_DEPENDENCIES[@]}"; do
    deps=$(get_service_dependencies "$service")
    for dep in $deps; do
        if [[ -n "$dep" ]]; then
            dep_file="/home/hallmikey/homelab-install-backup/services/${dep}.yml"
            if [[ -f "$dep_file" ]]; then
                log_success "$service depends on $dep (valid)"
            else
                dep_file_underscore="/home/hallmikey/homelab-install-backup/services/${dep//-/_}.yml"
                if [[ -f "$dep_file_underscore" ]]; then
                    log_success "$service depends on $dep (valid via underscore)"
                else
                    log_error "$service depends on $dep (NOT FOUND)"
                    ((errors++))
                fi
            fi
        fi
    done
done

# Check 4: Verify stage arrays match registry
log_info "Checking stage consistency..."
for stage in "${ALL_STAGES[@]}"; do
    eval "stage_array=(\"\${${stage}[@]}\")"
    stage_name="${stage#STAGE}"
    for service in "${stage_array[@]}"; do
        if [[ -n "${ALL_SERVICES[$service]+isset}" ]]; then
            log_success "$service in $stage_name"
        else
            log_error "$service in $stage_name (not in registry)"
            ((errors++))
        fi
    done
done

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  VALIDATION SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Errors: $errors"
echo "Warnings: $warnings"

if [[ $errors -eq 0 ]]; then
    log_success "Registry validation PASSED"
    exit 0
else
    log_error "Registry validation FAILED"
    exit 1
fi
