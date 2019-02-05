#!/usr/bin/env bash

# This script MUST be run as root!

vmname="windows10vm"

if ps -ef | grep qemu-system-x86_64 | grep -q multifunction=on; then
  echo "A passthrough VM is already running." &
  exit 1

else

  # use pulseaudio
  export QEMU_AUDIO_DRV=pa
  export QEMU_PA_SERVER=127.0.0.1
  export PULSE_SERVER=127.0.0.1

  # cp /usr/share/OVMF/OVMF_VARS.fd /tmp/my_vars.fd

  taskset -a 0xAAAAAAAA qemu-system-x86_64 \
    -name $vmname,process=$vmname \
    -machine type=q35,accel=kvm \
    -cpu host,kvm=off,hv_vendor_id=1234567890ab,hv_vapic,hv_time,hv_relaxed,hv_spinlocks=0x1fff \
    -smp 16,sockets=1,cores=16,threads=1 \
    -m 32G \
    -mem-prealloc \
    -rtc clock=host,base=localtime \
    -serial none \
    -parallel none \
    -soundhw hda \
    -device vfio-pci,host=0b:00.0,multifunction=on \
    -device vfio-pci,host=0b:00.1 \
    -drive if=pflash,format=raw,readonly,file=/run/libvirt/nix-ovmf/OVMF_CODE.fd \
    -drive id=disk0,if=virtio,cache=none,file=/home/skw/.local/share/libvirt/images/win.qcow2 \
    -drive file=/dev/sda,format=raw \
    -device ivshmem-plain,memdev=ivshmem,bus=pcie.0 \
    -object memory-backend-file,id=ivshmem,share=on,mem-path=/dev/shm/looking-glass,size=32M \
    -spice port=5900,addr=127.0.0.1,disable-ticketing \
    -monitor tcp:127.0.0.1:55555,server,nowait \
    -device virtio-keyboard-pci \
    -usb -device usb-host,vendorid=0x046d,productid=0xc215 \
    -boot order=dc

  exit 0
fi
