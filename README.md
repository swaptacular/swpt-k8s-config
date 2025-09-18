# Swaptacular GitOps repository for deploying to Kubernetes clusters

This repository serves as a template for deploying [Swaptacular nodes]
to [Kubernetes] clusters. It follows the [GitOps] paradigm, and aims
to make deploying Swaptacular nodes as simple as possible. The
resulting deployments are designed to:

  * Work on any standards-compliant Kubernetes cluster.

  * Be highly available and horizontally scalable.

  * Perform automatic database backups.

  * Provide cluster monitoring and log aggregation.

  * Require zero or near-zero administration.

  * Minimize external dependencies, which are limited to:
    - an [OCI image repository] for downloading Docker images;
    - an [Amazon S3]-compatible service for storing *encrypted*
      database backups;
    - an [SMTP server] for sending emails;
    - a [CAPTCHA] service for sign-in and sign-up.

    By default, [hCaptcha] is used, but the integration is generic and
    can easily support other CAPTCHA services, including custom
    implementations.

The rest of this file provides **step-by-step instructions** for
deploying one or more Swaptacular nodes to a Kubernetes cluster:

## Fork and clone this repository

First, you need to create a fork of this repository, and then clone it
locally:

**Note**: In this example, we use the username `johndoe`.

``` console
$ cd ~
$ mkdir src  # You may use other directory, if that is more convenient.
$ cd src
$ git clone git@github.com:johndoe/swpt-k8s-config.git
$ cd swpt-k8s-config/
$ pwd
/home/johndoe/src/swpt-k8s-config
```

## Choose a cluster name

Then, you need to choose a name for your cluster (e.g., `dev`):

``` console
$ export CLUSTER_NAME=dev  # Enter the name for your cluster here.
$ export CLUSTER_DIR=clusters/$CLUSTER_NAME
$ export GIT_INSTALL_DIR=simple-git-server/$CLUSTER_NAME
```

**Note:** When deploying to a [KinD] (Kubernetes in Docker) cluster,
you can use the provided `kind-cluster.yaml` configuration file. Also,
you may need to run the following command:

``` console
$ sudo sysctl fs.inotify.max_user_instances=8192
```

## Generate the cluster's PGP keys and configure SOPS

The next task is to configure secrets management using [SOPS] and
[GnuPG]:

``` console
$ pwd
/home/johndoe/src/swpt-k8s-config

$ cp -r simple-git-server/example/ $GIT_INSTALL_DIR  # Adds a git-install directory to the repo.
$ git add $GIT_INSTALL_DIR
$ mkdir $GIT_INSTALL_DIR/secret-files
$ ls -F $GIT_INSTALL_DIR
delete-secret-files.sh*    kustomization.yaml  secret-files/
generate-secret-files.sh*  manifests.yaml      static/

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

$ gpg --list-secret-keys $CLUSTER_DIR  # Shows the PGP key fingerprint (2ED21ED3DBBF5A37898D9D316225432F3481C8E0 in this example).
sec   rsa4096 2025-02-05 [SCEA]
      2ED21ED3DBBF5A37898D9D316225432F3481C8E0
uid           [ultimate] Swaptacular clusters/dev (flux secrets)
ssb   rsa4096 2025-02-05 [SEA]

$ export KEY_FP=$(gpg --list-secret-keys --with-colons $CLUSTER_DIR | awk -F: '/^fpr:/ {print $10; exit}')  # Extracts the PGP key fingerprint.
$ gpg --export-secret-keys --armor "${KEY_FP}" > $GIT_INSTALL_DIR/secret-files/sops.asc  # Writes the unencrypted PGP key to a file.
$ gpg --edit-key "${KEY_FP}"  # Protects the PGP private key with two strong passwords (they can be the same):
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

$ mkdir $CLUSTER_DIR
$ gpg --export --armor "${KEY_FP}" > $CLUSTER_DIR/.sops.pub.asc
$ git add $CLUSTER_DIR/.sops.pub.asc  # Stores the PGP public key in the repo.
$ cat <<EOF > $CLUSTER_DIR/.sops.yaml
creation_rules:
  - path_regex: .*.yaml
    encrypted_regex: ^(data|stringData)$
    pgp: ${KEY_FP}
  - pgp: ${KEY_FP}
EOF

$ git add $CLUSTER_DIR/.sops.yaml  # Stores the SOPS configuration file in the repo.
$ git commit -m 'Share the PGP public key for secrets generation'
[master 1c50aeb] Share the PGP public key for secrets generation
 10 files changed, 463 insertions(+)
 create mode 100644 simple-git-server/dev/delete-secret-files.sh
 create mode 100644 simple-git-server/dev/generate-secret-files.sh
 create mode 100644 simple-git-server/dev/kustomization.yaml
 create mode 100644 simple-git-server/dev/manifests.yaml
 create mode 100644 simple-git-server/dev/static/default.conf.template
 create mode 100644 simple-git-server/dev/static/nginx.conf
 create mode 100644 simple-git-server/dev/static/sshd_config
 create mode 100644 simple-git-server/dev/static/trusted_user_ca_keys
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

After these changes to the GitOps repository, your team members will
be able to clone the repository, import the cluster's public PGP key,
and create their local SOPS configuration file.

Like this:

``` console
$ pwd
/home/johndoe/src/swpt-k8s-config

$ gpg --import $CLUSTER_DIR/.sops.pub.asc  # Imports the public PGP key.
gpg: key 9F85AF312DC6F642: "clusters/dev (flux secrets)" not changed
gpg: Total number processed: 1
gpg:              unchanged: 1

$ cp $CLUSTER_DIR/.sops.yaml .  # Creates a local SOPS configuration file.
```

## Back up the cluster's PGP private key (recommended)

It is **strongly recommended** that you create a backup copy of the
cluster's PGP private key. Make sure you do not forget the two
passwords you used to protect the key:

``` console
$ gpg --export-secret-key --armor "${KEY_FP}" > /mnt/backup/sops.private.asc  # Enter the path to the backup file here.
$ cat /mnt/backup/sops.private.asc  # Shows the password-protected backup copy of the PGP private key.
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

## Create subdirectories for your cluster name

The next task -- and this is a big one -- is to create/populate
subdirectories named after your cluster (e.g., `dev`) in the
`clusters/`, `infrastructure/`, and `apps/` directories. In each of
these, you'll find an `example/` subdirectory -- use it as a template.
For instance:

**Note:** At this point the `clusters/$CLUSTER_NAME` directory (aka
`$CLUSTER_DIR`) already exists and contains hidden SOPS configuration
files.

``` console
$ pwd
/home/johndoe/src/swpt-k8s-config

$ cp -r clusters/example/* clusters/$CLUSTER_NAME
$ cp -r infrastructure/example/ infrastructure/$CLUSTER_NAME
$ cp -r apps/example/ apps/$CLUSTER_NAME
```

In these newly created directories, pay close attention to the
comments in the various `.yaml` files, and adapt these files according
to your needs. In several files you will have to change the references
to `clusters/example`, `infrastructure/example`, and `apps/example`,
so that they instead refer to your chosen cluster name. You can use
`sed` to change those references:

``` console
$ pwd
/home/johndoe/src/swpt-k8s-config

$ sed -i "s/clusters\/example/clusters\/$CLUSTER_NAME/g" $CLUSTER_DIR/flux-system/gotk-sync.yaml
$ sed -i "s/infrastructure\/example/infrastructure\/$CLUSTER_NAME/g" $CLUSTER_DIR/infrastructure.yaml
$ sed -i "s/apps\/example/apps\/$CLUSTER_NAME/g" $CLUSTER_DIR/apps.yaml
$ sed -i "s/apps\/example/apps\/$CLUSTER_NAME/g" apps/$CLUSTER_NAME/swpt-nfs-server/kustomization.yaml
```

Also, note that the numerous `secrets/` subdirectories contain fake
encrypted secrets, which you can not use. Instead of trying to use the
fake secrets, you should generate and encrypt your own secrets. The
fake secret files actually contain instructions on how to generate the
real secrets. The same applies to the files `server.crt` and
`server.key.encrypted`. You will find the same instructions on how to
generate those secrets in the comments in the various `.yaml` files.

Another very important directory is the `node-data/` subdirectory
(`apps/dev/swpt-debtors/node-data/`,
`apps/dev/swpt-creditors/node-data/`, and
`apps/dev/swpt-accounts/node-data/`). This subdirectory contains
information about the Swaptacular node and its peers. The `node-data/`
subdirectory starts as an identical copy of the [Swaptacular
certificate authority scripts
repository](https://github.com/swaptacular/swpt_ca_scripts), and
continues evolving from there.

You should always include a copy of the
`apps/example/regcreds.json.encrypted` file, and the
`apps/example/swpt-nfs-server/` directory in your cluster. However,
among the other subdirectories in `apps/example/`, you should preserve
only those which are responsible for running the types of Swaptacular
nodes that you want to run in your Kubernetes cluster:

  * `apps/example/swpt-accounts/` is responsible for running an
    [accounting authority node].
  * `apps/example/swpt-debtors/` is responsible for running a [debtors
    agent node].
  * `apps/example/swpt-creditors/` is responsible for running a
    [creditors agent node].

You can run more than one Swaptacluar node type in the same Kubernetes
cluster. You can even run multiple instances of the same node type,
but in this case you would need to make sure that the name of each
node's subdirectory is unique.

In this example, we will presume that you want to run an accounting
authority node, but if you want to run a different type of node (or
more than one type of node), the only difference would be the names of
the subdirectories that you need to preserve (`swpt-accounts`,
`swpt-debtors`, or `swpt-creditors`):

``` console
$ pwd
/home/johndoe/src/swpt-k8s-config

$ rm -rf apps/$CLUSTER_NAME/swpt-debtors  # Do not run a debtors agent node.
$ rm -rf apps/$CLUSTER_NAME/swpt-creditors  # Do not run a creditors agent node.
```

In production, you also will not need the `mailhog.yaml`,
`minio.yaml`, and `pebble.yaml` files in the `clusters/example/`
directory. They are useful only for testing.

Once you have sorted all this out (Remember, **you must pay close
attention** to the comments in the various `.yaml` files!), commit and
push your changes to the GitOps repository:

``` console
$ pwd
/home/johndoe/src/swpt-k8s-config

$ git add $CLUSTER_DIR infrastructure/$CLUSTER_NAME apps/$CLUSTER_NAME
$ git commit -m "Added cluster directories"
[master fbe45cc] Added cluster directories
 12 files changed, 1157 insertions(+)
 create mode 100644 infrastructure/dev/cert-manager/kustomization.yaml
 create mode 100644 infrastructure/dev/configs/kustomization.yaml
...
...

$ git push origin master  # Pushes the changes to the GitOps repository.
Enumerating objects: 5, done.
Counting objects: 100% (5/5), done.
Delta compression using up to 4 threads
Compressing objects: 100% (3/3), done.
Writing objects: 100% (3/3), 1.06 KiB | 1.06 MiB/s, done.
Total 3 (delta 2), reused 0 (delta 0), pack-reused 0
remote: Resolving deltas: 100% (2/2), completed with 2 local objects.
To github.com:epandurski/swpt-k8s-config.git
   205a82e..fbe45cc  master -> master
```

## Use a private container image registry (optional)

If you want to use a private container image registry (recommended for
production deployments), you will need to prepare an "image pull
secret" file, containing the credentials required to pull images from
your private registry. Here is how to do it:

``` console
$ pwd
/home/johndoe/src/swpt-k8s-config

$ export REGISTRY_NAME=registry.example.com   # Enter enter your image registry name here.
$ export REPOSITORY_NAME=repository  # Enter enter your repository name here.
$ docker login $REGISTRY_NAME
Username: johndoe
Password: <enter you password here>
WARNING! Your password will be stored unencrypted in /home/johndoe/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded

$ cp ~/.docker/config.json $GIT_INSTALL_DIR/secret-files/regcreds.json
$ cat $GIT_INSTALL_DIR/secret-files/regcreds.json  # This file contains the unencrypted "image pull secret". If necessary, you may edit the file.
{
	"auths": {
		"registry.example.com": {
			"auth": "am9obmRvZToxMjMK"
		}
	}
}

$ docker logout $REGISTRY_NAME  # Removes the unencrypted password from ~/.docker/config.json.
$ sops encrypt --input-type binary $GIT_INSTALL_DIR/secret-files/regcreds.json > apps/$CLUSTER_NAME/regcreds.json.encrypted
$ sops encrypt --input-type binary $GIT_INSTALL_DIR/secret-files/regcreds.json > infrastructure/$CLUSTER_NAME/regcreds.json.encrypted
$ git add apps/$CLUSTER_NAME/regcreds.json.encrypted
$ git add infrastructure/$CLUSTER_NAME/regcreds.json.encrypted
$ git commit -m 'Update regcreds'
[master 2f1bd3c] Update regcreds
 2 files changed, 2 insertions(+), 2 deletions(-)
```

You will also need to update the `$GIT_INSTALL_DIR/kustomization.yaml`
file to use your private container image registry for the Git server's
and Nginx's images:

``` console
$ pwd
/home/johndoe/src/swpt-k8s-config

$ cat $GIT_INSTALL_DIR/kustomization.yaml
...
...
images:
- name: rockstorm/git-server
  newName: ghcr.io/swaptacular/git-server
  digest: sha256:77a0476d8e63e32153c3b446c3c2739004558168dd92b83252d9a4aa0b49deaa
- name: nginx
  newName: ghcr.io/swaptacular/nginx
  digest: sha256:65645c7bb6a0661892a8b03b89d0743208a18dd2f3f17a54ef4b76fb8e2f2a10
...
...

$ sed -i "s/ghcr.io\/swaptacular/$REGISTRY_NAME\/$REPOSITORY_NAME/" $GIT_INSTALL_DIR/kustomization.yaml
$ cat $GIT_INSTALL_DIR/kustomization.yaml
...
...
images:
- name: rockstorm/git-server
  newName: registry.example.com/repository/git-server
  digest: sha256:77a0476d8e63e32153c3b446c3c2739004558168dd92b83252d9a4aa0b49deaa
- name: nginx
  newName: registry.example.com/repository/nginx
  digest: sha256:65645c7bb6a0661892a8b03b89d0743208a18dd2f3f17a54ef4b76fb8e2f2a10
...
...

$ git add $GIT_INSTALL_DIR/kustomization.yaml
$ git commit -m 'Edited simple-git-server/dev/kustomization.yaml'
$ git push origin master  # Pushes the updates to the GitOps repository.
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

If you **do not** want to use a private container image registry, you
can skip the previous steps, and start installing the Git server
immediately.

## Install a simple Git server in your Kubernetes cluster

The next step is to install a Git server in your Kubernetes cluster,
which will host a copy of your GitOps repository. This server will
also act as a Nginx reverse proxy for the Grafana, Alertmanager and
Prometheus UIs requests. But before installing the Git server, you
need to do some preparations:

1. In order to be able to authenticate to the Git server you are about
   to install, you need to add the root-CA public key for at least one
   of your Swaptacular nodes to the
   `$GIT_INSTALL_DIR/static/trusted_user_ca_keys` file:

   **Note:** To generate a root-CA public key for you node, you must
   use the scripts in the `node-data/` subdirectory, and [follow these
   instructions ](https://github.com/swaptacular/swpt_ca_scripts). In
   this example, we presume that you have done this already.

   ``` console
   $ pwd
   /home/johndoe/src/swpt-k8s-config

   $ ls -F apps/$CLUSTER_NAME/swpt-accounts/node-data/  # See https://github.com/swaptacular/swpt_ca_scripts
   certs/                generate-serverkey*  private/           root-ca.conf.template
   create-infobundle*    init-ca*             README.md          root-ca.crt
   creditors-subnet.txt  my-infobundle.zip    reconfigure-peer*  sign-peercert*
   db/                   nodeinfo/            register-peer*     sign-servercert*
   generate-masterkey*   peers/               root-ca.conf

   $ export ROOT_CA_CRT_FILE=apps/$CLUSTER_NAME/swpt-accounts/node-data/root-ca.crt  # This is the path to your Swaptacular node's self-signed root-CA certificate.
   $ openssl x509 -in "$ROOT_CA_CRT_FILE" -pubkey -noout > CERT.tmp
   $ ssh-keygen -f CERT.tmp -i -m PKCS8 >> $GIT_INSTALL_DIR/static/trusted_user_ca_keys
   $ rm CERT.tmp
   $ cat $GIT_INSTALL_DIR/static/trusted_user_ca_keys  # Shows the trusted root-CA keys, one key per line.
   ...
   ...
   ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCJfDWvw+LxOW1ECcpoHdFw+ygG4XSeVrB9JFVdIcrrVHqIXDPjvJKXrQ2TadeaTA2i1XUv+XwJr2ZN3OZ6dGLxddPQD4ZG6ciT4iK4TOjAiauE8gQPHR1uzShoK2TGfuYXma2lOnB4s/w5Tif+an5NzHRuDzAwXHPVfVeb9kgIO4A761CztwdTPyEM0jocpoz03Ch4DgYvwf2r+P+1x2Hm5htipNigkhdwtdw5yjUuTR3ylFIeokwcIZomYcGGO66i7EWGYzhr811uApgLJH5YtqeFnD054ia+AbOdCXEr1ZXvpol1Vqo6p/R015zBjMQ8wcdzd+PMSzHvXMLMjG6POhRvQ2yy3cmDpPPIzMHOcNxXhdarVLKDt8/SJlo4O+buAbHdib0pRXpqbPS6rjFwArB93H7TOcY+xl3EGAsjz+1wRPlbi1TN9XNRyQKxLK21QpYql4iYoD8Wac6iWQDDKNaTr88YFUu+MMUfZuQ+0MmXQ1yA/wfqyC9pjm4tkc0=
   ```

2. You need to choose the passwords for accessing the Alertmanager and
   Prometheus UIs (a view-only access):

   **Note**: In the given example, the username for both Alertmanager and
   Prometheus UIs will be `viewer`.

   ``` console
   $ cd $GIT_INSTALL_DIR
   $ pwd
   /home/johndoe/src/swpt-k8s-config/simple-git-server/dev

   $ echo "viewer:$(openssl passwd)" > secret-files/alertmanager_viewers
   Password: <enter your chosen password>
   Verifying - Password: <enter your chosen password again>

   $ cat secret-files/alertmanager_viewers  # Shows Alertmanager's viewers usernames and encrypted passwords, one viewer per line.
   viewer:$1$2gwQXkVy$An9E0C66KIGsgQ/KhPWoD.

   $ echo "viewer:$(openssl passwd)" > secret-files/prometheus_viewers
   Password: <enter your chosen password>
   Verifying - Password: <enter your chosen password again>

   $ cat secret-files/prometheus_viewers  # Shows Prometheus's viewers usernames and encrypted passwords, one viewer per line.
   viewer:$1$2gwQXkVy$An9E0C66KIGsgQ/KhPWoD.
   ```

3. Then, you need to run a simple script which will automatically
   generate some secrets:

   **Note**: You will be prompted to enter information for a
   self-signed SSL certificate. This certificate will be used by the
   Nginx reverse proxy providing access to the Grfana, Alertmanager,
   and Prometheus UIs. You may enter any values you like, including
   pressing “Enter” multiple times to skip fields.

   ``` console
   $ pwd
   /home/johndoe/src/swpt-k8s-config/simple-git-server/dev

   $ ./generate-secret-files.sh
   Generating public/private rsa key pair.
   Your identification has been saved in secret-files/ssh_host_rsa_key
   Your public key has been saved in secret-files/ssh_host_rsa_key.pub
   The key fingerprint is:
   SHA256:V5z4od4LmSBF3MyXsTzPBjt+yYOKLJQqrZS2ULerNyM johndoe@mycomputer
   The key's randomart image is:
   +---[RSA 3072]----+
   |+oo+=o...o=.    =|
   | + oo+o .. + o *o|
   |. . ..+.  E + O +|
   |   .   + o   = *o|
   |      . S + + . =|
   |         o + . + |
   |            o . .|
   |             =   |
   |              o  |
   +----[SHA256]-----+
   ........+...+..+.+..+...+....+.........+..+.......+........++++++++++++
   ...
   ...
   -----
   You are about to be asked to enter information that will be incorporated
   into your certificate request.
   What you are about to enter is what is called a Distinguished Name or a DN.
   There are quite a few fields but you can leave some blank
   For some fields there will be a default value,
   If you enter '.', the field will be left blank.
   -----
   Country Name (2 letter code) [AU]:
   State or Province Name (full name) [Some-State]:
   Locality Name (eg, city) []:
   Organization Name (eg, company) [Internet Widgits Pty Ltd]:
   Organizational Unit Name (eg, section) []:
   Common Name (e.g. server FQDN or YOUR name) []:
   Email Address []:

   ****************************************************************
   * IMPORTANT: Do not forget to run the "delete-secret-files.sh" *
   * script once you have successfully bootstrapped your          *
   * Kubernetes cluster!                                          *
   ****************************************************************
   ```

After completing all the preparations, you can finally install the Git
server in your Kubernetes cluster:

``` console
$ pwd
/home/johndoe/src/swpt-k8s-config/simple-git-server/dev

$ kubectl apply -k .
...
...
namespace/simple-git-server configured
configmap/sshd-config-t9g57f6875 configured
secret/host-keys configured
secret/regcreds configured
service/git-server configured
persistentvolumeclaim/git-repositories configured
deployment.apps/simple-git-server configured

$ kubectl -n simple-git-server get all
NAME                                     READY   STATUS    RESTARTS   AGE
pod/simple-git-server-5d86d687d8-7khj6   2/2     Running   0          24h

NAME                 TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                        AGE
service/git-server   LoadBalancer   10.96.123.249   172.18.0.4    2222:31003/TCP,443:32730/TCP   25h

NAME                                READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/simple-git-server   1/1     1            1           24h

NAME                                           DESIRED   CURRENT   READY   AGE
replicaset.apps/simple-git-server-5d86d687d8   1         1         1       24h
```

The last command displays the public (external) IP address of the load
balancer for the newly installed Git server (`172.18.0.4`, port 2222,
in this example). Later, you will be able to access the Grafana,
Alertmanager and Prometheus UIs at this IP address
(`https://172.18.0.4/` for Grafana, `https://172.18.0.4/alertmanager/`
and `https://172.18.0.4/prometheus/` for Alertmanager and Prometheus
UIs respectively).

You should **save this IP address**, because you will need it soon:

``` console
$ export CLUSTER_EXTERNAL_IP=$(kubectl -n simple-git-server get service git-server -o 'jsonpath={.status.loadBalancer.ingress[0].ip}')
$ echo $CLUSTER_EXTERNAL_IP  # Shows the public IP of the Git server's load balancer.
172.18.0.4
```

## Copy the GitOps repository to the newly installed Git server

To authenticate to the newly installed Git server, you need to issue
an SSH certificate to yourself -- that is, generate a new
`id_rsa-cert.pub` file in your `~/.ssh` directory:

**Note:** When deploying a non-production cluster, you may choose to
simplify your workflow by using an external GitOps server (less
secure) instead of the Git server you have installed on the cluster.
If that's the case, you can skip this step. However, you will need to
update the relevant `kustomiztion.yaml` files (search for
"GIT_SERVER"), and adjust the `flux bootstrap` command accordingly
(see the "Bootstrap FluxCD" section).

``` console
$ pwd
/home/johndoe/src/swpt-k8s-config/simple-git-server/dev

$ export ROOT_CA_PRIVATE_KEY_FILE=../../apps/$CLUSTER_NAME/swpt-accounts/node-data/private/root-ca.key  # This is the path to your Swaptacular node's private key.
$ ls ~/.ssh  # Shows the SSH keys installed on your computer.
id_rsa  id_rsa.pub  known_hosts

$ ssh-keygen -s "$ROOT_CA_PRIVATE_KEY_FILE" -I johndoe -n git ~/.ssh/id_rsa.pub  # Issues a certificate for the "id_rsa.pub" key. Here may substitute "johndoe" with any username.
Enter passphrase: <Enter your passphrase here>
Signed user key /home/johndoe/.ssh/id_rsa-cert.pub: id "johndoe" serial 0 for git valid forever

$ ls ~/.ssh
id_rsa  id_rsa.pub  id_rsa-cert.pub  known_hosts
```

Then, you need to connect to the Git server, create a new
`/srv/git/fluxcd.git` repository, and copy the entire contents of the
GitOps repo into it:

``` console
$ pwd
/home/johndoe/src/swpt-k8s-config/simple-git-server/dev

$ ssh git@$CLUSTER_EXTERNAL_IP -p 2222  # Creates an empty repository:
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
Connection to 172.18.0.4 closed.

$ git remote add k8s-repo ssh://git@$CLUSTER_EXTERNAL_IP:2222/srv/git/fluxcd.git
$ git push k8s-repo master  # Copies the GitOps repo to the just created empty repository.
Enumerating objects: 81, done.
Counting objects: 100% (81/81), done.
Delta compression using up to 4 threads
Compressing objects: 100% (79/79), done.
Writing objects: 100% (79/79), 25.67 KiB | 1.97 MiB/s, done.
Total 79 (delta 51), reused 0 (delta 0), pack-reused 0
To ssh://172.18.0.4:2222/srv/git/fluxcd.git
   59b1758..b019dfe  master -> master
```

## Bootstrap FluxCD

The next step is to bootstrap [FluxCD] from the Git server installed
in your Kubernetes cluster.

If you want to use a private container image registry for the FluxCD
images, you will need to specify your private registry using the
`--registry` option of the `flux bootstrap` command (instead of
"ghcr.io/swaptacular"), and also add the following options:

1. Provide the username and the password for your private registry
   with the `--registry-creds username:password` option.

2. Specify the name of the image pull secret that FluxCD will create,
   with the `--image-pull-secret regcreds` option. The name *must be*
   "regcreds".

``` console
$ pwd
/home/johndoe/src/swpt-k8s-config/simple-git-server/dev

$ sudo sh -c "sed -i '/git-server.simple-git-server.svc.cluster.local/d' /etc/hosts"
$ sudo sh -c "echo $CLUSTER_EXTERNAL_IP git-server.simple-git-server.svc.cluster.local >> /etc/hosts"
$ cat /etc/hosts  # Shows that the internal name of the Git-server has been added to your hosts file.
...
...
127.0.0.1 localhost
172.18.0.4 git-server.simple-git-server.svc.cluster.local

$ flux bootstrap git --url=ssh://git@git-server.simple-git-server.svc.cluster.local:2222/srv/git/fluxcd.git --branch=master --private-key-file=secret-files/ssh_host_rsa_key --path=$CLUSTER_DIR --version v2.6.4 --registry ghcr.io/swaptacular
...
...
Configuring the cluster to synchronize with the repository
Flux controllers installed and configured successfully

$ kubectl create secret generic sops-gpg --namespace=flux-system --from-file=sops.asc=secret-files/sops.asc  # Creates a Kubernetes secret containing the PGP private key.
secret/sops-gpg created

$ git pull k8s-repo master  # Checks for possible changes in the repo, made during the bootstrapping.
remote: Enumerating objects: 11, done.
remote: Counting objects: 100% (11/11), done.
remote: Compressing objects: 100% (6/6), done.
remote: Total 6 (delta 3), reused 1 (delta 0), pack-reused 0 (from 0)
Unpacking objects: 100% (6/6), 572 bytes | 572.00 KiB/s, done.
From ssh://172.18.0.4:2222/srv/git/fluxcd
 * branch            master     -> FETCH_HEAD
   f3348c8..01df4b9  master     -> k8s-repo/master
Updating f3348c8..01df4b9
Fast-forward
 clusters/dev/flux-system/gotk-sync.yaml | 2 ++
 1 file changed, 2 insertions(+)
```

## Wait for the cluster to start the pods

After FluxCD has been bootstrapped, starting the pods will take some
time. You can use `kubectl` to monitor the process. To check for any
issues during FluxCD's reconciliation, you may run the following
command:

``` console
$ flux get all -A --status-selector ready=false
NAMESPACE	NAME	REVISION	SUSPENDED	READY	MESSAGE

NAMESPACE	NAME	REVISION	SUSPENDED	READY	MESSAGE

NAMESPACE	NAME	REVISION	SUSPENDED	READY	MESSAGE

NAMESPACE  	NAME                           	REVISION            	SUSPENDED	READY
flux-system	kustomization/apps             	master@sha1:96334c96	False    	False	dependency 'flux-system/infra-configs' is not ready
flux-system	kustomization/infra-configs    	master@sha1:96334c96	False    	False	dependency 'flux-system/infra-controllers' revision is not up to date
flux-system	kustomization/infra-controllers	master@sha1:96334c96	False    	False	dependency 'flux-system/infra-cert-manager' revision is not up to date
```

## Configure your DNS records

Once your cluster is up and running, you will need to set your DNS
records, so that they point to the proper load balancer(s) in your
cluster.

Each Swaptacular node which you run in your cluster will have its own
load balancer, with a unique external IP address. To obtain the load
balancer's external IP address, you may use `kubectl`:

``` console
$ kubectl -n swpt-accounts get services
NAME                                               TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                                     AGE
apiproxy                                           ClusterIP      10.96.57.222    <none>        80/TCP                                      21h
broker                                             ClusterIP      10.96.10.19     <none>        15692/TCP,5672/TCP,15672/TCP                21h
broker-nodes                                       ClusterIP      None            <none>        4369/TCP,25672/TCP                          21h
db                                                 ClusterIP      10.96.157.204   <none>        5432/TCP                                    21h
db-config                                          ClusterIP      None            <none>        <none>                                      21h
db-repl                                            ClusterIP      10.96.176.132   <none>        5432/TCP                                    21h
http-cache                                         ClusterIP      10.96.27.123    <none>        80/TCP                                      21h
stomp-server                                       ClusterIP      10.96.165.250   <none>        1234/TCP                                    21h
swpt-accounts-ingress-nginx-controller             LoadBalancer   10.96.171.44    172.18.0.9    80:31318/TCP,443:32170/TCP,1234:31637/TCP   21h
swpt-accounts-ingress-nginx-controller-admission   ClusterIP      10.96.223.9     <none>        443/TCP                                     21h
swpt-accounts-ingress-nginx-controller-metrics     ClusterIP      10.96.183.76    <none>        10254/TCP                                   21h
web-server                                         ClusterIP      10.96.103.250   <none>        80/TCP                                      21h
```

In this example, the external IP address of `swpt-accounts`'s load
balancer is `172.18.0.9`.

## Delete your PGP private key (optional)

If you do not plan to use SOPS **to decrypt secrets** on this machine,
consider deleting the PGP private key from the machine. If you need it
later, you can always import the decryption key from your backup copy:

``` console
$ gpg --delete-secret-keys "${KEY_FP}"  # Deletes the private key.
gpg (GnuPG) 2.2.40; Copyright (C) 2022 g10 Code GmbH
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.


sec  rsa4096/6225432F3481C8E0 2025-02-05 Swaptacular clusters/dev (flux secrets)

Delete this key from the keyring? (y/N)
This is a secret key! - really delete? (y/N) y

$ gpg --import /mnt/backup/sops.private.asc  # Imports the private key from your backup copy.
gpg: key 6225432F3481C8E0: "Swaptacular clusters/dev (flux secrets)" not changed
gpg: key 6225432F3481C8E0: secret key imported
gpg: Total number processed: 1
gpg:              unchanged: 1
gpg:       secret keys read: 1
gpg:  secret keys unchanged: 1
```

## Delete the unencrypted secrets from your machine (recommended)

Once you have successfully bootstrapped your Kubernetes cluster, it is
**strongly recommended** that you delete the unencrypted secrets from
the `$GIT_INSTALL_DIR/secret-files` directory on your machine. To do
so, run the following command:

``` console
$ pwd
/home/johndoe/src/swpt-k8s-config/simple-git-server/dev

$ ./delete-secret-files.sh  # The secrets have already been copied to the cluster.
```

## Making changes to your GitOps repository

Each time you commit changes to your GitOps repository -- for example,
when you add a new peer to your Swaptacular node -- you need to push
those changes to the Git server in your Kubernetes cluster. For
instance:

``` console
$ cd ../..
$ pwd
/home/johndoe/src/swpt-k8s-config

$ echo "This README file has been improved!" >> README.md
$ git status
On branch master
Your branch is up to date with 'k8s-repo/master'.

Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
	modified:   README.md

$ git add README.md
$ git commit -m 'Improve the README'
[master 65eef4a] Improve the README
 1 file changed, 22 insertions(+), 1 deletion(-)

$ git push origin master  # Pushes the changes to the GitOps repository.
Enumerating objects: 5, done.
Counting objects: 100% (5/5), done.
Delta compression using up to 4 threads
Compressing objects: 100% (3/3), done.
Writing objects: 100% (3/3), 1.22 KiB | 627.00 KiB/s, done.
Total 3 (delta 2), reused 0 (delta 0), pack-reused 0
remote: Resolving deltas: 100% (2/2), completed with 2 local objects.
To github.com:epandurski/swpt-k8s-config.git
   dd30b11..65eef4a  master -> master

$ git push k8s-repo master  # Pushes the changes to the Git server in your Kubernetes cluster.
Enumerating objects: 5, done.
Counting objects: 100% (5/5), done.
Delta compression using up to 4 threads
Compressing objects: 100% (3/3), done.
Writing objects: 100% (3/3), 1.22 KiB | 1.22 MiB/s, done.
Total 3 (delta 2), reused 0 (delta 0), pack-reused 0
To ssh://git-server.simple-git-server.svc.cluster.local:2222/srv/git/fluxcd.git
   dd30b11..65eef4a  master -> master
```

FluxCD will periodically check for changes in the repository hosted on
the Git server in your Kubernetes cluster and reconcile the state of
the cluster.

## Scaling up

As the number of users grow, you may need to increase the number of
running deployment replicas, processes, and threads of the various
components, by editing the relevant `kustomization.yaml`,
`broker.yaml`, `postgres-cluster.yaml`, and `dragonfly-db.yaml` files.
While increasing replicas, processes, or threads can help with compute
scalability, eventually the database itself becomes a bottleneck,
necessitating horizontal scaling through sharding.

Each database shard is responsible for some portion of all existing
database records. At the beginning, there is only one database shard
(named `shard` in general, or "worker" in the trade app), which is
responsible for all database records. To increase the number of shards
to two, you need to split the existing shard into two child shards.
The new shards will have the names `shard-0` and `shard-1`, and each
will be responsible for half of the records previously belonging to
the parent shard. (That is: `shard-0` will be responsible for the
records whose MD5-hash's first bit is 0, and `shard-1` will be
responsible for the records whose MD5-hash's first bit is 1.) When
those children shards are again close to becoming overloaded, you can
again split each of them into two, resulting in four shards in total
(`shard-00`, `shard-01`, `shard-10`, and `shard-11`). You can continue
scaling by recursively splitting existing shards as needed.

The process of shard splitting is completely automated, but must be
triggered manually. To trigger a shard split, navigate to the `shards`
subdirectory of your GitOps repository (or for the trade app, the
"trade/workers" subdirectory), and execute the `split-shard` script as
shown below:

``` console
$ cd apps/$CLUSTER_NAME/swpt-accounts/shards
$ pwd
/home/johndoe/src/swpt-k8s-config/apps/dev/swpt-accounts/shards
$ ls -F
kustomization.yaml  shard/  split-shard*

$ ./split-shard shard
...
...
"shard" has been prepared for splitting.
Use "git status" to verify the prepared changes.

$ git status
On branch master
Your branch is up to date with 'k8s-repo/master'.

Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
	modified:   kustomization.yaml
	modified:   shard/kustomization.yaml
	modified:   shard/postgres-cluster.yaml

Untracked files:
  (use "git add <file>..." to include in what will be committed)
	shard-0/
	shard-1/
	shard/kustomization.unsplit

no changes added to commit (use "git add" and/or "git commit -a")

$ git add -A
$ git commit -m "Trigger split of swpt-accounts/shards/shard"
[split 80703f6] Trigger split of swpt-accounts/shards/shard
 8 files changed, 806 insertions(+)
 create mode 100644 apps/example/swpt-accounts/shards/shard-0/kustomization.yaml
 create mode 100644 apps/example/swpt-accounts/shards/shard-0/postgres-cluster.yaml
 create mode 100644 apps/example/swpt-accounts/shards/shard-1/kustomization.yaml
 create mode 100644 apps/example/swpt-accounts/shards/shard-1/postgres-cluster.yaml
 create mode 100644 apps/example/swpt-accounts/shards/shard/kustomization.unsplit

$ git push k8s-repo master
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

**Note:** If you try to split a shard which itself have been recently
split, and still contains records from its parent shard, the splitting
procedure will need to wait until all those records have been garbage
collected. The time needed for this to happen depends on the garbage
collecting settings. With the default settings it should take a week
or two.

## Scaling up Ory Hydra

Another database that may eventually need to be split into shards is
the one used by [Ory Hydra]. Currently, in the name of simplicity, it
uses a standard [PostgreSQL] database. However, because losing the
data in this database **would not** be catastrophic, and since Ory
Hydra supports databases specifically designed to scale, you could
relatively easily switch to [CockroachDB], [YugabyteDB], or [Citus].


[Swaptacular nodes]: https://swaptacular.github.io/overview
[Kubernetes]: https://kubernetes.io/
[GitOps]: https://www.redhat.com/en/topics/devops/what-is-gitops
[KinD]: https://kind.sigs.k8s.io/
[Amazon S3]: https://en.wikipedia.org/wiki/Amazon_S3
[SMTP server]: https://en.wikipedia.org/wiki/Simple_Mail_Transfer_Protocol
[OCI image repository]: https://opencontainers.org/
[CAPTCHA]: https://en.wikipedia.org/wiki/CAPTCHA
[hCaptcha]: https://www.hcaptcha.com/
[SOPS]: https://github.com/getsops/sops
[GnuPG]: https://www.gnupg.org/
[FluxCD]: https://fluxcd.io/
[Ory Hydra]: https://www.ory.sh/hydra
[PostgreSQL]: https://www.postgresql.org/
[CockroachDB]: https://www.cockroachlabs.com/
[YugabyteDB]: https://www.yugabyte.com/
[Citus]: https://www.citusdata.com/
[accounting authority node]: https://github.com/swaptacular/swpt_accounts
[debtors agent node]: https://github.com/swaptacular/swpt_debtors
[creditors agent node]: https://github.com/swaptacular/swpt_creditors
