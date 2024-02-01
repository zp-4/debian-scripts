#!/bin/bash
# -------------------------------------------------------------------------------------------------
# [zp-4]  post-install.sh
#               Network and System Configuration Script.
#               This script configures the hostname, network settings (static IP or DHCP),
#               tests Internet connectivity, manages the root password, adds a new user
#               with sudo privileges, removes a specified user (kizaru), checks for a desktop 
#               environment and offers to change or remove it, updates the system, installs 
#               the SSH server, and cleans up unused packages. It includes error handling 
#               to ensure each key step completes successfully.
# ------------------------------------------------------------------------------------------------
# Date: 2024-02-02
# Version: 1.0.0
# Maintained by: zp-4
# GitHub: https://github.com/zp-4/debian-scripts
# ------------------------------------------------------------------------------------------------


# Ensure the script is executed as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Change the hostname
read -p "Enter the new hostname: " newhostname
hostnamectl set-hostname "$newhostname"
echo "Hostname updated."

# Configure the network
read -p "Do you want a static IP? (y/n): " choice_ip
if [ "$choice_ip" = "y" ]; then
    read -p "Enter the network interface (e.g., eth0): " interface
    read -p "Enter the static IP address (e.g., 192.168.1.10): " ip_static
    read -p "Enter the subnet mask (e.g., 255.255.255.0): " netmask
    read -p "Enter the default gateway (e.g., 192.168.1.1): " gateway
    read -p "Enter the primary DNS (e.g., 8.8.8.8): " dns1
    read -p "Enter the secondary DNS (e.g., 8.8.4.4): " dns2

    cat > /etc/network/interfaces <<EOF
auto $interface
iface $interface inet static
    address $ip_static
    netmask $netmask
    gateway $gateway
    dns-nameservers $dns1 $dns2
EOF
    echo "Network configuration updated. Restarting network interface."
    ifdown "$interface" && ifup "$interface" || {
        echo "Network configuration failed. Check the settings and retry."
        exit 1
    }
else
    echo "Configuring DHCP for the network interface."
    read -p "Enter the network interface for DHCP (e.g., eth0): " interface_dhcp
    cat > /etc/network/interfaces <<EOF
auto $interface_dhcp
iface $interface_dhcp inet dhcp
EOF
    echo "Restarting network interface."
    ifdown "$interface_dhcp" && ifup "$interface_dhcp" || {
        echo "DHCP configuration failed. Check the settings and retry."
        exit 1
    }
fi

# Test Internet connectivity
echo "Testing Internet connectivity..."
if ! ping -c 4 8.8.8.8 &>/dev/null; then
    echo "Network connectivity failed. Check your network configuration or router."
    exit 1
fi

if ! ping -c 4 google.com &>/dev/null; then
    echo "DNS name resolution problem. Check your DNS configuration."
    exit 1
fi

echo "Internet connectivity confirmed."

# Change the root password
echo "Change the root password."
passwd root

# Add a new user
read -p "Enter the name of the new user: " username
adduser "$username"
adduser "$username" sudo

# Add the user to the sudoers file
echo "$username ALL=(ALL) ALL" >> /etc/sudoers

# Remove the user kizaru
deluser --remove-home kizaru

# Check the desktop environment
current_desktop=$(echo $XDG_CURRENT_DESKTOP)

if [ -n "$current_desktop" ]; then
    echo "Current desktop environment: $current_desktop"
    read -p "Do you want to change or remove it? (change/remove/nothing): " action_desktop
    case "$action_desktop" in
        change)
            read -p "Choose a new environment (xfce, kde, gnome): " new_desktop
            read -p "Do you want to remove the old desktop environment? (y/n): " remove_old
            if [ "$remove_old" = "y" ]; then
                echo "Removing the old desktop environment..."
                apt remove --purge $current_desktop-desktop* || {
                    echo "Failed to remove the desktop environment."
                    exit 1
                }
            fi
            echo "Installing the $new_desktop desktop environment..."
            apt install -y $new_desktop-desktop || {
                echo "Failed to install the new desktop environment."
                exit 1
            }
            ;;
        remove)
            echo "Removing the desktop environment..."
            apt remove --purge $current_desktop-desktop* || {
                echo "Failed to remove the desktop environment."
                exit 1
            }
            ;;
        nothing)
            ;;
        *)
            echo "Unrecognized action. No changes made."
            ;;
    esac
else
    echo "No desktop environment detected."
fi

# Update the system
echo "Updating the system..."
apt update && apt upgrade -y && apt dist-upgrade -y || {
    echo "System update failed. Check your Internet connection and retry."
    exit 1
}

# Install the SSH server
echo "Installing the SSH server..."
apt install -y openssh-server || {
    echo "Failed to install the SSH server. Check your Internet connection and retry."
    exit 1
}

# Clean up unused packages and update the system
echo "Cleaning up unused packages and final update..."
apt autoremove -y
apt autoclean -y || {
    echo "Failed to clean up packages. Check your system and retry."
    exit 1
}

echo "Configuration completed."
