// The renderer: turns the VMs of a registry into provisioners, the files that rules.mk reads.
// This file and rules.mk share one contract, so they change together, and the renderer
// writes rules.mk next to the provisioners so that they run without the renderer.
//
// A VM is an object whose visible sections mirror the format of their readers:
//   domain, pools, volumes             libvirt XML
//   userData, metaData, networkConfig  cloud-init NoCloud files
//   ssh                                { user, host } for `make ssh`
// Hidden fields carry what the XML cannot hold:
//   VM      name, node (with uri), seed (the NoCloud ISO, relative to the VM directory)
//   domain  autostart (default false)
//   pool    autostart (default false), lifecyclePolicy
//   volume  lifecyclePolicy, upload (a file relative to the VM directory), download (the URL of that file)
// lifecyclePolicy says what becomes of a pool or volume when its VM goes:
//   Disposable  `make down` deletes it (the default)
//   Reusable    it survives `make down`, and the VM uses it again; `make delete-all` deletes it
//   Shared      other VMs use it at the same time, so it always stays; `make create-shared` creates it
// Any other hidden field inside a section must be null, which removes an inherited element or key.
// So a misspelled field is an error instead of a silent default.

// ---------------------------------------------------------------------------
// Formats: XML, YAML and Make. Nothing here knows about VMs.
// ---------------------------------------------------------------------------

// XML is written from plain objects:
//   '@attr'     an attribute
//   '#text'     text content
//   'elem:key'  a repeated element <elem>; ':key' only names it so templates can merge it
//   [ ... ]     repeated elements without names
// Hidden fields are not rendered.
// std.manifestXmlJsonml is not used because it does not escape text or attributes.
// Strings are joined with `+` because the `%` operator is very slow.
local xmlEsc(s) = std.foldl(
  function(acc, p) std.strReplace(acc, p[0], p[1]),
  [['&', '&amp;'], ['<', '&lt;'], ['>', '&gt;'], ['"', '&quot;']],
  std.toString(s)
);
local tag(k) = std.splitLimit(k, ':', 1)[0];
local children(v) = [k for k in std.objectFields(v) if !std.startsWith(k, '@') && k != '#text'];

local elem(name, v, depth) =
  local pad = std.join('', ['  ' for _ in std.range(1, depth)]);
  if !std.isObject(v) then
    pad + '<' + name + '>' + xmlEsc(v) + '</' + name + '>\n'
  else
    local attrs = std.join('', [
      ' ' + std.substr(k, 1, std.length(k) - 1) + '="' + xmlEsc(v[k]) + '"'
      for k in std.objectFields(v) if std.startsWith(k, '@')
    ]);
    local kids = std.join('', std.flattenArrays([
      if std.isArray(v[k]) then [elem(tag(k), x, depth + 1) for x in v[k]] else [elem(tag(k), v[k], depth + 1)]
      for k in children(v)
    ]));
    local text = if std.objectHas(v, '#text') then xmlEsc(v['#text']) else '';
    if kids == '' && text == '' then pad + '<' + name + attrs + '/>\n'
    else if kids == '' then pad + '<' + name + attrs + '>' + text + '</' + name + '>\n'
    else pad + '<' + name + attrs + '>' + text + '\n' + kids + pad + '</' + name + '>\n';

local xml(root, v) = elem(root, v, 0);
local yaml(v, header='') = header + std.manifestYamlDoc(v, quote_keys=false) + '\n';
// Make reads `$` as a reference and `#` as a comment, so both are escaped.
local mkEsc(s) = std.strReplace(std.strReplace(std.toString(s), '$', '$$'), '#', '\\#');
local mk(vars) = std.join('', [k + ' := ' + mkEsc(vars[k]) + '\n' for k in std.objectFields(vars)]);

// ---------------------------------------------------------------------------
// Checks: each returns true or fails with a message that says where the problem is.
// ---------------------------------------------------------------------------

local sections = ['domain', 'metaData', 'networkConfig', 'pools', 'ssh', 'userData', 'volumes'];
local cloudInitSections = ['metaData', 'networkConfig', 'userData'];

local get(o, k, default) = if std.objectHasAll(o, k) then o[k] else default;
local all(checks) = std.foldl(function(a, b) a && b, checks, true);
local fail(where, msg) = error where + ': ' + msg;

local checkHidden(where, o, allowed) =
  local hidden = std.setDiff(std.objectFieldsAll(o), std.objectFields(o));
  local unknown = [k for k in hidden if !std.member(allowed, k) && o[k] != null];
  if std.length(unknown) > 0 then fail(where, 'unknown hidden field ' + std.join(', ', unknown))
  else all(std.flattenArrays([
    if std.isObject(o[k]) then [checkHidden(where + '.' + k, o[k], [])]
    else if std.isArray(o[k]) then [checkHidden(where + '.' + k, x, []) for x in o[k] if std.isObject(x)]
    else []
    for k in std.objectFields(o)
  ]));
local policies = ['Disposable', 'Reusable', 'Shared'];
local checkPolicy(where, o) =
  local p = get(o, 'lifecyclePolicy', 'Disposable');
  if std.member(policies, p) then true else fail(where, 'lifecyclePolicy must be one of ' + std.join(', ', policies) + ', not ' + p);
local checkBool(where, o, k) =
  if std.isBoolean(get(o, k, false)) then true else fail(where, k + ' must be a boolean');
// Pool and volume names become Make variable names in vars.mk.
local checkName(where, s) =
  local bad = [c for c in std.stringChars(s) if std.member(' \t:=#$%/\\', c)];
  if std.length(bad) == 0 then true else fail(where, 'name must not contain ' + std.join('', bad));

// libvirt needs a capacity. Without one in the XML, rules.mk fills it in at run time.
local capacityFrom(where, v) =
  if std.objectHas(v, 'capacity') then 'xml'
  else if get(v, 'upload', '') != '' then 'upload'
  else if std.objectHas(v, 'backingStore') then 'backing'
  else fail(where, 'capacity is required unless the volume is uploaded or has a backing store');

local check(name, vm, pools, vols) =
  local seed = get(vm, 'seed', '');
  local ssh = get(vm, 'ssh', {});
  local cloudInit = std.setInter(std.objectFields(vm), cloudInitSections);
  local unknownSections = std.setDiff(std.objectFields(vm), sections);
  local unknownSsh = std.setDiff(std.objectFields(ssh), ['host', 'user']);
  all([
    if std.length(unknownSections) > 0 then fail(name, 'unknown section ' + std.join(', ', unknownSections)) else true,
    if std.length(unknownSsh) > 0 then fail(name + '.ssh', 'unknown field ' + std.join(', ', unknownSsh)) else true,
    if std.length(cloudInit) > 0 && seed == '' then fail(name, 'seed is required for cloud-init') else true,
    checkHidden(name + '.domain', vm.domain, ['autostart']),
    checkBool(name + '.domain', vm.domain, 'autostart'),
    checkHidden(name + '.ssh', ssh, []),
  ] + [checkHidden(name + '.' + s, vm[s], []) for s in cloudInit] + std.flattenArrays([
    local where = name + '.pools.' + p;
    [checkName(where, p), checkHidden(where, pools[p], ['autostart', 'lifecyclePolicy']),
     checkBool(where, pools[p], 'autostart'), checkPolicy(where, pools[p])]
    for p in std.objectFields(pools)
  ]) + std.flattenArrays([
    local where = name + '.volumes.' + x.id;
    [checkName(where, x.pool), checkName(where, x.name),
     checkHidden(where, x.obj, ['download', 'lifecyclePolicy', 'upload']), checkPolicy(where, x.obj),
     if get(x.obj, 'download', '') != '' && get(x.obj, 'upload', '') == '' then fail(where, 'download needs upload') else true,
     capacityFrom(where, x.obj) != '']
    for x in vols
  ]));

// ---------------------------------------------------------------------------
// Provisioner variables: what rules.mk reads from vars.mk.
// ---------------------------------------------------------------------------

local yesNo(b) = if b then 'yes' else 'no';
local record(prefix, fields) = { [prefix + '.' + k]: fields[k] for k in std.objectFields(fields) };

local vars(name, vm, pools, vols) =
  local ssh = get(vm, 'ssh', {});
  // Backing volumes must exist before the volumes on top of them.
  local ordered = [x for x in vols if !std.objectHas(x.obj, 'backingStore')]
                  + [x for x in vols if std.objectHas(x.obj, 'backingStore')];
  {
    NAME: vm.domain.name,
    LIBVIRT_DEFAULT_URI: vm.node.uri,
    AUTOSTART: yesNo(get(vm.domain, 'autostart', false)),
    SEED: get(vm, 'seed', ''),
    SSH_USER: get(ssh, 'user', ''),
    SSH_HOST: get(ssh, 'host', ''),
    POOLS: std.join(' ', std.objectFields(pools)),
    VOLUMES: std.join(' ', [x.id for x in ordered]),
  } + std.foldl(function(acc, p) acc + record('POOL.' + p, {
    autostart: yesNo(get(pools[p], 'autostart', false)),
    lifecyclePolicy: get(pools[p], 'lifecyclePolicy', 'Disposable'),
  }), std.objectFields(pools), {}) + std.foldl(function(acc, x) acc + record('VOLUME.' + x.id, {
    lifecyclePolicy: get(x.obj, 'lifecyclePolicy', 'Disposable'),
    upload: get(x.obj, 'upload', ''),
    download: get(x.obj, 'download', ''),
    capacity: capacityFrom(name + '.volumes.' + x.id, x.obj),
    backing: if std.objectHas(x.obj, 'backingStore') then x.obj.backingStore.path else '',
  }), vols, {});

// ---------------------------------------------------------------------------
// Files: the layout of a provisioner, the directory of one VM.
// ---------------------------------------------------------------------------

local files(name, vm) =
  local pools = get(vm, 'pools', {});
  local volumes = get(vm, 'volumes', {});
  local vols = std.flattenArrays([
    [{ id: p + '/' + v, pool: p, name: v, obj: volumes[p][v] } for v in std.objectFields(volumes[p])]
    for p in std.objectFields(volumes)
  ]);
  local seed = get(vm, 'seed', '');
  assert check(name, vm, pools, vols);
  {
    Makefile: 'include vars.mk\ninclude ../rules.mk\n',
    'vars.mk': mk(vars(name, vm, pools, vols)),
    'domain.xml': xml('domain', vm.domain),
  }
  + { ['pools/' + p + '.xml']: xml('pool', pools[p]) for p in std.objectFields(pools) }
  + { ['volumes/' + x.id + '.xml']: xml('volume', x.obj) for x in vols }
  + (if std.objectHas(vm, 'userData') then { [seed + '.d/user-data']: yaml(vm.userData, '#cloud-config\n') } else {})
  + (if std.objectHas(vm, 'metaData') then { [seed + '.d/meta-data']: yaml(vm.metaData) } else {})
  + (if std.objectHas(vm, 'networkConfig') then { [seed + '.d/network-config']: yaml(vm.networkConfig) } else {});

// registry: the index of a registry, whose vms are { name: VM }.
// Returns { 'name/path': content } and rules.mk for `jsonnet -S -m`.
function(registry)
  local vms = registry.vms;
  local out = { [name]: files(name, vms[name]) for name in std.objectFields(vms) };
  { [name + '/' + f]: out[name][f] for name in std.objectFields(out) for f in std.objectFields(out[name]) }
  + { 'rules.mk': importstr 'rules.mk' }
