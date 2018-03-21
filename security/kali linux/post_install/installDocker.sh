#!/bin/bash

# update apt-get
export DEBIAN_FRONTEND="noninteractive"
sudo apt-get update -y

# remove previously installed Docker
sudo apt-get purge lxc-docker* -y
sudo apt-get purge docker.io* -y


get_distribution() {
        lsb_dist=""
        # Every system that we officially support has /etc/os-release
        if [ -r /etc/os-release ]; then
                lsb_dist="$(. /etc/os-release && echo "$ID")"
        fi
        # Returning an empty string here should be alright since the
        # case statements don't act unless you provide an actual value
        echo "$lsb_dist"
}


# add Docker repo
sudo apt-get install -y apt-transport-https ca-certificates


if [ $lsb_dist != "ubuntu" ];then
sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
cat > /etc/apt/sources.list.d/docker.list << 'EOF'
deb https://apt.dockerproject.org/repo debian-stretch main
EOF
else
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
fi

sudo apt-get update -y

# install Docker
sudo apt-get install -y docker-engine
sudo service docker start
sudo docker run hello-world


# configure Docker user group permissions
sudo groupadd docker
sudo gpasswd -a ${USER} docker
sudo service docker restart

# set Docker to auto-launch on startup
sudo systemctl enable docker
