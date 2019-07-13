# Boot2Docker Enable to use Webcam for mac

This repository based on the basic [boot2docker repository](https://github.com/boot2docker/boot2docker), and referenced with [Windows environment](https://github.com/Alexoner/boot2docker).

## What I changed

1. Go back to commit `c7e5c3`
2. Annotated `rm -rf ./*/kernel/drivers/media/* && \` at [Dockerfile](./Dockerfile)
3. Added conditions at [kernel_config](./kernel_config) like below:
```
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

## Author
[@jetsbee](https://github.com/jetsbee) [@gzupark](https://github.com/gzupark)
