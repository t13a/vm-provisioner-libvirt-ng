local r = import '../index.jsonnet';
local t = r.templates;

t.base
+ t.cloud(image=r.images.debian(version='13'))
// GRUB of this image needs a video device, even without a remote display.
+ t.video()
+ {
  node: r.nodes.hv2,
}
