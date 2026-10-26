# The provisioner. It holds no VM data: everything comes from vars.mk and the
# files that lib/renderer.libsonnet writes next to it, so the two change together.
.DELETE_ON_ERROR:
MAKEFLAGS += --no-builtin-rules --no-builtin-variables --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -euo pipefail -O nullglob -c

VIRSH ?= virsh
CURL ?= curl
MKISOFS ?= xorriso -as mkisofs
SSH ?= ssh
SSH_OPTS ?=

export LIBVIRT_DEFAULT_URI

ssh_target = $(or $(SSH_USER),$$(id -un))@$(or $(SSH_HOST),$$($(VIRSH) domifaddr $(NAME) | grep -Eo '[0-9.]+/[0-9]+' | cut -d/ -f1 | head -n1))

# Volumes are named POOL/VOLUME, and their records in vars.mk are VOLUME.POOL/VOLUME.*.
pool_of = $(word 1,$(subst /, ,$(1)))
vol_of = $(word 2,$(subst /, ,$(1)))
# $(call deletable,VOLUME|POOL,NAMES): the names whose deletionPolicy is Delete.
deletable = $(foreach x,$(2),$(if $(filter Delete,$($(1).$(x).deletionPolicy)),$(x)))

# libvirt requires a capacity. When the XML has none, use the size of the uploaded
# file or the capacity of the backing volume, as Makefile.j2 of v1alpha1 did.
capacity_of = $(if $(filter upload,$(VOLUME.$(1).capacity)),stat -Lc%s $(VOLUME.$(1).upload),$(VIRSH) vol-dumpxml $(VOLUME.$(1).backing) --xpath '/volume/capacity/text()')
volume_xml = $(if $(filter xml,$(VOLUME.$(1).capacity)),cat volumes/$(1).xml,sed "s|</volume>|  <capacity unit='bytes'>$$($(call capacity_of,$(1)))</capacity>\n</volume>|" volumes/$(1).xml)

define download
if [ ! -e $(VOLUME.$(1).upload) ]; then \
  mkdir -p $(dir $(VOLUME.$(1).upload)); \
  $(CURL) -fL $(VOLUME.$(1).download) -o $(VOLUME.$(1).upload).part; \
  mv $(VOLUME.$(1).upload).part $(VOLUME.$(1).upload); \
fi;
endef

define create_pool
if ! $(VIRSH) pool-info $(1) >/dev/null 2>&1; then $(VIRSH) pool-define pools/$(1).xml; fi; \
$(VIRSH) pool-autostart $(if $(filter yes,$(POOL.$(1).autostart)),,--disable) $(1); \
if ! $(VIRSH) pool-info $(1) | grep -q '^State: *running'; then $(VIRSH) pool-start --build $(1); fi;
endef

define create_volume
if ! $(VIRSH) vol-info --pool $(call pool_of,$(1)) $(call vol_of,$(1)) >/dev/null 2>&1; then \
  $(call volume_xml,$(1)) | $(VIRSH) vol-create $(call pool_of,$(1)) /dev/stdin; \
  $(if $(VOLUME.$(1).upload),$(VIRSH) vol-upload --pool $(call pool_of,$(1)) $(call vol_of,$(1)) $(VOLUME.$(1).upload);) \
fi;
endef

define delete_volume
if $(VIRSH) vol-info --pool $(call pool_of,$(1)) $(call vol_of,$(1)) >/dev/null 2>&1; then \
  $(VIRSH) vol-delete --pool $(call pool_of,$(1)) $(call vol_of,$(1)); \
fi;
endef

define delete_pool
if $(VIRSH) pool-info $(1) 2>/dev/null | grep -q '^State: *running'; then $(VIRSH) pool-destroy $(1); fi; \
if $(VIRSH) pool-info $(1) >/dev/null 2>&1; then $(VIRSH) pool-undefine $(1); fi;
endef

# $(call teardown,VOLUMES,POOLS): undefine the domain, then delete the given volumes and pools.
# Volumes go first, so a retained volume in a deleted pool keeps its file.
define teardown
if $(VIRSH) dominfo $(NAME) >/dev/null 2>&1; then $(VIRSH) undefine --nvram $(NAME); fi
$(foreach v,$(1),$(call delete_volume,$(v)))
$(foreach p,$(2),$(call delete_pool,$(p)))
rm -f $(SEED)
endef

.PHONY: up down download create start stop delete delete-all console ssh wait-for-ready
up: create start
down: delete

download:
	$(foreach v,$(VOLUMES),$(if $(VOLUME.$(v).download),$(call download,$(v))))

ifneq ($(SEED),)
$(SEED): $(wildcard $(SEED).d/*)
	$(MKISOFS) -quiet -output $@ -volid cidata -joliet -rock $(SEED).d
endif

create: download $(SEED)
	$(foreach p,$(POOLS),$(call create_pool,$(p)))
	$(foreach v,$(VOLUMES),$(call create_volume,$(v)))
	$(VIRSH) define domain.xml
	$(VIRSH) autostart $(if $(filter yes,$(AUTOSTART)),,--disable) $(NAME)

start:
	if ! $(VIRSH) domstate $(NAME) | grep -q running; then $(VIRSH) start $(NAME); fi

stop:
	if $(VIRSH) domstate $(NAME) 2>/dev/null | grep -q running; then $(VIRSH) destroy $(NAME); fi

# delete keeps what has deletionPolicy Retain. delete-all removes that too.
delete: stop
	$(call teardown,$(call deletable,VOLUME,$(VOLUMES)),$(call deletable,POOL,$(POOLS)))

delete-all: stop
	$(call teardown,$(VOLUMES),$(POOLS))

console:
	$(VIRSH) console --force $(NAME)

ssh:
	$(SSH) $(SSH_OPTS) $(ssh_target)

# Wait for SSH, then report how cloud-init finished: exit 0 done, 2 degraded, 1 error.
wait-for-ready:
	until $(SSH) $(SSH_OPTS) -o ConnectTimeout=3 $(ssh_target) true 2>/dev/null; do sleep 3; done
	$(SSH) $(SSH_OPTS) $(ssh_target) cloud-init status --wait
