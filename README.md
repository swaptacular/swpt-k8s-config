# swpt-k8s-config
Swaptacular GitOps repo for deploying Kubernetes clusters

## Bootstrapping the GitOps

```console

$ cd simple-git-server/
$ ./generate-secret-files.sh

$ export MY_ROOT_CA_CRT_FILE=~/src/swpt_ca_scripts/root-ca.crt  # the path to your Swaptacular node's self-signed root-CA certificate
$ openssl x509 -in "$MY_ROOT_CA_CRT_FILE" -pubkey -noout > CERT.tmp
$ ssh-keygen -f CERT.tmp -i -m PKCS8 >> trusted_user_ca_keys
$ rm CERT.tmp  # Execute the previous 4 lines for each one of your Swaptacular nodes.

$ export MY_CLUSTER_IP=127.0.0.1  # the public IP of your Kubernetes cluster
$ kubectl apply -k .
namespace/simple-git-server configured
configmap/sshd-config-t9g57f6875 configured
secret/host-keys configured
service/git-server configured
persistentvolumeclaim/git-repositories configured
deployment.apps/simple-git-server configured

$ ssh git@$MY_CLUSTER_IP -p 2222
Welcome to the restricted login shell for Git!
Run 'help' for help, or 'exit' to leave.  Available commands:
-------------------------------------------------------------
git-init
ls
mkdir
rm
vi

git> mkdir /srv/git/fluxcd.git
git> git-init --bare -b master /srv/git/fluxcd.git
Initialized empty Git repository in /srv/git/fluxcd.git/
git> exit
Connection to 127.0.0.1 closed.

$ sudo sh -c "echo $MY_CLUSTER_IP git-server.simple-git-server.svc.cluster.local >> /etc/hosts"

$ flux bootstrap git --url=ssh://git@git-server.simple-git-server.svc.cluster.local:2222/srv/git/fluxcd.git --branch=master --private-key-file=secret-files/ssh_host_rsa_key --path=clusters/dev

$ ./delete-secret-files.sh
```
