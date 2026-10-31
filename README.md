# vm-provisioner-libvirt-ng

A rewrite of [vm-provisioner-libvirt](https://github.com/t13a/vm-provisioner-libvirt). It renders a registry of VMs, written in Jsonnet, into provisioners. Each provisioner holds the libvirt XML and the cloud-init files of one VM, plus a Makefile that creates the VM with virsh.

**This project is in an early stage of development. Anything may change without notice.**

## Usage

Build the image. It renders a registry and validates the result.

```console
$ podman build -t vm-provisioner-libvirt-ng src
```

Render the registry in `registry/` into `provisioners/`. This also updates `registry/index.jsonnet`, which lists the files of the registry.

```console
$ podman run --rm --userns=keep-id -v ./registry:/src/registry -v ./provisioners:/src/provisioners vm-provisioner-libvirt-ng
```

`config` prints the VMs as the renderer sees them. It needs only the registry.

```console
$ podman run --rm --userns=keep-id -v ./registry:/src/registry vm-provisioner-libvirt-ng config
```

Each VM gets its own Makefile. Its targets run on the host and need virsh, xorriso, curl, and ssh.

```console
$ make -C provisioners/debian13 up              # create and start debian13
$ make -C provisioners/debian13 wait-for-ready  # wait for SSH and cloud-init
$ make -C provisioners/debian13 down            # delete debian13, but keep what has deletionPolicy Retain
```

## Layout

- `src/` holds what goes into the image:
  - `main.jsonnet` renders the VMs into provisioners. The comment at its top describes the VM format.
  - `v1.mk` defines the targets of each VM's Makefile. The renderer copies it into the provisioners.
  - The `Makefile` runs the renderer.
- `example/registry/` is an example registry. `vms/` has one file per VM, and each VM is composed from the other directories.
- `example/provisioners/` holds what the image renders from the example registry.
