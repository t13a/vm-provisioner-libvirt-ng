local r = import '../index.jsonnet';
local t = r.templates;

t.base
+ t.cloud(image=r.images.debian(version='12'))
+ {
  node: r.nodes.hv2,
}
