#!/bin/bash
set -e
set -o pipefail

mkdir secret-files || true
ssh-keygen -f secret-files/ssh_host_rsa_key -N ''
openssl req -x509 -nodes -days 100000 -newkey rsa:2048 -keyout secret-files/key.pem -out secret-files/cert.pem
[[ -e secret-files/regcreds.json ]] || echo '{"auths": {}}'> secret-files/regcreds.json

echo
echo '****************************************************************'
echo '* IMPORTANT: Do not forget to run the "delete-secret-files.sh" *'
echo '* script once you have successfully bootstrapped your          *'
echo '* Kubernetes cluster!                                          *'
echo '****************************************************************'
