// A video device. libvirt adds one only along with a remote display, and most guests run without
// one. GRUB of Debian 13 cloud images does not: it uses a graphical terminal, and without a video
// device the VM resets over and over before Linux starts. Any model works with vnc and spice.
// vga is QEMU's standard card; qxl suits spice best.
function(model='vga') { domain+: { devices+: { video: { model: { '@type': model } } } } }
