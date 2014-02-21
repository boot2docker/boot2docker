// +build !windows

package main

func defaultSSHPrefix() string {
	return "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p"
}

func defaultVboxManage() string {
	return "VBoxManage"	
}
