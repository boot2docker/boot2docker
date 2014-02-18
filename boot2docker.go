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
	VBM           string // VirtualBox management utility
	VM            string // boot2docker virtual machine name
	DIR           string // boot2docker directory
	ISO           string // boot2docker ISO image path
	DISK          string // boot2docker disk image path
	DISKSIZE      string // boot2docker disk image size (MB)
	MEMORY        string // boot2docker memory size (MB)
	SSH_HOST_PORT string // boot2docker host SSH port
	DOCKER_PORT   string // boot2docker docker port
	SSH           string // ssh executable
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
	B2D.VBM = getenv("BOOT2DOCKER_VBM", "VBoxManage")
	B2D.VM = getenv("BOOT2DOCKER_VM", "boot2docker-vm")
	B2D.DIR = getenv("BOOT2DOCKER_DIR", filepath.Join(u.HomeDir, ".boot2docker"))
	B2D.ISO = getenv("BOOT2DOCKER_ISO", filepath.Join(B2D.DIR, "boot2docker.iso"))
	B2D.DISK = getenv("BOOT2DOCKER_DISK", filepath.Join(B2D.DIR, "boot2docker.vmdk"))
	B2D.DISKSIZE = getenv("BOOT2DOCKER_DISKSIZE", "20000")
	B2D.MEMORY = getenv("BOOT2DOCKER_MEMORY", "1000")
	B2D.SSH_HOST_PORT = getenv("BOOT2DOCKER_SSH_HOST_PORT", "2022")
	B2D.DOCKER_PORT = getenv("BOOT2DOCKER_DOCKER_PORT", "4243")
	B2D.SSH = getenv("BOOT2DOCKER_DOCKER_SSH", "ssh")
}

type VM_STATE int

const (
	VM_UNKNOWN VM_STATE = iota
	VM_RUNNING
	VM_STOPPED
	VM_PAUSED
	VM_SUSPENDED
	VM_ABORTED
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
	case "start":
		fallthrough // Yes, Go has this statement!
	case "up":
		cmdStart(vm)
	case "ssh":
		cmdSsh(vm)
	case "resume":
		cmdResume(vm)
	case "save":
		fallthrough
	case "pause":
		fallthrough
	case "suspend":
		cmdSuspend(vm)
	case "halt":
		fallthrough
	case "down":
		fallthrough
	case "stop":
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
	if state != VM_RUNNING {
		log.Fatalf("%s is not running.", vm)
	}
	err := cmd(B2D.SSH, "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null", "-p", B2D.SSH_HOST_PORT, "docker@localhost")
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
	if state == VM_RUNNING {
		log.Printf("%s is already running.", vm)
		return
	}

	if state == VM_PAUSED {
		log.Printf("Resuming %s", vm)
		vbm("controlvm", vm, "resume")
		wait_vm()
		log.Printf("Resumed.")
	} else {
		log.Printf("Starting %s...", vm)
		vbm("startvm", vm, "--type", "headless")
		wait_vm()
		log.Printf("Started.")
	}

	// check if $DOCKER_HOST is properly configured
	DOCKER_HOST := getenv("DOCKER_HOST", "")
	if DOCKER_HOST != "tcp://localhost:"+B2D.DOCKER_PORT {
		fmt.Printf("\nTo connect the docker client to the Docker daemon, please set:\n")
		fmt.Printf("export DOCKER_HOST=tcp://localhost:%s\n\n", B2D.DOCKER_PORT)
	}
}

// ping boot2docker VM until it's started
func wait_vm() {
	addr := fmt.Sprintf("localhost:%s", B2D.SSH_HOST_PORT)
	for !ping(addr) {
		time.Sleep(1 * time.Second)
	}
}

func cmdResume(vm string) {
	if status(vm) == VM_SUSPENDED {
		vbm("controlvm", vm, "resume")
	} else {
		log.Printf("%s is not suspended.", vm)
	}
}

func cmdSuspend(vm string) {
	if !installed(vm) {
		cmdStatus(vm)
	}
	if status(vm) == VM_RUNNING {
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

	if status(vm) == VM_RUNNING {
		log.Printf("Shutting down %s...", vm)
		vbm("controlvm", vm, "acpipowerbutton")
		for status(vm) == VM_RUNNING {
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
	if state == VM_RUNNING {
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
	case VM_RUNNING:
		fmt.Printf("%s is running.\n", vm)
	case VM_PAUSED:
		log.Fatalf("%s is paused.", vm)
	case VM_SUSPENDED:
		log.Fatalf("%s is suspended.", vm)
	case VM_STOPPED:
		log.Fatalf("%s is stopped.", vm)
	case VM_ABORTED:
		log.Fatalf("%s is aborted.")
	default:
		log.Fatalf("%s does not exist.", vm)
	}
}

func cmdInit(vm string) {
	if installed(vm) {
		log.Fatalf("%s already exists.\n")
	}

	if ping(fmt.Sprintf("localhost:%s", B2D.DOCKER_PORT)) {
		log.Fatalf("DOCKER_PORT=%s on localhost is occupied. Please choose another port.", B2D.DOCKER_PORT)
	}

	if ping(fmt.Sprintf("localhost:%s", B2D.SSH_HOST_PORT)) {
		log.Fatalf("SSH_HOST_PORT=%s on localhost is occupied. Please choose another port.", B2D.SSH_HOST_PORT)
	}

	log.Printf("Creating VM %s", vm)
	vbm("createvm", "--name", vm, "--register")
	if vbm("modifyvm", vm,
		"--ostype", "Linux26_64",
		"--cpus", fmt.Sprintf("%d", runtime.NumCPU()),
		"--memory", B2D.MEMORY,
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
		"--natpf1", fmt.Sprintf("ssh,tcp,127.0.0.1,%s,,22", B2D.SSH_HOST_PORT),
		"--natpf1", fmt.Sprintf("docker,tcp,127.0.0.1,%s,,4243", B2D.DOCKER_PORT))

	if !exist(B2D.ISO) {
		cmdDownload()
	}

	if !exist(B2D.DISK) {
		makeDiskImage()
	}

	log.Printf("Setting VM disks")
	vbm("storagectl", vm, "--name", "SATA", "--add", "sata", "--hostiocache", "on")
	vbm("storageattach", vm, "--storagectl", "SATA", "--port", "0", "--device", "0", "--type", "dvddrive", "--medium", B2D.ISO)
	vbm("storageattach", vm, "--storagectl", "SATA", "--port", "1", "--device", "0", "--type", "hdd", "--medium", B2D.DISK)

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
	err = download(tag, B2D.ISO)
	if err != nil {
		log.Fatalf("failed to download ISO image: %s", err)
	}
}

func cmdDelete(vm string) {
	state := status(vm)
	if state == VM_STOPPED || state == VM_ABORTED {
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
	return cmd(B2D.VBM, args...)
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
func download(tag, dest string) error {
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
	stdout, _ := exec.Command(B2D.VBM, "list", "vms").Output()
	matched, _ := regexp.Match(fmt.Sprintf(`(?m)^"%s"`, regexp.QuoteMeta(vm)), stdout)
	return matched
}

// get the state of a VM
func status(vm string) VM_STATE {
	b, err := vminfo(vm)
	if err != nil {
		return VM_UNKNOWN
	}
	re := regexp.MustCompile(`(?m)^State:\s+(\w+)`)
	groups := re.FindSubmatch(b)
	if len(groups) < 1 {
		return VM_UNKNOWN
	}
	switch string(groups[1]) {
	case "running":
		return VM_RUNNING
	case "paused":
		return VM_PAUSED
	case "saved":
		return VM_SUSPENDED
	case "powered": // it's actually "powered off"
		return VM_STOPPED
	case "aborted":
		return VM_ABORTED
	default:
		return VM_UNKNOWN
	}
}

// print help message
func help() {
	log.Fatalf("Usage: %s {init|start|up|ssh|save|pause|stop|restart|resume|status|info|delete|download} [vm]", os.Args[0])
}

// get VM info
func vminfo(vm string) (stdout []byte, err error) {
	cmd := exec.Command(B2D.VBM, "showvminfo", vm)
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
	log.Printf("Creating %s MB hard disk image...", B2D.DISKSIZE)
	vbm("createhd", "--format", "VMDK", "--filename", B2D.DISK, "--size", B2D.DISKSIZE)

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
	vbm("clonehd", tmp_vmdk_file, B2D.DISK, "--existing")
	vbm("closemedium", "disk", tmp_vmdk_file)
	os.Remove(tmp_flag_file)
	os.Remove(tmp_vmdk_file)
	return nil
}

// helper function to test if a path exists or not
func exist(path string) bool {
	if _, err := os.Stat(path); os.IsNotExist(err) {
		return false
	}
	return true
}
