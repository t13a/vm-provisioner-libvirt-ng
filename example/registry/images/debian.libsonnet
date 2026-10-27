function(version) {
  local codename = { '12': 'bookworm', '13': 'trixie' }[version],
  url: 'https://cloud.debian.org/images/cloud/' + codename + '/latest/debian-' + version + '-generic-amd64.qcow2',
  volume: 'debian-cloud-' + version + '-amd64.qcow2',
  format: 'qcow2',
  sshUser: 'debian',
}
