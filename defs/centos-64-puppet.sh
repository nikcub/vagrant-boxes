#!/bin/bash

cat > /etc/yum.repos.d/epel.repo << EOM
[epel]
name=epel
baseurl=https://download.fedoraproject.org/pub/epel/6/\$basearch
enabled=1
gpgcheck=0
EOM



cat > /etc/sysconfig/network-scripts/ifcfg-eth0 << EOM
DEVICE=eth0
TYPE=Ethernet
ONBOOT=yes
NM_CONTROLLED=yes
BOOTPROTO=dhcp
DEFROUTE=yes
IPV6INIT=no
EOM

yum -y install gcc make gcc-c++ kernel-devel-`uname -r` zlib-devel openssl-devel readline-devel sqlite-devel perl wget dkms git bzip2

yum update -y

function install_guest_additions
{
	read -p "Please attach VirtualBox guest additions disk? " -n 1 -r
	echo    # (optional) move to a new line
	if [[ ! $REPLY =~ ^[Yy]$ ]]
	then
		mkdir /media/VirtualBoxGuestAdditions
		mount -r /dev/cdrom /media/VirtualBoxGuestAdditions
		cd /media/VirtualBoxGuestAdditions
		sh ./VBoxLinuxAdditions.run
		umount /media/VirtualBoxGuestAdditions
	fi
}


function install_puppet 
{
	cat > /etc/yum.repos.d/puppetlabs.repo << EOM
[puppetlabs]
name=puppetlabs
baseurl=http://yum.puppetlabs.com/el/6/products/\$basearch
enabled=1
gpgcheck=0

[puppetlabs-dependencies]
name=puppetlabdsdependencies
baseurl=http://yum.puppetlabs.com/el/6/dependencies/\$basearch
enabled=1
gpgcheck=0
EOM

	yum -y install ruby ruby-devel rubygems
	yum -y install puppet facter
	chkconfig puppet on
	service puppet start
}

# enable wheel
sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers
echo "%wheel        ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers

# lower grub timeout
sed -i "s/^timeout=.*/timeout=0/" /etc/grub.conf

# Add vagrant user
groupadd vagrant
useradd vagrant -g vagrant -G wheel
echo "vagrant"|passwd --stdin vagrant

# Installing vagrant keys
mkdir -pm 0700 /home/vagrant/.ssh
wget --no-check-certificate 'https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub' -O /home/vagrant/.ssh/authorized_keys
chmod 0600 /home/vagrant/.ssh/authorized_keys
chown -R vagrant /home/vagrant/.ssh

# cleanup
yum -y erase kernel-devel-`uname -r` kernel-headers-`uname -r` iscsi-initiator-utils iptables-ipv6 lvm2 mdadm device-mapper-multipath postfix 
yum -y clean all

dd if=/dev/zero of=/EMPTY bs=1M
rm -f /EMPTY
