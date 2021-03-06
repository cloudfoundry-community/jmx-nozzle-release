#! /usr/bin/env bash

# This script just enacts the bosh-lite docs found here:
# https://bosh.io/docs/bosh-lite
# NB: requires sudo, may call for password entry

set -eux

export VBOX_DEPLOYMENT_DIR=~/deployments/vbox
mkdir -p "${VBOX_DEPLOYMENT_DIR}"

pushd ~/workspace/bosh-system-metrics-server-release
    bosh create-release --tarball=/tmp/server-release.tgz --force
popd

pushd "${VBOX_DEPLOYMENT_DIR}"
	bosh -n create-env ~/workspace/bosh-deployment/bosh.yml \
	        --recreate \
		--state ./state.json \
		-o ~/workspace/bosh-deployment/virtualbox/cpi.yml \
		-o ~/workspace/bosh-deployment/virtualbox/outbound-network.yml \
		-o ~/workspace/bosh-deployment/bosh-lite.yml \
		-o ~/workspace/bosh-deployment/bosh-lite-runc.yml \
		-o ~/workspace/bosh-deployment/jumpbox-user.yml \
		-o ~/workspace/bosh-deployment/uaa.yml \
		-o ~/workspace/bosh-system-metrics-server-release/manifests/server-ops.yml \
		-o ~/workspace/bosh-deployment/local-dns.yml\
		--vars-store ./creds.yml \
		-v director_name="Bosh Lite Director" \
		-v internal_ip=192.168.50.6 \
		-v external_ip=192.168.50.6 \
		-v internal_gw=192.168.50.1 \
		-v internal_cidr=192.168.50.0/24 \
		-v outbound_network_name=NatNetwork

	bosh alias-env vbox -e 192.168.50.6 --ca-cert <(bosh int ./creds.yml --path /director_ssl/ca)
	bosh -e vbox login --client=admin --client-secret="$(bosh int ./creds.yml --path /admin_password)"
popd

# Try to add routes - they may already be there, so it may be okay to fail
set +e
  if [ "$(uname -s)" == Darwin ]; then
    sudo route add -net 10.244.0.0/16 192.168.50.6
  else
    sudo ip route add 10.244.0.0/16 via 192.168.50.6
  fi
set -e

bosh -n -e vbox update-cloud-config ~/workspace/bosh-deployment/warden/cloud-config.yml
bosh -n -e vbox upload-stemcell https://bosh.io/d/stemcells/bosh-warden-boshlite-ubuntu-trusty-go_agent
