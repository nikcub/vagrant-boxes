#!/bin/bash

function init_network
{

	cat > /etc/sysconfig/network-scripts/ifcfg-eth0 << EOM
DEVICE=eth0
TYPE=Ethernet
ONBOOT=yes
NM_CONTROLLED=yes
BOOTPROTO=dhcp
DEFROUTE=yes
IPV6INIT=no
EOM

	service network restart

	# yum -y install gcc make gcc-c++ kernel-devel-`uname -r` zlib-devel openssl-devel readline-devel wget git bzip2
	
	# yum -y install sqlite-devel perl dkms
}


function install_guest_additions {
	read -p "Please attach VirtualBox guest additions disk? " -n 1 -r
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
		yum -y install gcc make kernel-devel-`uname -r` perl
		mkdir /media/vbox
		mount -r /dev/cdrom /media/vbox
		sh /media/vbox/VBoxLinuxAdditions.run
		umount /media/vbox
	fi
}


function install_puppet {
	read -p "Install Puppet? (N/y) " -n 1 -r
	if [[ ! $REPLY =~ ^[Yy]$ ]]
	then
		return 1
	fi

	echo "Installing Puppet"

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

	return 0
}

function setup_server {

		cat > /etc/yum.repos.d/epel.repo << EOM
[epel]
name=epel
baseurl=https://download.fedoraproject.org/pub/epel/6/\$basearch
enabled=1
gpgcheck=0
EOM

	date > /etc/vagrant_box_build_time
	hostname vagrant-centos64

	# yum setup
	sed -i "s/^installonly_limit=[0-9]/installonly_limit=0/" /etc/yum.conf
	sed -i "s/^\[main\]/\[main\]\nclean_requirements_on_remove=yes/" /etc/yum.conf
	yum -y install yum-utils
	echo "%_install_langs   en:en_US" >> /etc/rpm/macros.dist

	# remove rules
	# rm /etc/udev/rules.d/70-persistent-net.rules
	mkdir /etc/udev/rules.d/DISABLED
	mv /etc/udev/rules.d/75-persistent-net.rules /etc/udev/rules.d/DISABLED
	ln -s /dev/null /etc/udev/rules.d/75-persistent-net-generator.rules

	# sudo setup
	sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers
	sed -i "s/^# %wheel.*NOPASSWD: ALL/%wheel        ALL=(ALL)       NOPASSWD: ALL/" /etc/sudoers
	echo 'Defaults env_keep="SSH_AUTH_SOCK"' >> /etc/sudoers

	sed -i "s/^BOOTUP=color/BOOTUP=verbose/" /etc/sysconfig/init

	# lower grub timeout
	sed -i "s/^timeout=.*/timeout=0/" /etc/grub.conf
	plymouth-set-default-theme details
	/usr/libexec/plymouth/plymouth-update-initrd
	sed -i "s/rhgb quiet//" /etc/grub.conf

	service iptables stop
	chkconfig iptables off
}

function setup_account {

	yum -y install wget 

	# Add vagrant user
	groupadd vagrant
	useradd vagrant -g vagrant -G wheel
	echo "vagrant"|passwd --stdin vagrant

	# Installing vagrant keys
	mkdir -pm 0700 /home/vagrant/.ssh
	wget --no-check-certificate 'https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub' -O /home/vagrant/.ssh/authorized_keys
	chmod 0600 /home/vagrant/.ssh/authorized_keys
	chown -R vagrant /home/vagrant/.ssh

	echo "export PATH=$PATH:/usr/sbin:/sbin" >> /home/vagrant/.bashrc

	yum -y erase wget 
}

function cleanup
{
	# cleanup
	yum -y groupremove "E-mail server" "Scalable Filesystems" "Storage Availability Tools" "iSCSI Storage Client"

	# yum -y erase kernel-devel-`uname -r` kernel-headers-`uname -r` kernel-headers kernel-devel iscsi-initiator-utils iptables-ipv6 lvm2 mdadm device-mapper-multipath postfix audit kernel-devel perl gcc-c++ cpp gcc make libstdc++-devel selinux-policy cyrus-sasl ppl hwdata device-mapper xfsprogs mysql-libs krb5-devel ncurses-devel wget 
	yum -y erase selinux-policy cyrus-sasl iptables-ipv6 mdadm gcc make kernel-devel-`uname -r` perl
	yum -y update

	package-cleanup --oldkernels --count=1 -y
	package-cleanup -q --leaves | xargs yum erase -y
	package-cleanup --leaves -q --all | xargs repoquery --installed --qf '%{nvra} - %{yumdb_info.reason}' | grep -- '- dep' | cut -d' ' -f1 | xargs yum -y erase
	# yum -y remove kernel
}

function cleanup {
	yum -y clean all

	rm -rf /tmp/*
	rm -f /root/.bash_history
	rm -f /home/vagrant/.bash_history
	rm -f /root/anaconda*
	rm -f /root/install*
	rm -f /var/log/*.log
	rm -f /var/log/*.old
	rm -f /var/log/*.syslog
	echo '' > /var/log/maillog
	echo '' > /var/log/cron
	echo '' > /var/log/lastlog
	echo '' > /var/log/secure
	echo '' > /var/log/messages
	
	rm -rf /usr/share/backgrounds
	rm -rf /usr/share/doc/*

	# remove unrequired locales to save space
	rm -f /usr/lib/locale/locale-archive
	find "/usr/share/locale/" -maxdepth 1 -type d -not -name "en_*" -not -name "." -not -name "locale" -not -name "en" -exec rm -ifr {} \;
	find "/usr/share/i18n/locales" -maxdepth 1 -type f -not -name "en_*" -not -name "."-not -name "i18n" -exec rm -ifr {} \;
	find "/usr/share/i18n/charmaps" -maxdepth 1 -type f -not -name "UTF*" -not -name "ISO-8859*" -not -name "." -exec rm -ifr {} \;

	dd if=/dev/zero of=/EMPTY bs=1M
	rm -f /EMPTY
	shutdown -h now
}

function fail {
  echo "FATAL: $*"
  exit 1
}

# install_guest_additions
# setup_server
# setup_account
install_puppet
cleanup

echo "Done."
