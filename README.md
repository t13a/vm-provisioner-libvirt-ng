# vm-provisioner-libvirt-ng

A rewrite of [vm-provisioner-libvirt](https://github.com/t13a/vm-provisioner-libvirt). It renders libvirt XML and cloud-init files from Jsonnet, then creates the VMs from those files with Make and virsh.

**This project is in an early stage of development. Anything may change without notice.**

## Usage

`make gen` renders `src/` into `out/` and validates the result. It needs go-jsonnet and virt-xml-validate. If cloud-init is installed, it also validates the user-data.

```console
$ make gen
```

Each VM gets its own Makefile under `out/`. Its targets need virsh, xorriso, curl, and ssh.

```console
$ make -C out/vm1 up              # create and start vm1
$ make -C out/vm1 wait-for-ready  # wait for SSH and cloud-init
$ make -C out/vm1 down            # delete vm1, but keep what has deletionPolicy Retain
```

## Layout

- `src/vms/` has one file per VM. Each VM is composed from `src/templates/`, `src/images/`, and `src/nodes/`.
- `lib/renderer.libsonnet` renders the VMs into files. The comment at its top describes the VM format.
- `lib/provisioner.mk` defines the targets of each VM's Makefile.
- `out/` holds the files that `make gen` generates.
