# Boot2Docker Enable to use Webcam for mac

This repository based on the basic [boot2docker repository](https://github.com/boot2docker/boot2docker), and referenced with [Windows environment](https://github.com/Alexoner/boot2docker).

## What I changed

1. Go back to commit `c7e5c3`
2. Annotated `rm -rf ./*/kernel/drivers/media/* && \` at [Dockerfile #L86](./Dockerfile#L86)
3. Changed libcap2 url at [Dockerfile #L95](./Dockerfile#L85)
4. Added conditions at [kernel_config](./kernel_config#L5062) like below:

```sh
#
# Additional Configuration
#
# Processor type and features
#
CONFIG_FRAME_VECTOR=y
#
# Generic Driver Options
#
CONFIG_DMA_SHARED_BUFFER=y
#
# Multifunction device drivers
#
CONFIG_MEDIA_SUPPORT=m
#
# Multimedia core support
#
CONFIG_MEDIA_CAMERA_SUPPORT=y
CONFIG_VIDEO_DEV=m
CONFIG_VIDEO_V4L2=m
CONFIG_VIDEOBUF2_CORE=m
CONFIG_VIDEOBUF2_MEMOPS=m
CONFIG_VIDEOBUF2_VMALLOC=m
#
# Media drivers
#
CONFIG_MEDIA_USB_SUPPORT=y
#
# Webcam devices
#
CONFIG_USB_VIDEO_CLASS=m
CONFIG_USB_VIDEO_CLASS_INPUT_EVDEV=y
CONFIG_USB_GSPCA=m
CONFIG_USB_S2255=m
#
# Webcam, TV (analog/digital) USB devices
#
CONFIG_V4L_PLATFORM_DRIVERS=y
#
# Media ancillary drivers (tuners, sensors, i2c, frontends)
#
CONFIG_MEDIA_SUBDRV_AUTOSELECT=y
#
# USB Physical Layer drivers
#
CONFIG_USB_GADGET=m
CONFIG_USB_GADGET_VBUS_DRAW=2
CONFIG_USB_GADGET_STORAGE_NUM_BUFFERS=2
#
# USB Peripheral Controller
#
CONFIG_USB_LIBCOMPOSITE=m
CONFIG_USB_F_MASS_STORAGE=m
CONFIG_USB_F_UVC=m
CONFIG_USB_CONFIGFS=m
CONFIG_USB_CONFIGFS_MASS_STORAGE=y
CONFIG_USB_CONFIGFS_F_UVC=y
#
# Pseudo filesystems
#
CONFIG_CONFIGFS_FS=m
```

## How to use

### Prerequisite

1. Install: `brew install socat`
2. Install: `brew install xquartz`
3. Run: `open -a XQuartz`
4. Setting: XQuartz Preferences -> Security -> check allow all (Allow connections from network clients)
5. Run: `defaults write org.macosforge.xquartz.X11 enable_iglx -bool true`
6. Run: `IP=$(ifconfig en0 | grep inet | awk '$1=="inet" {print $2}')`
7. Run: `xhost + $IP`
8. Install [VirtualBox](https://www.virtualbox.org/) and its Extension pack
9. Create new docker-machine environment using VirtualBox like below:

	```sh
	docker-machine create -d virtualbox \
		--virtualbox-cpu-count=2 \
		--virtualbox-memory=2048 \
		--virtualbox-disk-size=100000 \
		--virtualbox-boot2docker-url https://github.com/gzupark/boot2docker-webcam-mac/releases/download/18.06.1-ce-usb/boot2docker.iso \
		${YOUR_DOCKER_MACHINE_ENV_NAME}
	```

10. Run: `docker-machine stop ${YOUR_DOCKER_MACHINE_ENV_NAME}`
11. Configure the VirtualBox image that you created
    - Display -> Video memory (max)
	- Display -> Acceleration -> Enable 3D acceleration (check)
	- Ports -> USB -> Enable USB controller (check) -> USB 2.0 (select)
	- Shared folders -> Add -> Folder Path set root path = / or Folder name you want

### Follow steps

- To run below steps everytime when you want to use webcams with docker
- Assume normal terminal session is __T1__, and XQuartz terminal or 2nd terminal session is __T2__

1. Run __T1__: `open -a XQuartz`
2. Run __T2__: `socat TCP-LISTEN:6000,reuseaddr,fork UNIX-CLIENT:\"$DISPLAY\"`
	- if it occurs an error, please check with `lsof -i tcp:6000` and `kill` the PID
3. Run __T1__: `IP=$(ifconfig en0 | grep inet | awk '$1=="inet" {print $2}')`
4. Run __T1__: `xhost + $IP`
5. Run __T1__: `docker-machine start ${YOUR_DOCKER_MACHINE_ENV_NAME}`
6. Run __T1__: `eval $(docker-machine env ${YOUR_DOCKER_MACHINE_ENV_NAME})`
7. Run __T1__: `vboxmanage list webcams` and check a list
8. Run __T1__: `vboxmanage controlvm "${YOUR_DOCKER_MACHINE_ENV_NAME}" webcam attach .1` or others referenced a list

### Test - XQuartz

- xeyes

  ```sh
  docker run --rm -it -e DISPLAY=$IP:0 gns3/xeyes
  ```

- firefox

  ```sh
  docker run --rm -it -e DISPLAY=$IP:0 -v /tmp/.X11-unix:/tmp/.X11-unix jess/firefox
  ```

### Run - example

```sh
docker run --rm -it --device=/dev/video0:/dev/video0 \
	-v /tmp/.X11-unix:/tmp/.X11-unix \
	-e DISPLAY=$IP:0 \
	${YOUR_DOCKER_IMAGE}
```

## Author

[@jetsbee](https://github.com/jetsbee) [@gzupark](https://github.com/gzupark)
