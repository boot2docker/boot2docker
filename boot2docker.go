// This is the boot2docker management script.
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"regexp"
	"runtime"
	"time"
)

// boot2docker config
var B2D struct {
	Vbm         string // VirtualBox management utility
	VM          string // boot2docker virtual machine name
	Dir         string // boot2docker directory
	Iso         string // boot2docker ISO image path
	Disk        string // boot2docker disk image path
	DiskSize    string // boot2docker disk image size (MB)
	Memory      string // boot2docker memory size (MB)
	SshHostPort string // boot2docker host SSH port
	DockerPort  string // boot2docker docker port
	Ssh         string // ssh executable
}

// helper function to get env var with default values
func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func init() {
	u, err := user.Current()
	if err != nil {
		log.Fatalf("cannot get current user: %s", err)
	}
	B2D.Vbm = getenv("BOOT2DOCKER_VBM", "VBoxManage")
	B2D.VM = getenv("BOOT2DOCKER_VM", "boot2docker-vm")
	B2D.Dir = getenv("BOOT2DOCKER_DIR", filepath.Join(u.HomeDir, ".boot2docker"))
	B2D.Iso = getenv("BOOT2DOCKER_ISO", filepath.Join(B2D.Dir, "boot2docker.iso"))
	B2D.Disk = getenv("BOOT2DOCKER_DISK", filepath.Join(B2D.Dir, "boot2docker.vmdk"))
	B2D.DiskSize = getenv("BOOT2DOCKER_DISKSIZE", "20000")
	B2D.Memory = getenv("BOOT2DOCKER_MEMORY", "1000")
	B2D.SshHostPort = getenv("BOOT2DOCKER_SSH_HOST_PORT", "2022")
	B2D.DockerPort = getenv("BOOT2DOCKER_DOCKER_PORT", "4243")
	B2D.Ssh = getenv("BOOT2DOCKER_DOCKER_SSH", "ssh")
}

type vmState int

const (
	vmUnknown vmState = iota
	vmRunning
	vmStopped
	vmPaused
	vmSuspended
	vmAborted
)

func main() {
	flag.Parse()

	vm := flag.Arg(1)
	if vm == "" {
		vm = B2D.VM // use default vm if not specified otherwise
	}

	// TODO maybe use reflect here?
	switch flag.Arg(0) { // choose subcommand
	case "download":
		cmdDownload()
	case "init":
		cmdInit(vm)
	case "start", "up":
		cmdStart(vm)
	case "ssh":
		cmdSsh(vm)
	case "resume":
		cmdResume(vm)
	case "save", "pause", "suspend":
		cmdSuspend(vm)
	case "halt", "down", "stop":
		cmdStop(vm)
	case "restart":
		cmdRestart(vm)
	case "info":
		cmdInfo(vm)
	case "status":
		cmdStatus(vm)
	case "delete":
		cmdDelete(vm)
	default:
		help()
	}
}

func cmdSsh(vm string) {
	if !installed(vm) {
		cmdStatus(vm)
		return
	}
	state := status(vm)
	if state != vmRunning {
		log.Fatalf("%s is not running.", vm)
	}
	err := cmd(B2D.Ssh, "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null", "-p", B2D.SshHostPort, "docker@localhost")
	if err != nil {
		log.Fatal(err)
	}
}
func cmdStart(vm string) {
	if !installed(vm) {
		cmdStatus(vm)
		return
	}
	state := status(vm)
	if state == vmRunning {
		log.Printf("%s is already running.", vm)
		return
	}

	if state == vmPaused {
		log.Printf("Resuming %s", vm)
		vbm("controlvm", vm, "resume")
		waitVM()
		log.Printf("Resumed.")
	} else {
		log.Printf("Starting %s...", vm)
		vbm("startvm", vm, "--type", "headless")
		waitVM()
		log.Printf("Started.")
	}

	// check if $DOCKER_HOST is properly configured
	DockerHost := getenv("DOCKER_HOST", "")
	if DockerHost != "tcp://localhost:"+B2D.DockerPort {
		fmt.Printf("\nTo connect the docker client to the Docker daemon, please set:\n")
		fmt.Printf("export DOCKER_HOST=tcp://localhost:%s\n\n", B2D.DockerPort)
	}
}

// ping boot2docker VM until it's started
func waitVM() {
	addr := fmt.Sprintf("localhost:%s", B2D.SshHostPort)
	for !ping(addr) {
		time.Sleep(1 * time.Second)
	}
}

func cmdResume(vm string) {
	if status(vm) == vmSuspended {
		vbm("controlvm", vm, "resume")
	} else {
		log.Printf("%s is not suspended.", vm)
	}
}

func cmdSuspend(vm string) {
	if !installed(vm) {
		cmdStatus(vm)
	}
	if status(vm) == vmRunning {
		log.Printf("Suspending %s", vm)
		vbm("controlvm", vm, "savestate")
	} else {
		log.Printf("%s is not running.", vm)
	}
}

func cmdStop(vm string) {
	if !installed(vm) {
		cmdStatus(vm)
	}

	if status(vm) == vmRunning {
		log.Printf("Shutting down %s...", vm)
		vbm("controlvm", vm, "acpipowerbutton")
		for status(vm) == vmRunning {
			time.Sleep(1 * time.Second)
		}
	} else {
		log.Printf("%s is not running.", vm)
	}
}

func cmdRestart(vm string) {
	if !installed(vm) {
		cmdStatus(vm)
	}

	state := status(vm)
	if state == vmRunning {
		cmdStop(vm)
		time.Sleep(1 * time.Second)
		cmdStart(vm)
	} else {
		cmdStart(vm)
	}
}

func cmdInfo(vm string) {
	if installed(vm) {
		b, _ := vminfo(vm)
		fmt.Printf("%s", b)
	} else {
		fmt.Printf("%s does not exist.\n", vm)
	}
}

func cmdStatus(vm string) {
	switch status(vm) {
	case vmRunning:
		fmt.Printf("%s is running.\n", vm)
	case vmPaused:
		log.Fatalf("%s is paused.", vm)
	case vmSuspended:
		log.Fatalf("%s is suspended.", vm)
	case vmStopped:
		log.Fatalf("%s is stopped.", vm)
	case vmAborted:
		log.Fatalf("%s is aborted.")
	default:
		log.Fatalf("%s does not exist.", vm)
	}
}

func cmdInit(vm string) {
	if installed(vm) {
		log.Fatalf("%s already exists.\n")
	}

	if ping(fmt.Sprintf("localhost:%s", B2D.DockerPort)) {
		log.Fatalf("DOCKER_PORT=%s on localhost is occupied. Please choose another port.", B2D.DockerPort)
	}

	if ping(fmt.Sprintf("localhost:%s", B2D.SshHostPort)) {
		log.Fatalf("SSH_HOST_PORT=%s on localhost is occupied. Please choose another port.", B2D.SshHostPort)
	}

	log.Printf("Creating VM %s", vm)
	vbm("createvm", "--name", vm, "--register")
	if vbm("modifyvm", vm,
		"--ostype", "Linux26_64",
		"--cpus", fmt.Sprintf("%d", runtime.NumCPU()),
		"--memory", B2D.Memory,
		"--rtcuseutc", "on",
		"--acpi", "on",
		"--ioapic", "on",
		"--hpet", "on",
		"--hwvirtex", "on",
		"--vtxvpid", "on",
		"--largepages", "on",
		"--nestedpaging", "on",
		"--firmware", "bios",
		"--bioslogofadein", "off",
		"--bioslogofadeout", "off",
		"--bioslogodisplaytime", "0",
		"--biosbootmenu", "disabled",
		"--boot1", "dvd") != nil {
		log.Fatal("An error occured, upgrade VirtualBox")
		cmdDelete(vm)
	}

	log.Printf("Setting VM networking")
	vbm("modifyvm", vm, "--nic1", "nat", "--nictype1", "virtio", "--cableconnected1", "on")
	vbm("modifyvm", vm,
		"--natpf1", fmt.Sprintf("ssh,tcp,127.0.0.1,%s,,22", B2D.SshHostPort),
		"--natpf1", fmt.Sprintf("docker,tcp,127.0.0.1,%s,,4243", B2D.DockerPort))

	_, err := os.Stat(B2D.Iso)
	if err != nil {
		if os.IsNotExist(err) {
			cmdDownload()
		} else {
			log.Fatalf("failed to open ISO image: %s", err)
		}
	}
	_, err = os.Stat(B2D.Disk)
	if err != nil {
		if os.IsNotExist(err) {
			err := makeDiskImage()
			if err != nil {
				log.Fatalf("failed to create disk image: %s", err)
			}
		} else {
			log.Fatalf("failed to open disk image: %s", err)
		}
	}

	log.Printf("Setting VM disks")
	vbm("storagectl", vm, "--name", "SATA", "--add", "sata", "--hostiocache", "on")
	vbm("storageattach", vm, "--storagectl", "SATA", "--port", "0", "--device", "0", "--type", "dvddrive", "--medium", B2D.Iso)
	vbm("storageattach", vm, "--storagectl", "SATA", "--port", "1", "--device", "0", "--type", "hdd", "--medium", B2D.Disk)

	log.Printf("Done.")
	log.Printf("You can now type `boot2docker up` and wait for the VM to start.")
}

func cmdDownload() {
	log.Printf("downloading boot2docker ISO image...")
	tag, err := getLatestReleaseName()
	if err != nil {
		log.Fatalf("failed to get latest release: %s", err)
	}
	log.Printf("  %s", tag)
	err = download(B2D.Iso, tag)
	if err != nil {
		log.Fatalf("failed to download ISO image: %s", err)
	}
}

func cmdDelete(vm string) {
	state := status(vm)
	if state == vmStopped || state == vmAborted {
		vbm("unregistervm", "--delete", vm)
		return
	}
	log.Fatalf("%s needs to be stopped to delete it.", vm)
}

// convenient function to exec a command
func cmd(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// convenient function to launch VBoxManage
func vbm(args ...string) error {
	return cmd(B2D.Vbm, args...)
}

// get the latest boot2docker release tag e.g. v0.5.4
func getLatestReleaseName() (string, error) {
	rsp, err := http.Get("https://api.github.com/repos/steeve/boot2docker/releases")
	if err != nil {
		return "", err
	}
	defer rsp.Body.Close()

	var t []struct {
		TagName string `json:"tag_name"`
	}
	err = json.NewDecoder(rsp.Body).Decode(&t)
	if err != nil {
		return "", err
	}
	if len(t) == 0 {
		return "", fmt.Errorf("no releases found")
	}
	return t[0].TagName, nil
}

// download boot2docker ISO for the given tag and save it at dest
func download(dest, tag string) error {
	rsp, err := http.Get(fmt.Sprintf("https://github.com/steeve/boot2docker/releases/download/%s/boot2docker.iso", tag))
	if err != nil {
		return err
	}
	defer rsp.Body.Close()
	f, err := os.Create(dest)
	if err != nil {
		return err
	}
	_, err = io.Copy(f, rsp.Body)
	return err
}

// check if we already have the virtual machine in VirtualBox
func installed(vm string) bool {
	stdout, _ := exec.Command(B2D.Vbm, "list", "vms").Output()
	matched, _ := regexp.Match(fmt.Sprintf(`(?m)^"%s"`, regexp.QuoteMeta(vm)), stdout)
	return matched
}

// get the state of a VM
func status(vm string) vmState {
	b, err := vminfo(vm)
	if err != nil {
		return vmUnknown
	}
	re := regexp.MustCompile(`(?m)^State:\s+(\w+)`)
	groups := re.FindSubmatch(b)
	if len(groups) < 1 {
		return vmUnknown
	}
	switch string(groups[1]) {
	case "running":
		return vmRunning
	case "paused":
		return vmPaused
	case "saved":
		return vmSuspended
	case "powered": // it's actually "powered off"
		return vmStopped
	case "aborted":
		return vmAborted
	default:
		return vmUnknown
	}
}

// print help message
func help() {
	log.Fatalf("Usage: %s {init|start|up|ssh|save|pause|stop|restart|resume|status|info|delete|download} [vm]", os.Args[0])
}

// get VM info
func vminfo(vm string) (stdout []byte, err error) {
	cmd := exec.Command(B2D.Vbm, "showvminfo", vm)
	stdout, err = cmd.Output()
	return
}

// check if an addr can be successfully connected
func ping(addr string) bool {
	conn, err := net.Dial("tcp", addr)
	if err != nil {
		return false
	}
	defer conn.Close()
	return true
}

func makeDiskImage() error {
	log.Printf("Creating %s MB hard disk image...", B2D.DiskSize)
	vbm("createhd", "--format", "VMDK", "--filename", B2D.Disk, "--size", B2D.DiskSize)

	// We do the following so boot2docker vm will auto-format the disk for us
	// upon first boot.
	const tmp_flag_file = "format-flag.txt"
	const tmp_vmdk_file = "format-flag.vmdk"
	f, err := os.Create(tmp_flag_file)
	if err != nil {
		return err
	}
	err = f.Truncate(5 * 1024 * 1024) // 5MB
	if err != nil {
		return err
	}
	_, err = f.WriteString("boot2docker, please format-me\n")
	if err != nil {
		return err
	}
	err = f.Close()
	if err != nil {
		return err
	}

	vbm("convertfromraw", tmp_flag_file, tmp_vmdk_file, "--format", "VMDK")
	vbm("clonehd", tmp_vmdk_file, B2D.Disk, "--existing")
	vbm("closemedium", "disk", tmp_vmdk_file)
	os.Remove(tmp_flag_file)
	os.Remove(tmp_vmdk_file)
	return nil
}
