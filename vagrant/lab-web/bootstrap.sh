#!/bin/bash

TIME_ZONE_FILE=/usr/share/zoneinfo/Asia/Yerevan

function _ensure_lsb_release {
    if type lsb_release >/dev/null 2>&1; then
        return
    fi

    if type apt-get >/dev/null 2>&1; then
        apt-get -y install lsb-release
    elif type yum >/dev/null 2>&1; then
        yum -y install redhat-lsb-core
    fi
}

function _is_distro {
    if [[ -z "$DISTRO" ]]; then
        _ensure_lsb_release
        DISTRO=$(lsb_release -si)
    fi

    [[ "$DISTRO" == "$1" ]]
}

function is_ubuntu {
    _is_distro "Ubuntu"
}

function is_centos {
    _is_distro "CentOS"
}

# Install common packages and do some post deploy.
function prep_work {

    # This removes the fqdn from /etc/hosts's 127.0.0.1. This name.local will
    # resolve to the public IP instead of localhost.
    sudo sed -i -r "s,^127\.0\.0\.1\s+.*,127\.0\.0\.1   localhost localhost.localdomain localhost4 localhost4.localdomain4," /etc/hosts

    if is_centos; then
        if [[ "$(systemctl is-enabled firewalld)" == "enabled" ]]; then
            sudo systemctl stop firewalld
            sudo systemctl disable firewalld
        fi
        sudo yum -y install epel-release
        sudo yum update -y
        sudo yum groupinstall "Development tools" -y
        sudo yum -y install install rsync vim sysstat python3 python-pip man python-devel gcc openssl-devel ansible -y
        sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/sysconfig/selinux
        sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
        setenforce 0
    elif is_ubuntu; then
        if [[ "$(systemctl is-enabled ufw)" == "enabled" ]]; then
            sudo systemctl stop ufw
            sudo systemctl disable ufw
        fi
        sudo apt-get update -y
        sudo apt-get -y install rsync vim build-essential man net-tools automake python3 python-pip sysstat python-dev screen iptables
        sudo apt-get install software-properties-common -y
        sudo apt-add-repository ppa:ansible/ansible
        sudo apt-get update -y
        sudo apt-get install ansible -y
        sudo apt-get purge apparmor -y
 

    else
        echo "Unsupported Distro: $DISTRO" 1>&2
        exit 1
    fi
}

# Do some cleanup after the installation of kolla
function cleanup {
    if is_centos; then
        yum clean all
    elif is_ubuntu; then
        apt-get clean
    else
        echo "Unsupported Distro: $DISTRO" 1>&2
        exit 1
    fi
}

configureShell() {
  # ===================================================================
  # Set up annoying shell and vim configs for root.
  # ===================================================================
  value=$(grep -c "set -o vi" ~root/.bashrc)
  if [ $value -eq 0 ]; then
    echo 'set -o vi' >> ~root/.bashrc
  fi

  if [ ! -f ~root/.vimrc ]; then
    touch ~root/.vimrc
  fi

  value=$(grep -c "set tabstop=2" ~root/.vimrc)
  if [ $value -eq 0 ]; then
    echo 'set tabstop=2' >> ~root/.vimrc
  fi

  # ===================================================================
  # Setting up annoying shell and vim configs for vagrant.
  # ===================================================================
  value=$(grep -c "set -o vi" ~vagrant/.bashrc)
  if [ $value -eq 0 ]; then
    echo 'set -o vi' >> ~vagrant/.bashrc
  fi

  if [ ! -f ~vagrant/.vimrc ]; then
    touch ~vagrant/.vimrc
    chown vagrant.vagrant ~vagrant/.vimrc
  fi

  value=$(grep -c "set tabstop=2" ~vagrant/.vimrc)
  if [ $value -eq 0 ]; then
    echo 'set tabstop=2' >> ~vagrant/.vimrc
  fi

}


printLog "Setting Timzone for host";
mv /etc/localtime /etc/localtime.orig
ln -s $TIME_ZONE_FILE /etc/localtime

prep_work;
configureShell;
cleanup;