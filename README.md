# swpt-k8s-config
Swaptacular GitOps repo for deploying Kubernetes clusters

## Bootstrapping the GitOps

```console
$ export MY_CLUSTER_IP=127.0.0.1  # the public IP of your Kubernetes cluster
$ cd simple-git-server/
$ pwd
/home/evgeni/src/swpt-k8s-config/simple-git-server

$ export MY_ROOT_CA_CRT_FILE=~/src/swpt_ca_scripts/root-ca.crt  # the path to your Swaptacular node's self-signed root-CA certificate
$ openssl x509 -in "$MY_ROOT_CA_CRT_FILE" -pubkey -noout > CERT.tmp
$ ssh-keygen -f CERT.tmp -i -m PKCS8 >> trusted_user_ca_keys
$ rm CERT.tmp  # Execute these 4 lines for each one of your Swaptacular nodes.

$ ./generate-secret-files.sh
Generating public/private rsa key pair.
Your identification has been saved in secret-files/ssh_host_rsa_key
Your public key has been saved in secret-files/ssh_host_rsa_key.pub
The key fingerprint is:
SHA256:V5z4od4LmSBF3MyXsTzPBjt+yYOKLJQqrZS2ULerNyM evgeni@t470s
The key's randomart image is:
+---[RSA 3072]----+
|       ..+  .o   |
|       .. ++oo   |
|        . ..X    |
|       .   + B   |
|  . . ..S o + +  |
| . o .o. + = = . |
|. +..o    = + =  |
| +E.*... . o o . |
|  +*.o .o . .    |
+----[SHA256]-----+

****************************************************************
* IMPORTANT: Do not forget to run the "delete-secret-files.sh" *
* script once you have successfully bootstrapped your          *
* Kubernetes cluster!                                          *
****************************************************************

$ kubectl apply -k .
...
...
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
...
...
Configuring the cluster to synchronize with the repository
Flux controllers installed and configured successfully

$ ./delete-secret-files.sh
```
