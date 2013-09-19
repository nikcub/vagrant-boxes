
function ssh {
	VBoxManage modifyvm "vagrant-centos62" --natpf1 "guestssh,tcp,,2222,,22"
	ssh -p 2222 root@127.0.0.1
}

function build {
	vagrant package --output centos64.box --base vagrant-centos64
	vagrant box add centos64 centos64.box
}