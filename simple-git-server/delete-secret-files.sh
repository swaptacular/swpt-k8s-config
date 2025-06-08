#!/bin/bash
set -e
set -o pipefail

shred -z secret-files/ssh_host_rsa_key || true
shred -z secret-files/regcreds.json || true
rm secret-files/ -rf
