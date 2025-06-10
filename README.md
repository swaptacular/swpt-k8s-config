# swpt-k8s-config
Swaptacular GitOps repo for deploying Kubernetes clusters

## Bootstrapping the GitOps

First you need to install a Git server to your Kubernetes cluster,
which will contain a copy of your GitOps repository.

If you want to use a private container image registry (recommended for
production deployments), you will have to prepare an "image pull
secret" containing the credentials for pulling from your private
registry. Here is how to do this:

**Note**: In this example, the name of the user is `johndoe`.

``` console
$ docker login registry.example.com  # Enter the name of your private registry here.
Username: johndoe
Password:
WARNING! Your password will be stored unencrypted in /home/johndoe/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded

$ cat ~/.docker/config.json
{
	"auths": {
		"registry.example.com": {
			"auth": "am9obmRvZToxMjMK"
		}
	}
}

$ cd simple-git-server/
$ pwd
/home/johndoe/swpt-k8s-config/simple-git-server

$ cp ~/.docker/config.json secret-files/regcreds.json
$ cat secret-files/regcreds.json  # contains the "image pull secret"
{
	"auths": {
		"registry.example.com": {
			"auth": "am9obmRvZToxMjMK"
		}
	}
}
```

You will also need to change the `simple-git-server/kustomization.yaml`
file to use your private container image registry for the Git server's
image.

If you DO NOT want to use a private container image registry, you may
skip the previous steps, and start installing the Git server:

``` console
$ sed -i -E '/^([^#].*)?$/d' trusted_user_ca_keys  # Removes existing trusted CA keys, preserves comments.

$ export ROOT_CA_CRT_FILE=~/swpt_ca_scripts/root-ca.crt  # the path to your Swaptacular node's self-signed root-CA certificate
$ openssl x509 -in "$ROOT_CA_CRT_FILE" -pubkey -noout > CERT.tmp
$ ssh-keygen -f CERT.tmp -i -m PKCS8 >> trusted_user_ca_keys
$ rm CERT.tmp  # Execute these 4 lines for each Swaptacular node that you will run on your Kubernetes cluster.

$ cat trusted_user_ca_keys  # Shows the trusted CA keys, one key per line.
...
...
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCJfDWvw+LxOW1ECcpoHdFw+ygG4XSeVrB9JFVdIcrrVHqIXDPjvJKXrQ2TadeaTA2i1XUv+XwJr2ZN3OZ6dGLxddPQD4ZG6ciT4iK4TOjAiauE8gQPHR1uzShoK2TGfuYXma2lOnB4s/w5Tif+an5NzHRuDzAwXHPVfVeb9kgIO4A761CztwdTPyEM0jocpoz03Ch4DgYvwf2r+P+1x2Hm5htipNigkhdwtdw5yjUuTR3ylFIeokwcIZomYcGGO66i7EWGYzhr811uApgLJH5YtqeFnD054ia+AbOdCXEr1ZXvpol1Vqo6p/R015zBjMQ8wcdzd+PMSzHvXMLMjG6POhRvQ2yy3cmDpPPIzMHOcNxXhdarVLKDt8/SJlo4O+buAbHdib0pRXpqbPS6rjFwArB93H7TOcY+xl3EGAsjz+1wRPlbi1TN9XNRyQKxLK21QpYql4iYoD8Wac6iWQDDKNaTr88YFUu+MMUfZuQ+0MmXQ1yA/wfqyC9pjm4tkc0=

$ git add trusted_user_ca_keys
$ git commit -m 'Update simple-git-server/trusted_user_ca_keys'
[master 2f1bd3c] Update simple-git-server/trusted_user_ca_keys
 1 file changed, 1 insertion(+), 1 deletion(-)

$ git push origin master  # Pushes the trusted CA keys to the GitOps repository.
Enumerating objects: 11, done.
Counting objects: 100% (11/11), done.
Delta compression using up to 4 threads
Compressing objects: 100% (7/7), done.
Writing objects: 100% (7/7), 1.94 KiB | 662.00 KiB/s, done.
Total 7 (delta 5), reused 0 (delta 0), pack-reused 0
remote: Resolving deltas: 100% (5/5), completed with 4 local objects.
To github.com:johndoe/swpt-k8s-config.git
   dca1e7a..175b62a  master -> master

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
secret/regcreds configured
service/git-server configured
persistentvolumeclaim/git-repositories configured
deployment.apps/simple-git-server configured
```

In order to authenticate to the just installed Git server, you will
need to issue an SSH certificate to yourself:

``` console
$ export ROOT_CA_PRIVATE_KEY_FILE=~/swpt_ca_scripts/private/root-ca.key  # the path to your Swaptacular node's private key

$ ls ~/.ssh  # Inspect the SSH keys installed on your computer:
id_rsa  id_rsa.pub  known_hosts

$ ssh-keygen -s "$ROOT_CA_PRIVATE_KEY_FILE" -I johndoe -n git ~/.ssh/id_rsa.pub  # Issues a certificate for the "id_rsa.pub" key.
Enter passphrase:
Signed user key /home/johndoe/.ssh/id_rsa-cert.pub: id "johndoe" serial 0 for git valid forever

$ ls ~/.ssh
id_rsa  id_rsa.pub  id_rsa-cert.pub  known_hosts
```

Then you need to connect to the Git server, create a new
`/srv/git/fluxcd.git` repository, and copy the whole content of the
GitOps repo into it:

``` console
$ export CLUSTER_EXTERNAL_IP=127.0.0.1  # the public IP of your Kubernetes cluster

$ ssh git@$CLUSTER_EXTERNAL_IP -p 2222  # Create an empty repository:
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

$ git remote add k8s-repo ssh://git@$CLUSTER_EXTERNAL_IP:2222/srv/git/fluxcd.git

$ git push k8s-repo master  # Copies the GitOps repo to the just created empty repository.
Enumerating objects: 81, done.
Counting objects: 100% (81/81), done.
Delta compression using up to 4 threads
Compressing objects: 100% (79/79), done.
Writing objects: 100% (79/79), 25.67 KiB | 1.97 MiB/s, done.
Total 79 (delta 51), reused 0 (delta 0), pack-reused 0
To ssh://127.0.0.1:2222/srv/git/fluxcd.git
   59b1758..b019dfe  master -> master
```

The next step is to bootstraps FluxCD from the Git server on your
Kubernetes cluster.

If you want to use a private container image registry for the FluxCD
images, you will need to add the following options to the `flux
bootstrap` command:

1. Specify your private registry with the `--registry
   registry.example.com/johndoe` option (the default is
   "ghcr.io/fluxcd")

2. Give the username and the password for your private registry with
   the `--registry-creds username:password` option.

3. Specify the name of the image pull secret with the
   `--image-pull-secret regcreds` option. The name must be "regcreds".

``` console
$ sudo sh -c "sed -i '/git-server.simple-git-server.svc.cluster.local/d' /etc/hosts"
$ sudo sh -c "echo $CLUSTER_EXTERNAL_IP git-server.simple-git-server.svc.cluster.local >> /etc/hosts"
$ cat /etc/hosts  # The internal name of the Git-server has been added to your hosts file.
...
...
127.0.0.1 localhost
127.0.0.1 git-server.simple-git-server.svc.cluster.local

$ export CLUSTER_NAME=dev  # one of the subdirectories in the "./clusters/" directory
$ export CLUSTER_DIR=clusters/$CLUSTER_NAME

$ flux bootstrap git --url=ssh://git@git-server.simple-git-server.svc.cluster.local:2222/srv/git/fluxcd.git --branch=master --private-key-file=secret-files/ssh_host_rsa_key --path=$CLUSTER_DIR
...
...
Configuring the cluster to synchronize with the repository
Flux controllers installed and configured successfully
```

The only remaining task is to configure secrets management with
[SOPS](https://github.com/getsops/sops) and
[GnuPG / PGP](https://www.gnupg.org/):

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
Name-Real: Swaptacular ${CLUSTER_DIR}
EOF

$ gpg --list-secret-keys $CLUSTER_DIR
sec   rsa4096 2025-02-05 [SCEA]
      2ED21ED3DBBF5A37898D9D316225432F3481C8E0
uid           [ultimate] Swaptacular clusters/dev (flux secrets)
ssb   rsa4096 2025-02-05 [SEA]

$ export KEY_FP=2ED21ED3DBBF5A37898D9D316225432F3481C8E0  # the PGP key fingerprint

$ gpg --export-secret-keys --armor "${KEY_FP}" | kubectl create secret generic sops-gpg --namespace=flux-system --from-file=sops.asc=/dev/stdin  # Creates a Kubernetes secret with the PGP private key.
secret/sops-gpg created

$ gpg --edit-key "${KEY_FP}"  # Protect the PGP private key with strong password(s):
gpg (GnuPG) 2.2.40; Copyright (C) 2022 g10 Code GmbH
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Secret key is available.

sec  rsa4096/6225432F3481C8E0
     created: 2025-02-05  expires: never       usage: SCEA
     trust: ultimate      validity: ultimate
ssb  rsa4096/8D9D22305D43BA1B
     created: 2025-02-05  expires: never       usage: SEA
[ultimate] (1). Swaptacular clusters/dev (flux secrets)

gpg> passwd
<Choose and confirm a strong password for "sec" (the primary key)>
<Choose and confirm a strong password for "sbb" (the subkey)>
gpg> quit

$ gpg --export --armor "${KEY_FP}" > $CLUSTER_DIR/.sops.pub.asc
$ git add $CLUSTER_DIR/.sops.pub.asc  # Stores the PGP public key in the repo.

$ cat <<EOF > $CLUSTER_DIR/.sops.yaml
creation_rules:
  - path_regex: .*.yaml
    encrypted_regex: ^(data|stringData)$
    pgp: ${KEY_FP}
  - pgp: ${KEY_FP}
EOF
$ git add $CLUSTER_DIR/.sops.yaml  # Stores an example SOPS configuration file in the repo.

$ git commit -m 'Share PGP public key for secrets generation'
[master 1c50aeb] Share PGP public key for secrets generation
 2 files changed, 63 insertions(+)
 create mode 100644 clusters/dev/.sops.pub.asc
 create mode 100644 clusters/dev/.sops.yaml

$ git push origin master  # Pushes the changes to the GitOps repository.
Enumerating objects: 8, done.
Counting objects: 100% (8/8), done.
Delta compression using up to 4 threads
Compressing objects: 100% (4/4), done.
Writing objects: 100% (5/5), 3.93 KiB | 1.31 MiB/s, done.
Total 5 (delta 2), reused 0 (delta 0), pack-reused 0
remote: Resolving deltas: 100% (2/2), completed with 2 local objects.
To github.com:johndoe/swpt-k8s-config.git
   c46b496..1c50aeb  master -> master
```

Now, when team members clone the GitOps repository, they will be able
to import the public PGP key, and create a SOPS configuration file:

``` console
$ gpg --import $CLUSTER_DIR/.sops.pub.asc  # Imports the public PGP key.
gpg: key 9F85AF312DC6F642: "clusters/dev (flux secrets)" not changed
gpg: Total number processed: 1
gpg:              unchanged: 1

$ cp $CLUSTER_DIR/.sops.yaml .  # Creates a SOPS configuration file.
```

It is **highly recommended** that you create a backup copy of the PGP
private key. Make sure you do not forget the password(s) which you
chose to protect the PGP private key:

``` console
$ gpg --export-secret-key --armor "${KEY_FP}" > /mnt/backup/sops.private.asc

$ cat /mnt/backup/sops.private.asc  # a password-protected backup copy of the PGP private key
-----BEGIN PGP PRIVATE KEY BLOCK-----

lQdGBGeiOpcBEAC5BY0+BAsdEgAvnoFcf26mpAVdHJMJJndg7sZazL43ubt19Mrp
gb4erMOVTi8lGYLLJ2/kvOFClo4K6qKQUBT6uvQR3GW4ZMQy8lKq1cePeIDpQytm
...
...
at0elqM15f4A24DhqAPT2BsHlxa55yliv7GTvRC1isT6iZ8Kj4IE1caAdHopgBpu
nHlB9rEGqlTEhDYLc3igwmVrPPtqf3F2vBOpIEDWbwvxQbjvhcO6pGZ5pZNn9W89
QbIgaiHj7aTsupibdTde
=o9oQ
-----END PGP PRIVATE KEY BLOCK-----
```

If you do not plan to use SOPS to decrypt secrets on this machine,
consider deleting the PGP private key from the machine. If you need
it, you can always import the secret decryption key from your backup
copy:

``` console
$ gpg --delete-secret-keys "${KEY_FP}"  # Delete the private key.
gpg (GnuPG) 2.2.40; Copyright (C) 2022 g10 Code GmbH
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.


sec  rsa4096/6225432F3481C8E0 2025-02-05 Swaptacular clusters/dev (flux secrets)

Delete this key from the keyring? (y/N)
This is a secret key! - really delete? (y/N) y

$ gpg --import /mnt/backup/sops.private.asc  # Import the private key from your backup copy.
gpg: key 6225432F3481C8E0: "Swaptacular clusters/dev (flux secrets)" not changed
gpg: key 6225432F3481C8E0: secret key imported
gpg: Total number processed: 1
gpg:              unchanged: 1
gpg:       secret keys read: 1
gpg:  secret keys unchanged: 1
```

Now that you have configured SOPS, if you use a private container
image registry, you will have to encrypt your "image pull secret"
file. Skip this step if you DO NOT use a private container image
registry:

``` console
$ sops encrypt --input-type binary simple-git-server/secret-files/regcreds.json > apps/$CLUSTER_NAME/regcreds.json.encrypted
$ sops encrypt --input-type binary simple-git-server/secret-files/regcreds.json > infrastructure/$CLUSTER_NAME/regcreds.json.encrypted
$ git add apps/$CLUSTER_NAME/regcreds.json.encrypted
$ git add infrastructure/$CLUSTER_NAME/regcreds.json.encrypted
$ git commit -m 'Update regcreds'
[master 2f1bd3c] Update regcreds
 2 files changed, 2 insertions(+), 2 deletions(-)

$ git push origin master  # Pushes the updated secret to the GitOps repository.
Enumerating objects: 11, done.
Counting objects: 100% (11/11), done.
Delta compression using up to 4 threads
Compressing objects: 100% (7/7), done.
Writing objects: 100% (7/7), 1.94 KiB | 662.00 KiB/s, done.
Total 7 (delta 5), reused 0 (delta 0), pack-reused 0
remote: Resolving deltas: 100% (5/5), completed with 4 local objects.
To github.com:johndoe/swpt-k8s-config.git
   dca1e7a..175b62a  master -> master

$ git push k8s-repo master  # Pushes the updated secret to the Kubernetes cluster.
Enumerating objects: 11, done.
Counting objects: 100% (11/11), done.
Delta compression using up to 4 threads
Compressing objects: 100% (7/7), done.
Writing objects: 100% (7/7), 1.94 KiB | 662.00 KiB/s, done.
Total 7 (delta 5), reused 0 (delta 0), pack-reused 0
remote: Resolving deltas: 100% (5/5), completed with 4 local objects.
To github.com:johndoe/swpt-k8s-config.git
   dca1e7a..175b62a  master -> master
```

Finally, do not forget to delete the unencrypted secrets from the
`simple-git-server` directory:

``` console
$ cd simple-git-server
$ ./delete-secret-files.sh  # The secrets have already been copied to the cluster.
```
