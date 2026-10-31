// The base of every VM. Templates are mixins; see src/main.jsonnet for the sections and hidden fields.
// `vm` is bound late to the final, fully merged VM, so templates can use values that the VM sets later.
// The base is headless: the templates video, vnc and spice add a video device and remote displays.

// A fixed UUID makes `virsh define` update the existing domain instead of failing.
local uuid(s) = local h = std.md5(s); h[0:8] + '-' + h[8:12] + '-' + h[12:16] + '-' + h[16:20] + '-' + h[20:32];

{
  local vm = self,
  name:: error 'name is required',
  node:: error 'node is required',
  domain: {
    autostart:: false,
    '@type': 'kvm',
    name: vm.name,
    uuid: uuid(vm.name),
    memory: { '@unit': 'MiB', '#text': 1024 },
    vcpu: 1,
    os: { type: { '@arch': 'x86_64', '@machine': 'q35', '#text': 'hvm' } },
    features: { acpi: {}, apic: {} },
    cpu: { '@mode': 'host-passthrough' },
    devices: {
      'interface:default': { '@type': 'network', source: { '@network': vm.node.network }, model: { '@type': 'virtio' } },
      serial: { '@type': 'pty' },
      console: { '@type': 'pty' },
      // The QEMU guest agent in the guest talks to the host through this port.
      'channel:org.qemu.guest_agent.0': { '@type': 'unix', target: { '@type': 'virtio', '@name': 'org.qemu.guest_agent.0' } },
    },
  },
}
