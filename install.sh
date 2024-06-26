#!/usr/bin/env bash

(echo -e "$(date -u) Spolot installation started.") >> $PWD/data/log.txt
sudo apt update
read -p "Enter IPFS port(default 4002): " IPFSPORT
if [ -z "$IPFSPORT" ]; then
    IPFSPORT=4002
fi

arch=$(uname -m)
if [[ "$arch" == "x86_64" ]]; then
    ipfsdistr="https://github.com/ipfs/kubo/releases/download/v0.29.0/kubo_v0.29.0_linux-amd64.tar.gz"
elif [[ "$arch" == "aarch64" ]]; then
    ipfsdistr="https://github.com/ipfs/kubo/releases/download/v0.29.0/kubo_v0.29.0_linux-arm64.tar.gz"
fi

mkdir -p temp apps data/share/log
echo PATH="$PATH:/home/$USER/.local/bin:$PWD/bin" | sudo tee /etc/environment
echo SPOLOT="$PWD" | sudo tee -a /etc/environment
echo IPFS_PATH="$PWD/data/.ipfs" | sudo tee -a /etc/environment
source /etc/environment
echo -e "PATH=$PATH\nSPOLOT=$PWD\nIPFS_PATH=$IPFS_PATH\n$(sudo crontab -l)\n" | sudo crontab -
sudo DEBIAN_FRONTEND=noninteractive apt full-upgrade -yq
sudo DEBIAN_FRONTEND=noninteractive apt install -y docker.io docker-compose build-essential python3-dev python3-pip python3-venv tmux links2 cron btop
sudo usermod -aG docker $USER
sudo sh -c 'echo "{\"registry-mirrors\": [\"https://mirror.gcr.io\", \"https://daocloud.io\", \"https://c.163.com/\", \"https://huecker.io/\", \"https://registry.docker-cn.com\"]}" > /etc/docker/daemon.json'
sudo systemctl restart docker
python3 -m venv venv
source venv/bin/activate
pip install reader[cli] -q

sudo mkdir /ipfs /ipns
sudo chmod 777 /ipfs
sudo chmod 777 /ipns
export IPFS_PATH=$PWD/data/.ipfs
wget -O temp/kubo.tar.gz $ipfsdistr
tar xvzf temp/kubo.tar.gz -C temp
sudo mv temp/kubo/ipfs /usr/local/bin/ipfs
ipfs init --profile server
ipfs config --json Experimental.FilestoreEnabled true
ipfs config --json Pubsub.Enabled true
ipfs config --json Ipns.UsePubsub true
ipfs config profile apply lowpower
ipfs config Addresses.Gateway /ip4/127.0.0.1/tcp/8082
ipfs config Addresses.API /ip4/127.0.0.1/tcp/5002
sed -i "s/4001/$IPFSPORT/g" $PWD/data/.ipfs/config
sed -i "s/104.131.131.82\/tcp\/$IPFSPORT/104.131.131.82\/tcp\/4001/g" $PWD/data/.ipfs/config
sed -i "s/104.131.131.82\/udp\/$IPFSPORT/104.131.131.82\/udp\/4001/g" $PWD/data/.ipfs/config
echo -e "\
[Unit]\n\
Description=InterPlanetary File System (IPFS) daemon\n\
Documentation=https://docs.ipfs.tech/\n\
After=network.target\n\
\n\
[Service]\n\
MemorySwapMax=0\n\
TimeoutStartSec=infinity\n\
Type=notify\n\
User=$USER\n\
Group=$USER\n\
Environment=IPFS_PATH=$PWD/data/.ipfs\n\
ExecStart=/usr/local/bin/ipfs daemon --enable-gc --mount --mount-ipfs=/ipfs --mount-ipns=/ipns --migrate=true\n\
Restart=on-failure\n\
KillSignal=SIGINT\n\
\n\
[Install]\n\
WantedBy=default.target\n\
" | sudo tee /etc/systemd/system/ipfs.service
sudo systemctl daemon-reload
sudo systemctl enable ipfs
sudo systemctl restart ipfs

cat <<EOF >>$PWD/bin/ipfssub.sh
#!/usr/bin/env bash

/usr/local/bin/ipfs pubsub sub spolot >> $PWD/data/sub.txt
EOF
chmod +x $PWD/bin/ipfssub.sh

echo -e "\
[Unit]\n\
Description=InterPlanetary File System (IPFS) subscription\n\
After=network.target\n\
\n\
[Service]\n\
Type=simple\n\
User=$USER\n\
Group=$USER\n\
Environment=IPFS_PATH=$PWD/data/.ipfs\n\
ExecStartPre=/usr/bin/sleep 5\n\
ExecStart=$PWD/bin/ipfssub.sh\n\
Restart=on-failure\n\
KillSignal=SIGINT\n\
\n\
[Install]\n\
WantedBy=default.target\n\
" | sudo tee /etc/systemd/system/ipfssub.service
sudo systemctl daemon-reload
sudo systemctl enable ipfssub
sudo systemctl restart ipfssub
sleep 9

echo -e "$(sudo crontab -l)\n@reboot echo \"\$(date -u) System is rebooted\" >> $PWD/data/log.txt\n* * * * * su $USER -c \"bash $PWD/bin/cron.sh\"" | sudo crontab -

sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt install -y ca-certificates curl gnupg
sudo rm /etc/apt/keyrings/nodesource.gpg
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
NODE_MAJOR=22
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
sudo apt-get update && sudo apt-get install nodejs -y
node -v
npm -v

echo -n "IPFS status:"
ipfs cat QmYwoMEk7EvxXi6LcS2QE6GqaEYQGzfGaTJ9oe1m2RBgfs/test.txt
echo -n "IPFSmount status:"
cat /ipfs/QmYwoMEk7EvxXi6LcS2QE6GqaEYQGzfGaTJ9oe1m2RBgfs/test.txt

cd $SPOLOT
sleep 9
rm -rf temp
mkdir temp
str=$(ipfs id) && echo $str | cut -c10-61 > $PWD/data/id.txt
(echo -n "$(date -u) Spolot system is installed. ID=" && cat $PWD/data/id.txt) >> $PWD/data/log.txt
ipfspub 'Initial message'
ipfs pubsub pub spolot $PWD/data/log.txt
sudo reboot
