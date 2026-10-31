// A remote display over SPICE. Unlike VNC, it gets no port unless autoport asks for a free one.
// Without video, libvirt adds a cirrus card, so pair it with video(model='qxl').
// The channel lets spice-vdagent in the guest share the clipboard and follow the window size.
{ domain+: { devices+: {
  'graphics:spice': { '@type': 'spice', '@autoport': 'yes' },
  'channel:com.redhat.spice.0': { '@type': 'spicevmc', target: { '@type': 'virtio', '@name': 'com.redhat.spice.0' } },
} } }
