#!/bin/bash

#  Unix2Gui.sh
#  
#  Copyright 2024 dion <dion@levatine>
#  
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#  MA 02110-1301, USA.
#  
#  

VENT_VER="ventoy-1.0.97"

# Function to install necessary packages for each distribution
install_packages() {
    local PACKAGE_MANAGER=""
    local PACKAGE_NAME=""
    local INSTALL_COMMAND=""
    local PRE_INST=""
    local PRE_INST2=""

    # Detect the package manager and set package manager-specific variables
    if command -v yum &> /dev/null; then
        PACKAGE_MANAGER="yum"
        INSTALL_COMMAND="install"
        PRE_INST="rpm -v --import http://li.nux.ro/download/nux/RPM-GPG-KEY-nux.ro"
        PRE_INST2="sudo rpm -Uvh http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-5.el7.nux.noarch.rpm"
        PACKAGE_NAME="exfat-utils fuse-exfat zenity"
    elif command -v dnf &> /dev/null; then
        PACKAGE_MANAGER="dnf"
        INSTALL_COMMAND="install"
        PACKAGE_NAME="exfat-utils fuse-exfat zenity"
    elif command -v apt-get &> /dev/null; then
        PACKAGE_MANAGER="apt-get"
        INSTALL_COMMAND="install"
        PACKAGE_NAME="exfat-fuse zenity"
    elif command -v apt &> /dev/null; then
        PACKAGE_MANAGER="apt"
        INSTALL_COMMAND="install"
        PACKAGE_NAME="exfat-fuse zenity"
    elif command -v pacman &> /dev/null; then
        PACKAGE_MANAGER="pacman"
        INSTALL_COMMAND="-S"
        PACKAGE_NAME="exfat-utils fuse-exfat zenity"
    else
        zenity --error --text="Unsupported distribution. Exiting..."
        exit 1
    fi

    # Check if packages are installed, and if not, install them
    MISSING_PACKAGES=""
    for PACKAGE in $PACKAGE_NAME; do
        if ! dpkg-query -W -f='${Status}' "$PACKAGE" 2>/dev/null | grep -q "ok installed"; then
            MISSING_PACKAGES="$MISSING_PACKAGES $PACKAGE"
        fi
    done

    if [ -n "$MISSING_PACKAGES" ]; then
            sudo $PACKAGE_MANAGER update
            if [ -n "$PRE_INST" ]; then
                sudo $PRE_INST
            fi
            if [ -n "$PRE_INST2" ]; then
                sudo $PRE_INST2
            fi
            sudo $PACKAGE_MANAGER $INSTALL_COMMAND $MISSING_PACKAGES -y
    fi
}

# Function to list available USB devices
list_usb_devices() {
    local devices=()
    local sizes=()
    local models=()

    # Use lsblk to list all drives
    while read -r device size model rm; do
        if [ "$device" == "NAME" ] && [ "$size" == "SIZE" ] && [ "$model" == "MODEL" ] && [ "$rm" == "RM" ]; then
            continue
        fi
        devices+=("$device")
        sizes+=("$size")
        models+=("$model")
    done < <(lsblk -ndo NAME,SIZE,MODEL,RM /dev/sd[a-z])

    # Display the list of available USB devices using Zenity's list dialog
    local selected_device=$(zenity --list \
        --title="Select USB Device" \
        --text="Available USB devices:" \
        --column="USB Devices" \
        "${devices[@]}" \
        --height=200 \
        --width=300 \
        2>/dev/null)
    
    if [ -z "$selected_device" ]; then
        zenity --info --text="No device selected. Exiting..."
        exit 0
    fi

    # Proceed with installation
    install_Unix2usb "$selected_device"
}

if [ -d "${VENT_VER}" ]; then
    cd "$VENT_VER" || exit
else
    cd "$(pwd)/Unix2usb/$VENT_VER" || exit
fi

prompt_installation() {
    local selected_device="$1"
    local from_gui="$2"
    
    # Check if the script is running in a GUI environment
    if [ -n "$DISPLAY" ]; then
        if ! zenity --question --text="Do you want to continue?" > /dev/null 2>&1; then
            zenity --info --text="Installation canceled. Returning to main menu..."
            exit 0
        fi
    else
        echo "Error: GUI mode is not available. Please run the script in a graphical environment." >&2
        exit 1
    fi
}

# Function to install Unix2usb boot files
install_Unix2usb() {
    local selected_device="$1"
    local from_gui="$2"
    local mountpoint

    # Getting mountpoint
    mountpoint=$(df -P "/dev/${selected_device}1" | awk 'NR==2 {print $6}')

    # Prompt user for installation confirmation
    if prompt_installation "$selected_device" "$from_gui"; then
        # Start installation process
        (
            # Execute installation commands inside a subshell to capture output
            sudo umount "/dev/$selected_device" > /dev/null 2>&1
            if [ -d "${mountpoint}/UNIX" ]; then
                sudo umount "/dev/$selected_device"
                echo -e "\n"
                echo "Unix2usb is already installed. But you can upgrade or reinstall."
                sudo ./Unix2Disk.sh -u -L UNIX "/dev/$selected_device"
            else
                sudo umount "/dev/$selected_device"
                echo -e "\n"
                echo "This device has not yet been prepared."
                sudo ./Unix2Disk.sh -I -L UNIX "/dev/$selected_device"
            fi
            echo "$?"  
        ) | zenity --progress \
            --title="Unix2usb Installation" \
            --text="Installing Unix2usb on /dev/${selected_device} Please wait..." \
            --percentage=0 \
            --auto-close \
            --width=500 \
            --pulsate \

        # Check the exit status of the installation process
        if [ "${PIPESTATUS[0]}" -ne 0 ]; then
            # Installation was canceled or failed, display appropriate message and exit
            zenity --info --text="Installation canceled. Returning to main menu..."
            exit 0
        else
            # Installation was successful, display success message
            zenity --info \
            --title="Installation Complete" \
            --text="Unix2usb installed successfully on $selected_device.\n\nNow you can simply copy and paste ISO files into the 'ISO' folder on your USB.\nISO files stored there will be detected and presented in a menu during USB boot." \
            --width=300
        fi
    fi

    list_usb_devices
}

# Main script starts here
install_packages
list_usb_devices