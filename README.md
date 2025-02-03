# swpt-k8s-config
Swaptacular GitOps repo for deploying Kubernetes clusters

## Bootstrapping the GitOps

``` console
$ export CLUSTER_IP=127.0.0.1  # the public IP of your Kubernetes cluster
$ cd simple-git-server/
$ pwd
/home/johndoe/swpt-k8s-config/simple-git-server

$ export ROOT_CA_CRT_FILE=~/swpt_ca_scripts/root-ca.crt  # the path to your Swaptacular node's self-signed root-CA certificate
$ openssl x509 -in "$ROOT_CA_CRT_FILE" -pubkey -noout > CERT.tmp
$ ssh-keygen -f CERT.tmp -i -m PKCS8 >> trusted_user_ca_keys
$ rm CERT.tmp  # Execute these 4 lines for each Swaptacular node that you will run on your Kubernetes cluster.

$ ./generate-secret-files.sh  # Generates an SSH private/public key pair.
Generating public/private rsa key pair.
Your identification has been saved in secret-files/ssh_host_rsa_key
Your public key has been saved in secret-files/ssh_host_rsa_key.pub
The key fingerprint is:
SHA256:V5z4od4LmSBF3MyXsTzPBjt+yYOKLJQqrZS2ULerNyM johndoe@mycomputer
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

$ kubectl apply -k .  # Installs a simple Git server to your Kubernetes cluster.
...
...
namespace/simple-git-server configured
configmap/sshd-config-t9g57f6875 configured
secret/host-keys configured
service/git-server configured
persistentvolumeclaim/git-repositories configured
deployment.apps/simple-git-server configured

$ ssh git@$CLUSTER_IP -p 2222  # Here we create an empty "/srv/git/fluxcd.git" repository:
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

$ git remote add k8s-repo ssh://git@$CLUSTER_IP:2222/srv/git/fluxcd.git
$ git push k8s-repo master  # Copies the GitOps repo to the just created empty repository.
Enumerating objects: 81, done.
Counting objects: 100% (81/81), done.
Delta compression using up to 4 threads
Compressing objects: 100% (79/79), done.
Writing objects: 100% (79/79), 25.67 KiB | 1.97 MiB/s, done.
Total 79 (delta 51), reused 0 (delta 0), pack-reused 0
To ssh://127.0.0.1:2222/srv/git/fluxcd.git
   59b1758..b019dfe  master -> master

$ sudo sh -c "echo $CLUSTER_IP git-server.simple-git-server.svc.cluster.local >> /etc/hosts"
$ cat /etc/hosts  # The name of the repo has been added to your hosts file.
...
...
127.0.0.1 localhost
127.0.0.1 git-server.simple-git-server.svc.cluster.local

$ export CLUSTER_NAME=clusters/dev  # must be a subdirectory in the "./clusters" directory.

$ flux bootstrap git --url=ssh://git@git-server.simple-git-server.svc.cluster.local:2222/srv/git/fluxcd.git --branch=master --private-key-file=secret-files/ssh_host_rsa_key --path=$CLUSTER_NAME  # Bootstraps FluxCD from the repo.
...
...
Configuring the cluster to synchronize with the repository
Flux controllers installed and configured successfully

$ ./delete-secret-files.sh  # The SSH secrets have been copied to the cluster, so we do not need them anymore.
```

To authenticate to the Git repository on the Kubernetes cluster, you will need to issue an SSH certificate to yourself:

``` console
$ export ROOT_CA_PRIVATE_KEY_FILE=~/swpt_ca_scripts/private/root-ca.key  # the path to your Swaptacular node's private key

$ ls ~/.ssh  # Inspect the SSH keys installed on your computer:
id_rsa  id_rsa.pub  known_hosts

$ ssh-keygen -s "$ROOT_CA_PRIVATE_KEY_FILE" -I johndoe -n git ~/.ssh/id_rsa.pub  # Issues a certificate for the "id_rsa.pub" key.
Enter passphrase:
Signed user key /home/johndoe/.ssh/id_rsa-cert.pub: id "johndoe" serial 0 for git valid forever
```

The only remaining task is to configure secrets management with SOPS and GPG:

``` console
$ cd ..
$ pwd
/home/johndoe/swpt-k8s-config

$ gpg --batch --full-generate-key <<EOF
%no-protection
Key-Type: 1
Key-Length: 4096
Subkey-Type: 1
Subkey-Length: 4096
Expire-Date: 0
Name-Comment: flux secrets
Name-Real: ${CLUSTER_NAME}
EOF

$ gpg --list-secret-keys $CLUSTER_NAME
gpg: checking the trustdb
gpg: marginals needed: 3  completes needed: 1  trust model: pgp
gpg: depth: 0  valid:   3  signed:   0  trust: 0-, 0q, 0n, 0m, 0f, 3u
sec   rsa4096 2025-02-03 [SCEA]
      46B3059077BEFD9D1BD3B1488C6B09689C8A214A
uid           [ultimate] cluster.yourdomain.com (flux secrets)
ssb   rsa4096 2025-02-03 [SEA]

$ export KEY_FP=46B3059077BEFD9D1BD3B1488C6B09689C8A214A  # the fingerprint of the newly created GPG key

$ gpg --export-secret-keys --armor "${KEY_FP}" | kubectl create secret generic sops-gpg --namespace=flux-system --from-file=sops.asc=/dev/stdin  # Creates a Kubernetes secret with the GPG private key.
secret/sops-gpg created

$ gpg --delete-secret-keys "${KEY_FP}"  # We do not need the GPG private key anymore.
gpg (GnuPG) 2.2.40; Copyright (C) 2022 g10 Code GmbH
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.


sec  rsa4096/9F85AF312DC6F642 2025-02-03 clusters/dev (flux secrets)

Delete this key from the keyring? (y/N)
This is a secret key! - really delete? (y/N) y

$ gpg --export --armor "${KEY_FP}" > $CLUSTER_NAME/.sops.pub.asc
$ git add $CLUSTER_NAME/.sops.pub.asc  # Stores the GPG public key in the repo.

$ cat <<EOF > $CLUSTER_NAME/.sops.yaml
creation_rules:
  - path_regex: .*.yaml
    encrypted_regex: ^(data|stringData)$
    pgp: ${KEY_FP}
  - pgp: ${KEY_FP}
EOF
$ git add $CLUSTER_NAME/.sops.yaml  # Stores an example SOPS configuration file in the repo.

$ git commit -am 'Share GPG public key for secrets generation'
[master 1c50aeb] Share GPG public key for secrets generation
 2 files changed, 63 insertions(+)
 create mode 100644 clusters/dev/.sops.pub.asc
 create mode 100644 clusters/dev/.sops.yaml

$ git push origin master  # Pushes the changes to the upstream git server.
Enumerating objects: 8, done.
Counting objects: 100% (8/8), done.
Delta compression using up to 4 threads
Compressing objects: 100% (4/4), done.
Writing objects: 100% (5/5), 3.93 KiB | 1.31 MiB/s, done.
Total 5 (delta 2), reused 0 (delta 0), pack-reused 0
remote: Resolving deltas: 100% (2/2), completed with 2 local objects.
To github.com:epandurski/swpt-k8s-config.git
   c46b496..1c50aeb  master -> master
```

Team members can import the public PGP after they pull the Git repository:
``` console
$ gpg --import clusters/dev/.sops.pub.asc
gpg: key 9F85AF312DC6F642: "clusters/dev (flux secrets)" not changed
gpg: Total number processed: 1
gpg:              unchanged: 1
```
