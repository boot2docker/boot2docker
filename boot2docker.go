// This is the boot2docker management utilty.
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net"
	"net/http"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"regexp"
	"runtime"
	"strconv"
	"time"
)

// B2D reprents boot2docker config.
var B2D struct {
	Vbm         string // VirtualBox management utility
	SSH         string // SSH client executable
	VM          string // boot2docker virtual machine name
	Dir         string // boot2docker directory
	ISO         string // boot2docker ISO image path
	Disk        string // boot2docker disk image path
	DiskSize    int    // boot2docker disk image size (MB)
	Memory      int    // boot2docker memory size (MB)
	SSHHostPort int    // boot2docker host SSH port
	DockerPort  int    // boot2docker docker port
}

// Return the value of an ENV var, or the fallback value if the ENV var is empty/undefined.
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
	B2D.SSH = getenv("BOOT2DOCKER_DOCKER_SSH", "ssh")
	B2D.Dir = getenv("BOOT2DOCKER_DIR", filepath.Join(u.HomeDir, ".boot2docker"))
	B2D.ISO = getenv("BOOT2DOCKER_ISO", filepath.Join(B2D.Dir, "boot2docker.iso"))
	B2D.Disk = getenv("BOOT2DOCKER_DISK", filepath.Join(B2D.Dir, "boot2docker.vmdk"))
	if B2D.DiskSize, err = strconv.Atoi(getenv("BOOT2DOCKER_DISKSIZE", "20000")); err != nil {
		log.Fatalf("Invalid BOOT2DOCKER_DISKSIZE: %s", err)
	}
	if B2D.DiskSize <= 0 {
		log.Fatalf("BOOT2DOCKER_DISKSIZE way too small.")
	}
	if B2D.Memory, err = strconv.Atoi(getenv("BOOT2DOCKER_MEMORY", "1024")); err != nil {
		log.Fatalf("Invalid BOOT2DOCKER_MEMORY: %s", err)
	}
	if B2D.Memory <= 0 {
		log.Fatalf("BOOT2DOCKER_MEMORY way too small.")
	}
	if B2D.SSHHostPort, err = strconv.Atoi(getenv("BOOT2DOCKER_SSH_HOST_PORT", "2022")); err != nil {
		log.Fatalf("Invalid BOOT2DOCKER_SSH_HOST_PORT: %s", err)
	}
	if B2D.SSHHostPort <= 0 {
		log.Fatalf("Invalid BOOT2DOCKER_SSH_HOST_PORT: must be in the range of 1--65535: got %d", B2D.SSHHostPort)
	}
	if B2D.DockerPort, err = strconv.Atoi(getenv("BOOT2DOCKER_DOCKER_PORT", "4243")); err != nil {
		log.Fatalf("Invalid BOOT2DOCKER_DOCKER_PORT: %s", err)
	}
	if B2D.DockerPort <= 0 {
		log.Fatalf("Invalid BOOT2DOCKER_DOCKER_PORT: must be in the range of 1--65535: got %d", B2D.DockerPort)
	}

	// TODO maybe allow flags to override ENV vars?
	flag.Parse()
}

// State of a virtual machine.
type vmState string

const (
	vmRunning      vmState = "running"
	vmPoweroff             = "poweroff"
	vmPaused               = "paused"
	vmSaved                = "saved"
	vmAborted              = "aborted"
	vmUnregistered         = "(unregistered)" // not actually reported by VirtualBox
	vmUnknown              = "(unknown)"      // not actually reported by VirtualBox
)

func main() {
	if vm := flag.Arg(1); vm != "" {
		B2D.VM = vm
	}

	// TODO maybe use reflect here?
	switch flag.Arg(0) { // choose subcommand
	case "download":
		cmdDownload()
	case "init":
		cmdInit()
	case "start", "up", "boot", "resume":
		cmdStart()
	case "ssh":
		cmdSSH()
	case "save", "suspend":
		cmdSave()
	case "pause":
		cmdPause()
	case "halt", "down", "stop":
		cmdStop()
	case "poweroff":
		cmdPoweroff()
	case "restart":
		cmdRestart()
	case "reset":
		cmdReset()
	case "info":
		cmdInfo()
	case "status":
		cmdStatus()
	case "delete":
		cmdDelete()
	default:
		help()
	}
}

// Call the external SSH command to login into boot2docker VM.
func cmdSSH() {
	switch state := status(B2D.VM); state {
	case vmUnregistered:
		log.Fatalf("%s is not registered.", B2D.VM)
	case vmRunning:
		if err := cmd(B2D.SSH, "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null", "-p", fmt.Sprintf("%d", B2D.SSHHostPort), "docker@localhost"); err != nil {
			log.Fatal(err)
		}
	default:
		log.Fatalf("%s is not running.", B2D.VM)
	}
}

// Start the VM from all possible states.
func cmdStart() {
	switch state := status(B2D.VM); state {
	case vmUnregistered:
		log.Fatalf("%s is not registered.", B2D.VM)
	case vmRunning:
		log.Printf("%s is already running.", B2D.VM)
	case vmPaused:
		log.Printf("Resuming %s", B2D.VM)
		if err := vbm("controlvm", B2D.VM, "resume"); err != nil {
			log.Fatalf("failed to resume vm: %s", err)
		}
		waitVM()
		log.Printf("Resumed.")
	case vmSaved, vmPoweroff, vmAborted:
		log.Printf("Starting %s...", B2D.VM)
		if err := vbm("startvm", B2D.VM, "--type", "headless"); err != nil {
			log.Fatalf("failed to start vm: %s", err)
		}
		waitVM()
		log.Printf("Started.")
	default:
		log.Fatalf("Cannot start %s from state %.", B2D.VM, state)
	}

	// Check if $DOCKER_HOST ENV var is properly configured.
	DockerHost := getenv("DOCKER_HOST", "")
	if DockerHost != fmt.Sprintf("tcp://localhost:%d", B2D.DockerPort) {
		fmt.Printf("\nTo connect the docker client to the Docker daemon, please set:\n")
		fmt.Printf("export DOCKER_HOST=tcp://localhost:%d\n\n", B2D.DockerPort)
	}
}

// Save the current state of VM on disk.
func cmdSave() {
	switch state := status(B2D.VM); state {
	case vmUnregistered:
		log.Fatalf("%s is not registered.", B2D.VM)
	case vmRunning:
		log.Printf("Suspending %s", B2D.VM)
		if err := vbm("controlvm", B2D.VM, "savestate"); err != nil {
			log.Fatalf("failed to suspend vm: %s", err)
		}
	default:
		log.Printf("%s is not running.", B2D.VM)
	}
}

// Pause the VM.
func cmdPause() {
	switch state := status(B2D.VM); state {
	case vmUnregistered:
		log.Fatalf("%s is not registered.", B2D.VM)
	case vmRunning:
		if err := vbm("controlvm", B2D.VM, "pause"); err != nil {
			log.Fatal(err)
		}
	default:
		log.Printf("%s is not running.", B2D.VM)
	}
}

// Gracefully stop the VM by sending ACPI shutdown signal.
func cmdStop() {
	switch state := status(B2D.VM); state {
	case vmUnregistered:
		log.Fatalf("%s is not registered.", B2D.VM)
	case vmRunning:
		log.Printf("Shutting down %s...", B2D.VM)
		if err := vbm("controlvm", B2D.VM, "acpipowerbutton"); err != nil {
			log.Fatalf("failed to shutdown vm: %s", err)
		}
		for status(B2D.VM) == vmRunning {
			time.Sleep(1 * time.Second)
		}
	default:
		log.Printf("%s is not running.", B2D.VM)
	}
}

// Forcefully power off the VM (equivalent to unplug power). Could potentially
// result in corrupted disk. Use with care.
func cmdPoweroff() {
	switch state := status(B2D.VM); state {
	case vmUnregistered:
		log.Fatalf("%s is not registered.", B2D.VM)
	case vmRunning:
		if err := vbm("controlvm", B2D.VM, "poweroff"); err != nil {
			log.Fatal(err)
		}
	default:
		log.Printf("%s is not running.", B2D.VM)
	}
}

// Gracefully stop and then start the VM.
func cmdRestart() {
	switch state := status(B2D.VM); state {
	case vmUnregistered:
		log.Fatalf("%s is not registered.", B2D.VM)
	case vmRunning:
		cmdStop()
		time.Sleep(1 * time.Second)
		cmdStart()
	default:
		cmdStart()
	}
}

// Forcefully reset the VM. Could potentially result in corrupted disk. Use
// with care.
func cmdReset() {
	switch state := status(B2D.VM); state {
	case vmUnregistered:
		log.Fatalf("%s is not registered.", B2D.VM)
	case vmRunning:
		if err := vbm("controlvm", B2D.VM, "reset"); err != nil {
			log.Fatal(err)
		}
	default:
		log.Printf("%s is not running.", B2D.VM)
	}
}

// Delete the VM and remove associated files.
func cmdDelete() {
	switch state := status(B2D.VM); state {
	case vmUnregistered:
		log.Printf("%s is not registered.", B2D.VM)

	case vmPoweroff, vmAborted:
		if err := vbm("unregistervm", "--delete", B2D.VM); err != nil {
			log.Fatalf("failed to delete vm: %s", err)
		}
	default:
		log.Fatalf("%s needs to be stopped to delete it.", B2D.VM)
	}
}

// Show detailed info of the VM.
func cmdInfo() {
	if err := vbm("showvminfo", B2D.VM); err != nil {
		log.Fatal(err)
	}
}

// Show the current state of the VM.
func cmdStatus() {
	state := status(B2D.VM)
	fmt.Printf("%s is %s.\n", B2D.VM, state)
	if state != vmRunning {
		os.Exit(1)
	}
}

// Initialize the boot2docker VM from scratch.
func cmdInit() {
	if state := status(B2D.VM); state != vmUnregistered {
		log.Fatalf("%s already exists.\n")
	}

	if ping(fmt.Sprintf("localhost:%d", B2D.DockerPort)) {
		log.Fatalf("DOCKER_PORT=%d on localhost is occupied. Please choose another none.", B2D.DockerPort)
	}

	if ping(fmt.Sprintf("localhost:%d", B2D.SSHHostPort)) {
		log.Fatalf("SSH_HOST_PORT=%d on localhost is occupied. Please choose another one.", B2D.SSHHostPort)
	}

	log.Printf("Creating VM %s...", B2D.VM)
	if err := vbm("createvm", "--name", B2D.VM, "--register"); err != nil {
		log.Fatalf("failed to create vm: %s", err)
	}

	if err := vbm("modifyvm", B2D.VM,
		"--ostype", "Linux26_64",
		"--cpus", fmt.Sprintf("%d", runtime.NumCPU()),
		"--memory", fmt.Sprintf("%d", B2D.Memory),
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
		"--boot1", "dvd"); err != nil {
		log.Fatal("failed to modify vm: %s", err)
	}

	log.Printf("Setting VM networking")
	if err := vbm("modifyvm", B2D.VM, "--nic1", "nat", "--nictype1", "virtio", "--cableconnected1", "on"); err != nil {
		log.Fatalf("failed to modify vm: %s", err)
	}

	if err := vbm("modifyvm", B2D.VM,
		"--natpf1", fmt.Sprintf("ssh,tcp,127.0.0.1,%d,,22", B2D.SSHHostPort),
		"--natpf1", fmt.Sprintf("docker,tcp,127.0.0.1,%d,,4243", B2D.DockerPort)); err != nil {
		log.Fatalf("failed to modify vm: %s", err)
	}

	if _, err := os.Stat(B2D.ISO); err != nil {
		if os.IsNotExist(err) {
			cmdDownload()
		} else {
			log.Fatalf("failed to open ISO image: %s", err)
		}
	}

	if _, err := os.Stat(B2D.Disk); err != nil {
		if os.IsNotExist(err) {
			err := makeDiskImage(B2D.Disk, B2D.DiskSize)
			if err != nil {
				log.Fatalf("failed to create disk image: %s", err)
			}
		} else {
			log.Fatalf("failed to open disk image: %s", err)
		}
	}

	log.Printf("Setting VM disks")
	if err := vbm("storagectl", B2D.VM, "--name", "SATA", "--add", "sata", "--hostiocache", "on"); err != nil {
		log.Fatalf("failed to add storage controller: %s", err)
	}

	if err := vbm("storageattach", B2D.VM, "--storagectl", "SATA", "--port", "0", "--device", "0", "--type", "dvddrive", "--medium", B2D.ISO); err != nil {
		log.Fatalf("failed to attach storage device: %s", err)
	}

	if err := vbm("storageattach", B2D.VM, "--storagectl", "SATA", "--port", "1", "--device", "0", "--type", "hdd", "--medium", B2D.Disk); err != nil {
		log.Fatalf("failed to attach storage device: %s", err)
	}

	log.Printf("Done.")
	log.Printf("You can now type `boot2docker up` and wait for the VM to start.")
}

// Download the boot2docker ISO image.
func cmdDownload() {
	log.Printf("downloading boot2docker ISO image...")
	tag, err := getLatestReleaseName()
	if err != nil {
		log.Fatalf("failed to get latest release: %s", err)
	}
	log.Printf("  %s", tag)
	if err := download(B2D.ISO, tag); err != nil {
		log.Fatalf("failed to download ISO image: %s", err)
	}
}

// Convenient function to exec a command.
func cmd(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// Convenient function to launch VBoxManage.
func vbm(args ...string) error {
	return cmd(B2D.Vbm, args...)
}

// Get the latest boot2docker release name (e.g. v0.5.4).
func getLatestReleaseName() (string, error) {
	rsp, err := http.Get("https://api.github.com/repos/boot2docker/boot2docker/releases")
	if err != nil {
		return "", err
	}
	defer rsp.Body.Close()

	var t []struct {
		TagName string `json:"tag_name"`
	}
	if err := json.NewDecoder(rsp.Body).Decode(&t); err != nil {
		return "", err
	}
	if len(t) == 0 {
		return "", fmt.Errorf("no releases found")
	}
	return t[0].TagName, nil
}

// Download boot2docker ISO image for the given tag and save it at dest.
func download(dest, tag string) error {
	rsp, err := http.Get(fmt.Sprintf("https://github.com/boot2docker/boot2docker/releases/download/%s/boot2docker.iso", tag))
	if err != nil {
		return err
	}
	defer rsp.Body.Close()

	f, err := ioutil.TempFile("", "boot2docker-")
	if err != nil {
		return err
	}
	defer os.Remove(f.Name())

	if _, err := io.Copy(f, rsp.Body); err != nil {
		return err
	}
	if err := f.Close(); err != nil {
		return err
	}

	if err := os.Rename(f.Name(), dest); err != nil {
		return err
	}
	return nil
}

// Get the state of a VM.
func status(vm string) vmState {
	// Check if the VM exists.
	out, err := exec.Command(B2D.Vbm, "list", "vms").Output()
	if err != nil {
		return vmUnknown
	}
	found, err := regexp.Match(fmt.Sprintf(`(?m)^"%s"`, regexp.QuoteMeta(vm)), out)
	if err != nil {
		return vmUnknown
	}
	if !found {
		return vmUnregistered
	}

	if out, err = exec.Command(B2D.Vbm, "showvminfo", vm, "--machinereadable").Output(); err != nil {
		return vmUnknown
	}
	re := regexp.MustCompile(`(?m)^VMState="(\w+)"$`)
	groups := re.FindSubmatch(out)
	if len(groups) < 1 {
		return vmUnknown
	}
	switch state := vmState(groups[1]); state {
	case vmRunning, vmPaused, vmSaved, vmPoweroff, vmAborted:
		return state
	default:
		return vmUnknown
	}
}

// Print help message.
func help() {
	log.Fatalf("Usage: %s {init|start|up|ssh|save|pause|stop|poweroff|reset|restart|status|info|delete|download} [vm]", os.Args[0])
}

// Ping boot2docker VM until it's started.
func waitVM() {
	addr := fmt.Sprintf("localhost:%d", B2D.SSHHostPort)
	for !ping(addr) {
		time.Sleep(1 * time.Second)
	}
}

// Check if an addr can be successfully connected.
func ping(addr string) bool {
	conn, err := net.Dial("tcp", addr)
	if err != nil {
		return false
	}
	defer conn.Close()
	return true
}

// Make a boot2docker VM disk image.
func makeDiskImage(dest string, size int) error {
	log.Printf("Creating %d MB hard disk image...", size)
	cmd := exec.Command(B2D.Vbm, "convertfromraw", "stdin", dest, fmt.Sprintf("%d", size*1024*1024), "--format", "VMDK")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	w, err := cmd.StdinPipe()
	if err != nil {
		return err
	}
	// Write the magic string so the VM auto-formats the disk upon first boot.
	if _, err := w.Write([]byte("boot2docker, please format-me")); err != nil {
		return err
	}
	if err := w.Close(); err != nil {
		return err
	}

	return cmd.Run()
}
