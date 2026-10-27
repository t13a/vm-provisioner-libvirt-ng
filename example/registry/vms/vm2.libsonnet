local r = import '../index.jsonnet';
local t = r.templates;

t.base
+ t.cloud(image=r.images.debian(version='13'))
+ t.headless
+ {
  node: r.nodes.hv2,
  // Subtraction works the same in cloud-init sections: hide the inherited key.
  userData+: { runcmd:: null },
}
