// A data disk in the VM's own pool. By default it survives `make down`; `make delete-all` removes it.
function(dev, gib, lifecyclePolicy='Reusable') {
  local vm = self,
  local volume = vm.name + '-' + dev + '.qcow2',
  volumes+: { [vm.name]+: { [volume]: {
    lifecyclePolicy:: lifecyclePolicy,
    name: volume,
    capacity: { '@unit': 'GiB', '#text': gib },
    target: { format: { '@type': 'qcow2' } },
  } } },
  domain+: { devices+: { ['disk:' + dev]: {
    '@type': 'volume', '@device': 'disk',
    driver: { '@name': 'qemu', '@type': 'qcow2' },
    source: { '@pool': vm.name, '@volume': volume },
    target: { '@dev': dev, '@bus': 'virtio' },
  } } },
}
