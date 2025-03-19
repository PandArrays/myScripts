#!/bin/bash
# This script checks if a server is up and, if it is, attempts an SSH connection.
# Customize the list below with your server names and addresses.

# Declare an associative array mapping server names to IP addresses or hostnames.
declare -A SERVERS=(
  ["Home Server"]="192.168.2.14"
  ["PC Gaming"]="192.168.2.233"
  ["MacBook Air"]="192.168.2.86"
)

# Display a menu of servers to the user.
echo "Select a server to check:"
PS3="Enter your choice (or type the number corresponding to your selection): "

# 'select' provides a built-in way to generate menus from an array.
select server in "${!SERVERS[@]}" "Quit"; do
  if [[ "$server" == "Quit" ]]; then
    echo "Exiting the script."
    exit 0
  elif [[ -n "$server" ]]; then
    server_ip=${SERVERS[$server]}
    echo "Pinging $server ($server_ip)..."
    # Ping the server with 2 packets and redirect output to avoid clutter.
    if ping -c 2 "$server_ip" >/dev/null 2>&1; then
      echo "$server is online."
      # Uncomment the next line and replace 'your_username' with your actual SSH username.
      # echo "Connecting via SSH..."
      # ssh your_username@"$server_ip"
    else
      echo "$server is down or unreachable."
    fi
    break
  else
    echo "Invalid selection. Please try again."
  fi
done
