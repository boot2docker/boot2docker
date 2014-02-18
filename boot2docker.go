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
	"strings"
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
		vm = B2D.VM
	}

	// TODO maybe use reflect here?
	switch flag.Arg(0) { // choose subcommand
	case "download":
		cmdDownload()
	case "init":
		cmdInit(vm)
	case "start":
		cmdStart(vm)
	case "up":
		cmdStart(vm)
	case "resume":
		cmdResume(vm)
	case "save":
		cmdSuspend(vm)
	case "pause":
		cmdSuspend(vm)
	case "suspend":
		cmdSuspend(vm)
	case "halt":
		cmdStop(vm)
	case "down":
		cmdStop(vm)
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

func cmdStart(vm string) {
	if !installed(vm) {
		cmdStatus(vm)
		return
	}
	state := status(vm)
	if state == VM_RUNNING {
		log.Printf("%v is already running.", vm)
		return
	}

	if state == VM_PAUSED {
		log.Printf("Resuming %s", vm)
		vbm("controlvm %s resume", vm)
		wait_vm()
		log.Printf("Resumed.")
	} else {
		log.Printf("Starting %s...", vm)
		vbm("startvm %s --type headless", vm)
		wait_vm()
		log.Printf("Started.")
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
		vbm("controlvm %s resume", vm)
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
		vbm("controlvm %s savestate", vm)
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
		vbm("controlvm %s acpipowerbutton", vm)
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
	vbm("createvm --name %s --register", vm)
	if vbm(`modifyvm %s
		--ostype Linux26_64
		--cpus %d
		--memory %s
		--rtcuseutc on
		--acpi on
		--ioapic on
		--hpet on
		--hwvirtex on
		--vtxvpid on
		--largepages on
		--nestedpaging on
		--firmware bios
		--bioslogofadein off
		--bioslogofadeout off
		--bioslogodisplaytime 0
		--biosbootmenu disabled
		--boot1 dvd`, vm, runtime.NumCPU(), B2D.MEMORY) != nil {
		log.Fatal("An error occured, upgrade VirtualBox")
		cmdDelete(vm)
	}

	log.Printf("Setting VM networking")
	vbm("modifyvm %s --nic1 nat --nictype1 virtio --cableconnected1 on", vm)
	vbm(`modifyvm %s 
		--natpf1 "ssh,tcp,127.0.0.1,%s,,22" 
		--natpf1 "docker,tcp,127.0.0.1,%s,,4243"`, vm, B2D.SSH_HOST_PORT, B2D.DOCKER_PORT)

	if _, err := os.Stat(B2D.ISO); os.IsNotExist(err) {
		cmdDownload()
	}

	if _, err := os.Stat(B2D.DISK); os.IsNotExist(err) {
		makeDiskImage()
	}

	log.Printf("Setting VM disks")
	vbm(`storagectl %s --name "SATA" --add sata --hostiocache on`, vm)
	vbm(`storageattach %s --storagectl "SATA" --port 0 --device 0 --type dvddrive --medium %s`, vm, B2D.ISO)
	vbm(`storageattach %s --storagectl "SATA" --port 1 --device 0 --type hdd --medium %s`, vm, B2D.DISK)

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
		vbm("unregistervm --delete %s", vm)
		return
	}
	log.Fatalf("%s needs to be stopped to delete it.", vm)
}

// convenient function to exec a command
func cmd(name string, args ...string) error {
	log.Println(name, args)
	//return nil
	cmd := exec.Command(name, args...)
	return cmd.Run()
}

// convenient function to launch VBoxManage
func vbm(arg string, x ...interface{}) error {
	return cmd(B2D.VBM, strings.Fields(fmt.Sprintf(arg, x...))...)
}

// get the latest boot2docker release tag e.g. v0.5.4
func getLatestReleaseName() (string, error) {
	rsp, err := http.Get("https://api.github.com/repos/steeve/boot2docker/releases")
	if err != nil {
		return "", err
	}
	defer rsp.Body.Close()

	var t [1]struct {
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
	cmd := exec.Command(B2D.VBM, "list", "vms")
	stdout, _ := cmd.Output()
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
	log.Fatalf("Usage %s {init|start|up|save|pause|stop|restart|resume|status|info|delete|download}\n", os.Args[0])
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
	log.Printf("Creating %s Meg hard drive...", B2D.DISKSIZE)
	vbm("closemedium disk %s", B2D.DISK)
	vbm("createhd --format VMDK --filename %s --size %s", B2D.DISK, B2D.DISKSIZE)

	f, err := os.Create("format-flag.txt")
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

	vbm("convertfromraw format-flag.txt format-flag.vmdk --format VMDK")
	vbm("clonehd format-flag.vmdk %s --existing", B2D.DISK)
	vbm("closemedium disk format-flag.vmdk")
	os.Remove("format-flag.txt")
	os.Remove("format-flag.vmdk")
	return nil
}
