# swpt-k8s-config
Swaptacular GitOps repo for deploying Kubernetes clusters

## Bootstrapping the GitOps

```console
$ export MY_CLUSTER_IP=127.0.0.1  # Put here the public IP of your Kubernetes cluster.

$ cd simple-git-server/

$ <Edit the "trusted_user_ca_keys" file.>

$ ./generate-secret-files.sh

$ kubectl apply -k simple-git-server/

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

$ <Create "fluxcd.git" empty bare repo.>

$ sudo sh -c "echo $MY_CLUSTER_IP git-server.simple-git-server.svc.cluster.local >> /etc/hosts"

$ flux bootstrap git \
--url=ssh://git@git-server.simple-git-server.svc.cluster.local:2222/srv/git/fluxcd.git \
--branch=master \
--private-key-file=secret-files/ssh_host_rsa_key \
--path=clusters/dev

$ ./delete-secret-files.sh
```
