#!/bin/bash -e

# run all post-generation scripts
# https://github.com/actions/runner-images/blob/main/docs/create-image-and-azure-resources.md#post-generation-scripts

echo "run all post-generation scripts ..."
find /opt/post-generation -mindepth 1 -maxdepth 1 -type f -name "*.sh" -exec bash {} \;

echo "succeeded!"
echo ""

# get path from etc/environment
echo "update path variable"
source /etc/environment
echo $PATH

# update /etc/sudoers secure_path
sed -i.bak "/secure_path/d" /etc/sudoers
echo "Defaults secure_path=$PATH" >> /etc/sudoers

# debug
cat /etc/sudoers
