#!/bin/bash
set -e
set -o pipefail

shred -z secret-files/ssh_host_rsa_key || true
rm secret-files/ -rf
