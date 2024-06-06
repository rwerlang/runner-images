#!/bin/bash -e

# Create the agent_env_vars script that will be ran by enableagent.sh during the pipeline agent installation
cat /etc/environment > /etc/profile.d/agent_env_vars.sh
chmod +x /etc/profile.d/agent_env_vars.sh

# Execute all post-generation scripts
find /opt/post-generation -mindepth 1 -maxdepth 1 -type f -name *.sh -exec bash {} \;
