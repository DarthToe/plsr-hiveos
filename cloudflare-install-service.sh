#!/bin/bash

# Service name and associated files
SERVICE_NAME="cloudflare-ddns"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
TIMER_NAME="${SERVICE_NAME}.timer"
TIMER_FILE="/etc/systemd/system/${TIMER_NAME}"
SCRIPT_NAME="cloudflare-ddns.sh"  # Assuming your main script is in the same directory

# Function to install the script as a systemd service
install_service() {
    # Determine absolute script path (with better error message)
    local script_path=$(realpath "$SCRIPT_NAME")
    if [[ -z "$script_path" ]]; then
        echo "Error: Cannot find script '$SCRIPT_NAME' in the current directory." >&2
        exit 1
    fi

    # Service file configuration
    service_content="[Unit]
Description=ddns

[Service]
Type=oneshot
ExecStart=$script_path
User=root

[Install]
WantedBy=multi-user.target"

    # Write service file with error handling
    if ! echo "$service_content" | sudo tee "$SERVICE_FILE" > /dev/null; then
        echo "Error creating service file. Check permissions and try again." >&2
        exit 1
    fi
}

# Function to install the timer for hourly execution
install_timer() {
    # Timer file configuration
    timer_content="[Unit]
Description=Run Cloudflare Dynamic DNS Updater Hourly

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target"

    # Write timer file with error handling
    if ! echo "$timer_content" | sudo tee "$TIMER_FILE" > /dev/null; then
        echo "Error creating timer file. Check permissions and try again." >&2
        exit 1
    fi
}

# --- Main Script Execution ---

# Stop and disable any existing service and timer
sudo systemctl stop "$SERVICE_NAME.service" "$TIMER_NAME"
sudo systemctl disable "$SERVICE_NAME.service" "$TIMER_NAME"

# Remove any existing service and timer files
sudo rm -f "$SERVICE_FILE" "$TIMER_FILE"

# Install the service and timer afresh
echo "Installing service '$SERVICE_NAME'..."
install_service

echo "Installing timer '$TIMER_NAME'..."
install_timer

# Reload systemd and ensure service/timer are enabled and running
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME.service"
sudo systemctl start "$SERVICE_NAME.service"
sudo systemctl enable "$TIMER_NAME"
sudo systemctl start "$TIMER_NAME"

echo "Installation complete. Check status with 'systemctl status $SERVICE_NAME.service'"
