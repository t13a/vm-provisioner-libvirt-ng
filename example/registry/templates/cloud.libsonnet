// Boots a cloud image with a NoCloud seed. Downloaded images are cached in imageDir,
// relative to the directory of the VM, provisioners/<name>/.
function(image, imageDir='../../.images') {
  local vm = self,
  local seedIso = vm.name + '-seed.iso',
  local bootVolume = vm.name + '-boot.qcow2',
  seed:: seedIso,
  pools: { [vm.name]: {
    autostart:: true,
    '@type': 'dir',
    name: vm.name,
    target: { path: vm.node.poolDir + '/' + vm.name },
  } },
  volumes: {
    [vm.node.imagePool.name]: { [image.volume]: {
      lifecyclePolicy:: 'Shared',
      download:: image.url,
      upload:: imageDir + '/' + image.volume,
      name: image.volume,
      target: { format: { '@type': image.format } },
    } },
    [vm.name]: {
      [bootVolume]: {
        name: bootVolume,
        target: { format: { '@type': 'qcow2' } },
        backingStore: { path: vm.node.imagePool.path + '/' + image.volume, format: { '@type': image.format } },
      },
      [seedIso]: {
        upload:: seedIso,
        name: seedIso,
        target: { format: { '@type': 'raw' } },
      },
    },
  },
  domain+: { devices+: {
    'disk:vda': {
      '@type': 'volume', '@device': 'disk',
      driver: { '@name': 'qemu', '@type': 'qcow2' },
      source: { '@pool': vm.name, '@volume': bootVolume },
      target: { '@dev': 'vda', '@bus': 'virtio' },
    },
    'disk:sda': {
      '@type': 'volume', '@device': 'cdrom',
      driver: { '@name': 'qemu', '@type': 'raw' },
      source: { '@pool': vm.name, '@volume': seedIso },
      target: { '@dev': 'sda', '@bus': 'sata' },
      readonly: {},
    },
  } },
  // cloud-init reads a name with a dot as an FQDN, so the hostname would end at the first dot.
  metaData: { 'instance-id': vm.name, 'local-hostname': vm.name },
  // The agent's unit has no [Install] section: udev starts it when the port of base appears, and on
  // the first boot that happens before the package is installed. So the first boot starts it here.
  userData: { packages: ['qemu-guest-agent'], runcmd: ['systemctl start qemu-guest-agent'] },
  ssh: { user: image.sshUser },
}
