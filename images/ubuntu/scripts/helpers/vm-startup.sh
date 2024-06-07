#!/bin/bash -e

echo "creating AzDevOps account ..."
# https://vstsagenttools.blob.core.windows.net/tools/ElasticPools/Linux/<script_version>/enableagent.sh

sudo useradd -m AzDevOps
sudo usermod -a -G docker AzDevOps
sudo usermod -a -G adm AzDevOps
sudo usermod -a -G sudo AzDevOps

echo "giving AzDevOps user access to the '/home' directory"
sudo chmod -R +r /home
setfacl -Rdm "u:AzDevOps:rwX" /home
setfacl -Rb /home/AzDevOps
echo 'AzDevOps ALL=NOPASSWD: ALL' >> /etc/sudoers

echo "succeeded!"
echo ""

# run all post-generation scripts
# https://github.com/actions/runner-images/blob/main/docs/create-image-and-azure-resources.md#post-generation-scripts

echo "run all post-generation scripts ... "
find /opt/post-generation -mindepth 1 -maxdepth 1 -type f -name "*.sh" -exec bash {} \;

echo "succeeded!"
echo ""

# get path from etc/environment
echo "update path variable ... "
source /etc/environment

# update /etc/sudoers secure_path
sed -i.bak "/secure_path/d" /etc/sudoers
echo "Defaults secure_path=$PATH" >> /etc/sudoers

echo "succeeded!"
