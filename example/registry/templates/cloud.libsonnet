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
      deletionPolicy:: 'Retain',
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
  metaData: { 'instance-id': vm.name, 'local-hostname': vm.name },
  userData: { packages: ['qemu-guest-agent'], runcmd: ['systemctl enable --now qemu-guest-agent'] },
  ssh: { user: image.sshUser },
}
