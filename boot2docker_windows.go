// +build windows

package main

import "os"
import "os/exec"

func defaultSSHPrefix() string {
	putty := "putty.exe"
	if _, err := exec.LookPath(putty); err != nil {
		putty = os.ExpandEnv("${ProgramFiles(x86)}/PuTTY/putty.exe")
	}
	// it is impossible with putty.exe to ignore host key checking
	return putty + "-ssh -P"
}

func defaultVBoxManage() string {
	VBoxManage := "VBoxManage.exe"
	if _, err := exec.LookPath(VBoxManage); err != nil {
		VBoxManage = os.ExpandEnv("${VBOX_INSTALL_PATH}/VBoxManage.exe")
	}
	return VBoxManage
}
