#!/bin/bash

# Define the list of configuration items
options=("locales" "tzdata" "keyboard-configuration" "console-setup" "Exit")

echo "==============================================="
echo "   Debian/Ubuntu System Configuration Tool"
echo "==============================================="

# Use 'select' to create the interactive menu
PS3="Please enter the number of the item to configure: "

select opt in "${options[@]}"
do
    case $opt in
        "locales")
            echo ">>> Running: dpkg-reconfigure locales"
            dpkg-reconfigure locales
            ;;
        "tzdata")
            echo ">>> Running: dpkg-reconfigure tzdata"
            dpkg-reconfigure tzdata
            ;;
        "keyboard-configuration")
            echo ">>> Running: dpkg-reconfigure keyboard-configuration"
            dpkg-reconfigure keyboard-configuration
            ;;
        "console-setup")
            echo ">>> Running: dpkg-reconfigure console-setup"
            dpkg-reconfigure console-setup
            ;;
        "Exit")
            echo "Exiting configuration tool. Goodbye!"
            break
            ;;
        *)
            echo "Invalid option: $REPLY. Please choose a number between 1 and ${#options[@]}."
            ;;
    esac
    
    echo -e "\n--- Task completed. Select another or Exit. ---\n"
done