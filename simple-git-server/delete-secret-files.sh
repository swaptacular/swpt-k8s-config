#!/bin/bash
set -e
set -o pipefail

shred -z secret-files/ssh_host_rsa_key || true
shred -z secret-files/regcreds.json || true
shred -z secret-files/key.pem || true
shred -z secret-files/sops.asc || true
shred -z secret-files/alertmanager_viewers || true
shred -z secret-files/prometheus_viewers || true
rm secret-files/ -rf
