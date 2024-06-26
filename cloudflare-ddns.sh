#!/bin/bash

# Cloudflare Dynamic DNS Updater for HiveOS

# ## Script Operation Order:

# 1. **Check Dependencies:** Ensures essential tools (`curl`, `jq`) are installed.
# 2. **Check Service:** Verifies if the `cloudflare-ddns` service is enabled and running (for informational purposes).
# 3. **Get Public IP:** Fetches the rig's current public IP address from various sources, with failover for robustness.
# 4. **Cloudflare DNS Update (Optional):**
#    - Checks if Cloudflare credentials are provided.
#    - If yes, fetches the current DNS record from Cloudflare.
#    - Compares it with the current public IP.
#    - Updates the Cloudflare DNS record if there's a mismatch. Logs success or failure.
# 5. **Save IP:** Saves the current public IP to `previous_ip.txt` for future comparison.
# 6. **Reboot on IP Change:** Checks if the IP has changed, and if so, reboots the HiveOS rig. Logs the action taken.

# --- Configuration ---

# Cloudflare API Credentials (Replace placeholders with your actual values or leave empty if not using Cloudflare)
CLOUDFLARE_EMAIL=""
CLOUDFLARE_API_KEY=""
CLOUDFLARE_ZONE_ID=""
CLOUDFLARE_DNS_RECORD=""

# File to store the previous IP address
IP_ADDRESS_FILE="previous_ip.txt"

# --- Logging ---

LOG_FILE="/var/log/cloudflare-ddns.log"
log() {
    echo "$(date) - $1" >> "$LOG_FILE"
}

# --- Colors ---

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Dependencies ---

check_and_install_dependencies() {
    dependencies=("curl" "jq")  # List of required dependencies
    for dependency in "${dependencies[@]}"; do
        if ! command -v "$dependency" &> /dev/null; then  # Check if dependency exists
            log "Dependency '$dependency' not found. Installing..."
            echo -e "${YELLOW}Dependency '$dependency' not found. Installing...${NC}"
            if ! sudo apt-get install -y "$dependency"; then  # Try to install using apt-get
                log "Failed to install '$dependency'. Please install it manually."
                echo -e "${RED}Failed to install '$dependency'. Please install it manually.${NC}"
                exit 1  # Exit script if installation fails
            fi
        fi
    done
}

# --- Check Service ---

check_service_status() {
    service_status=$(systemctl is-enabled cloudflare-ddns.service)

    if [[ "$service_status" = "enabled" ]]; then
        if systemctl is-active --quiet cloudflare-ddns.service; then
            log "Service 'cloudflare-ddns' is enabled and running."
            echo -e "${GREEN}Service 'cloudflare-ddns' is enabled and running.${NC}"
        else
            log "Service 'cloudflare-ddns' is enabled but not running. Check status manually."
            echo -e "${YELLOW}Service 'cloudflare-ddns' is enabled but not running. Check status manually.${NC}"
        fi
        log "Service Timer Status: $(systemctl is-active cloudflare-ddns.timer)"
        echo -e "${YELLOW}Service Timer Status: $(systemctl is-active cloudflare-ddns.timer)${NC}"
    else
        log "Service 'cloudflare-ddns' is not enabled. Ensure it's set up correctly."
        echo -e "${YELLOW}Service 'cloudflare-ddns' is not enabled. Ensure it's set up correctly.${NC}"
    fi
}

# --- IP Retrieval ---

# List of reliable IP address retrieval websites
sites=("icanhazip.com" "ipv4.lafibre.info/ip.php" "ifconfig.me/ip" "api.ipify.org" "ipinfo.io/ip" "ipecho.net/plain" "checkip.amazonaws.com")

get_valid_ip() {
  local remaining_sites=("${sites[@]}")
  local unreachable_sites=()  # Track unreachable sites
  local ip_address=""

  while [[ -z "$ip_address" && ${#remaining_sites[@]} -gt 0 ]]; do
    local index=$((RANDOM % ${#remaining_sites[@]}))
    local site="${remaining_sites[index]}"

    # Skip sites marked as unreachable
    if [[ " ${unreachable_sites[*]} " == *" $site "* ]]; then
      continue
    fi

    # Check if the site is reachable and get the IP
    if curl_output=$(curl -s "$site" 2>/dev/null); then 
      ip_address=$(echo "$curl_output" | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')

      if [[ -z "$ip_address" ]]; then
        log "Failed to get IP from $site, trying another..."
        unset 'remaining_sites[index]'  # Remove the site if it failed
      fi
    else
      log "Error: Site $site unreachable."
      unreachable_sites+=("$site")    # Mark the site as unreachable
      unset 'remaining_sites[index]'  # Remove the site
    fi

    remaining_sites=("${remaining_sites[@]}") # Reset array indices
  done

  echo "$ip_address"
}


# --- Cloudflare DNS Update (Optional) ---

update_cloudflare_dns() {
    local ip_address=$1

    if [[ -n "$CLOUDFLARE_EMAIL" && -n "$CLOUDFLARE_API_KEY" && -n "$CLOUDFLARE_ZONE_ID" && -n "$CLOUDFLARE_DNS_RECORD" ]]; then
        # Get Cloudflare DNS Record Details
        record_details=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records?name=$CLOUDFLARE_DNS_RECORD" \
            -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
            -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
            -H "Content-Type: application/json")

        # Extract the current IP address and record ID from the response (using jq)
        current_ip=$(echo "$record_details" | jq -r '.result[0].content')
        record_id=$(echo "$record_details" | jq -r '.result[0].id')

        # Compare IP addresses and update Cloudflare DNS if there's a change
        if [[ "$current_ip" != "$ip_address" ]]; then
            # Update DNS record using PATCH
            update_response=$(curl --request PATCH \
                --url "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records/$record_id" \
                --header "Content-Type: application/json" \
                --header "X-Auth-Email: $CLOUDFLARE_EMAIL" \
                --header "X-Auth-Key: $CLOUDFLARE_API_KEY" \
                --data '{
                    "content": "'"$ip_address"'",
                    "name": "'"$CLOUDFLARE_DNS_RECORD"'",
                    "type": "A"
                }')

            if [[ "$update_response" == *"\"success\":true"* ]]; then  # Check for success message in response
                log "Cloudflare DNS record updated to $ip_address"
                echo -e "${GREEN}Cloudflare DNS record updated to $ip_address${NC}"
            else
                log "Error updating Cloudflare DNS record: $update_response"
                echo -e "${RED}Error updating Cloudflare DNS record: $update_response${NC}"
            fi
        else
            log "Cloudflare DNS record is already up-to-date: $ip_address."
            echo -e "${GREEN}Cloudflare DNS record is already up-to-date: $ip_address.${NC}"
        fi
    else
        log "Cloudflare credentials not provided or incomplete. Skipping DNS update."
        echo -e "${YELLOW}Cloudflare credentials not provided or incomplete. Skipping DNS update.${NC}"
    fi
}

# --- Main Script Logic ---

echo -e "${YELLOW}Starting Cloudflare Dynamic DNS Updater${NC}"
log "Starting Cloudflare Dynamic DNS Updater"

check_and_install_dependencies       # 1. Check and install dependencies (curl, jq)
check_service_status                 # 2. Check if the service is enabled and running
ip_address=$(get_valid_ip)           # 3. Get the current public IP address

if [[ -z "$ip_address" ]]; then       # Error handling: Exit if no valid IP is found
    log "ERROR: Could not obtain a valid IP address. Exiting."
    echo -e "${RED}ERROR: Could not obtain a valid IP address. Exiting.${NC}"
    exit 1
fi

if [[ -f "$IP_ADDRESS_FILE" ]]; then # Load the previous IP (if the file exists)
    previous_ip=$(cat "$IP_ADDRESS_FILE")
else
    previous_ip=""
fi

update_cloudflare_dns "$ip_address"   # 4. Update Cloudflare DNS record (if needed)

if [[ "$previous_ip" != "$ip_address" ]]; then  # 5. Save the IP and reboot if changed
    log "IP address changed to $ip_address. Saving and rebooting..."
    echo -e "${YELLOW}IP address changed to $ip_address. Saving and rebooting...${NC}"
    echo "$ip_address" > "$IP_ADDRESS_FILE"
    sreboot  # Reboot the HiveOS rig
else
    log "IP address unchanged ($ip_address). No action needed."
    echo -e "${GREEN}IP address unchanged ($ip_address). No action needed.${NC}"
fi

log "Script execution completed"
echo -e "${YELLOW}Script execution completed${NC}"
