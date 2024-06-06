#!/bin/bash

# Replace $HOME with the default user's home directory for environmental variables related to the default user home directory

# When running with 'sudo su -c ...' the $HOME user is /root, not the VM primary admin user, so we need to find it
vmAdmin=$(cut -d: -f6 /etc/passwd | tail -2 | head -n 1)

homeDir=$(cut -d: -f6 /etc/passwd | tail -1)
sed -i "s|$HOME|$homeDir|g" /etc/environment
sed -i "s|$vmAdmin|$homeDir|g" /etc/environment

# Create the agent_env_vars script that will be ran by enableagent.sh during the pipeline agent installation
cat /etc/environment > /etc/profile.d/agent_env_vars.sh
chmod +x /etc/profile.d/agent_env_vars.sh
