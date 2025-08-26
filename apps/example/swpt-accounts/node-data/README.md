# Scripts for managing Swaptacular certificate authorities

This repository contains shell scripts that Swaptacular network nodes
can use to maintain a trusted certificate authority (*root-CA*). The
way this works [is explained
here](http://swaptacular.github.io/2023/04/26/under-the-hood-peer-connections/).
The scripts should work on any contemporary GNU system, on which
`bash` is installed, along with `openssl`, `zip`, `unzip`, `envsubst`,
and `hexdump`.

## Creating the root-CA database

To create your root-CA, first you need to generate a private key for it. To
do this, use the `generate-masterkey` script:

```shell
$ ./generate-masterkey
```

This will create a `private/` sub-directory which will contain your root-CA
private key, encrypted with a password that you will be asked to enter.
**You should keep the content of the private/ sub-directory secret**. The
content of any other files and sub-directories, that are automatically
created by the scripts, is not a secret, and can even be made publicly
available.

Once you have successfully generated a private key, use the `init-ca`
command to create the root-CA database:

```shell
$ ./init-ca
```

You will be asked a bunch of questions, and you will have to enter the
password for your private key a few times. At the end, a self-signed
certificate will be generated for your certificate authority. Also, a bunch
of sub-directories will be created. For example, after running the `init-ca`
command, your script directory will contain something similar to this:

``` shell
$ ls -F
certs/               init-ca*   README.md              sign-peercert*
create-infobundle*   LICENSE    register-peer*         sign-servercert*
db/                  nodeinfo/  root-ca.conf
generate-masterkey*  peers/     root-ca.conf.template
generate-serverkey*  private/   root-ca.crt
```

* `root-ca.conf` contains configuration parameters for the OpenSSL library.
* `root-ca.conf.template` contains a template for the "root-ca.conf" file.
  This template file will be used only during the initial creation of the
  root-CA database.
* `root-ca.crt` contains the self-signed certificate for your root-CA. This
  file should be copied to the servers of your Swaptacular node, to be used
  as a trusted root CA during the SSL authentication phase.
* `certs/` will contain the certificates that have been signed by your
  root-CA.
* `db/` will contain all sorts of bookkeeping information about your
  root-CA.
* `nodeinfo/` will contain information about your Swaptacular node. You can
  add random files to this directory, and your peers will store all those
  files in their root-CA databases. Most importantly, the information that
  you put here, should allow your peers to get in touch with you, if
  necessary.
* `peers/` will contain information about your peers, including the content
  of their "nodeinfo" directories.

**Note:** For *creditors agent nodes*, a `creditors-subnet.txt` file will
also be created, indicating the range of creditor IDs that the node is
responsible for. For *debtors agent nodes*, after registering a peer, a
`debtors-subnet.txt` file will be created, indicating the range of debtor
IDs that the node is responsible for.

As you may have guessed, **the information contained in these files and
directories is very important** for the proper functioning of your
Swaptacular node. Therefore, it is probably a good idea to use a version
control system (like `git`), and each time you register a new peer, or make
other important changes, to commit those changes to your version control
servers.

## Creating an info-bundle file

Every Swaptacular network node should create an *info-bundle* file for
itself. Info-bundle files are `.zip` archives that contain 4 files:

1. `root-ca.crt` — the self-signed certificate for the node's root-CA.
2. `root-ca.csr` — a certificate signing request.
3. `nodeinfo.zip` — the content of the node's "nodeinfo" directory.
4. `nodeinfo.signature` — a digital signature for the "nodeinfo.zip" file.

To create an info-bundle file for your node, use the `create-infobundle`
command, specifying the path to the file that you want to be created (in
this example, "~/my-foo-node.zip"):

```shell
$ ./create-infobundle ~/my-foo-node.zip  # You can omit the ".zip" extension.
```

You will be asked to enter the password for your private key at least once.
At the end, an info-bundle file will be created for you, at the specified
path (in this example: `~/my-foo-node.zip`).

You can run the `create-infobundle` command many times, creating as many
info-bundle files as you want. Normally, whenever you make changes to your
"nodeinfo" directory, you will need to generate a new, updated info-bundle
file. It is probably a good idea, to have your latest info-bundle file under
version control.

## Signing a server certificate

Server certificates are used by your servers, so that they can prove their
identity before your peers. Installing a server certificate includes 3
steps:

1. First you need to generate a public/private key pair for your server,
   along with a corresponding certificate signing request file. For maximum
   security, it is best to perform this step directly on the server, so that
   the private key never "leaves" the server on which it has been generated.

   To do this, you may use the `generate-serverkey` command, specifying the
   path to the public/private key pair file that should be created, followed
   by the path to the certificate signing request file that should be
   created:

   ```shell
   $ ./generate-serverkey ~/myserver.key ~/myserver.csr
   ```

   An **unencrypted** public/private key pair file, and a certificate
   signing request file will be created for you. In this example, those
   would be `~/myserver.key` and `~/myserver.csr`.

   Note that in order to be able to run "generate-serverkey" directly on the
   server, you will have to copy to the server the `root-ca.conf` file as
   well.

2. Then you use the certificate signing request generated in step 1, and
   your root-CA private key, to sign the server certificate. To do this, run
   the `sign-servercert` command, specifying the path to the certificate
   signing request file, followed by the path to the server certificate file
   that should be created:

   ```shell
   $ ./sign-servercert ~/myserver.csr ~/myserver.crt
   ```

   You will be asked to enter the password for your root-CA private key. At
   the end, a server certificate file will be created. In this example, this
   would be `~/myserver.crt`.

3. After this, the server certificate file created in step 2 should be
   copied to the server, so that it can be used for authentication.

## Signing a peer certificate

You should sign and give a peer certificate to each one of your peers, so
that they can prove their identity before your servers.

To sign a peer certificate, first you will need to obtain the latest
*info-bundle* file for the Swaptacular node that is about to become your
peer. You can obtain this file directly from the owner of the node, or
indirectly through a third party. Obtaining the info-bundle file through a
third party is perfectly safe, because every file in the info-bundle is
digitally signed.

Once you have obtained the correct info-bundle file, run the `sign-peercert`
command, specifying the path to the file:

```shell
$ ./sign-peercert ~/other-swaptacular-node.zip
```

You will be asked to enter the password for your private key. At the end, a
signed peer certificate file will be created. The file will be located in a
sub-directory of the `peers` directory. A message like this will be appear,
to inform you what to do next:

```
***********************************************************************
* IMPORTANT: A peer certificate file has been created. You should     *
*            send this file to the owner of the Swaptacular node that *
*            made the certificate signing request.                    *
*                                                                     *
*            Also, do not forget to send your own info-bundle file    *
*            as well (see the "create-infobundle" command), so that   *
*            you too, could receive a peer certificate from your      *
*            peer node.                                               *
***********************************************************************
File location: /some-path/peers/fd75076e66e6bd5f8b7dee0e03bd51a0/peercert.crt
```

You can run the "sign-peercert"` command for an already established peer as
well. In this case it will not create a new certificate file, but if a newer
version of the peer's info-bundle file has been supplied, the peer's
"nodeinfo" directory will be updated.

**Important note:** Before signing a peer certificate to an *accounting
authority node*, it is highly recommended to take the time to verify that
the `serialNumber` stated in the certificate's "Subject", is indeed reserved
for the owner of the subject's public key. This can be done by consulting a
centralized registry of accounting authority nodes.

## Registering a peer

To finalize the process of registering a new peer, you need to receive a
signed peer certificate from the peer. In addition, if you have not yourself
signed a peer certificate for this peer already, in order to do this, you
will need to receive an *info-bundle* file as well.

**After you have signed a peer certificate for the peer**, run the
`register-peer` command, specifying the path to the peer certificate file
that you *received* (in this example: "~/received-peercert.crt"):

```shell
$ ./register-peer ~/received-peercert.crt
```

If everything is OK, a message like this will be appear, to inform you what
to do next:

```
***********************************************************************
* IMPORTANT: The peer certificate file has been verified and stored.  *
*                                                                     *
*            You should use this peer certificate as an intermediary  *
*            certificate, together with your server's (leaf)          *
*            certificate, to establish authenticated SSL connections  *
*            with the peer node. See the "sign-servercert" command.   *
***********************************************************************
File location: /some-path/peers/fd75076e66e6bd5f8b7dee0e03bd51a0/sub-ca.crt
```

At this point, the referred "peers" sub-directory (in this example:
`/some-path/peers/fd75076e66e6bd5f8b7dee0e03bd51a0/`), contains all the
necessary information for your servers to accept and initiate authenticated
SSL connections from and to your peer. For example, the sub-directory may
contain something similar to this:

```shell
$ ls -F /some-path/peers/fd75076e66e6bd5f8b7dee0e03bd51a0
nodeinfo/     peercert.crt  queues.txt   sub-ca.crt
nodetype.txt  root-ca.crt   subnet.txt
```

* `nodeinfo/` contains information about the peer's node.
* `peercert.crt` contains the peer certificate that you signed.
* `queues.txt` contains the number of sending queues.
* `sub-ca.crt` contains the peer certificate that the peer signed for
  you.
* `nodetype.txt` indicates the type the peer's node.
* `root-ca.crt` contains the self-signed certificate for the peer's
  root-CA.
* `subnet.txt` (or `masq-subnet.txt`) contains information about the
  range of debtor/creditor IDs that are allocated to/by the peer.
* `DEACTIVATED` if this file exists, this indicates that the peer has
  been deactivated. The file contains the deactivation date.

**Important note:** If you have not deleted the
`peers/create-peer-manifest` file (which is optional), a bunch of YAML
files will also be automatically created in the peer's sub-directory.
These are [Kustomize](http://kustomize.io) files for Kubernetes
deployments. Also, the new peer will be added to the
`peers/kustomization.yaml` peers aggregator file, which will be
automatically created if it does not exist already.

## Reconfiguring a registered peer

To increase the number of sending queues for a registered peer (the
default is `1`), you can use the "reconfigure-peer" command. For
example, for the peer that we registered in the previous section,
running:

```shell
$ ./reconfigure-peer fd75076e66e6bd5f8b7dee0e03bd51a0 3
```

would increase the number of sending queues for that peer to `3`. Note
that you are not allowed to decrease this number.

If you want to deactivate this peer, you can run:

```shell
$ ./reconfigure-peer fd75076e66e6bd5f8b7dee0e03bd51a0 --deactivate
```

**Important note:** Once a peer has been deactivated, it can not be
re-activated again.
