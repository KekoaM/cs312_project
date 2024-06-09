---
title: Course Project Part 1
author: |
  | Kai Morita-McVey
  | moritamk@oregonstate.edu
date: \today
geometry: "left=1cm,right=1cm,top=2cm,bottom=2cm"
---

## EC2 instance setup

This portion assumes that the user has an AWS account with sufficient IAM policies to support VPC and EC2 instance creation and management.

All AWS steps should be performed in the same region (e.g. `us-west-2`).

The AWS portion of this guide will cover:

1. Creating a VPC
2. Creating an EC2 instance

### VPC Creation

On the AWS dashboard, create a new VPC using the GUI. It will automatically determine your Availability Zone based on the selected AWS Region.

1. Choose "VPC and more"
2. Set a value for "Name tag auto-generation"
3. Choose an IPv4 CIDR block (the default is fine)
4. Select "Amazon-provided IPv6 CIDR block"
5. Choose a tenancy (default is fine)
6. Select 1 AZ (We are not setting up replication or failover)
7. Select 1 public subnet
8. Select 0 private subnets
9. Select "None" for NAT gateways
10. Select "No" for Egress only internet gateway
11. Select "None" for VPC endpoints
12. Check both DNS options
13. Click "Create VPC"

### EC2 Creation

On the AWS dashboard, navigate to the EC2 Dashboard and select "Launch instance".

1. Set a name for the instance
2. Select Redhat Enterprise Linux 9 (HVM) as your AMI, and set the Architecture to Arm. (RHEL is more expensive per hour than alternatives such as Rocky Linux, however the AWS Learner Lab does not allow for "Marketplace AMIs" such as Rocky. A normal AWS account could use Rocky here and the rest of the steps would be identical).
3. Choose an instance type. This will vary based on expected usage of the server. Minecraft is heavily single-threaded and generally does well with 2-10GB of RAM. We also can utilize an Arm image for the server, allowing us to choose a "t4g" family instance type. A `t4g.medium` is a good choice.
4. Either select an existing key pair or create a new one. When creating a new key pair use `ed25519`.
5. Select "Edit" under network settings
    1. Under VPC, select the VPC that was created in [VPC Creation](#VPC-Creation).
    2. Use the default subnet selection (there should only be 1)
    3. Enable "Auto-assign public IP"
    4. Enable "Auto-assign IPv6 IP"
    5. Select "Create security group" under Firewall
        1. Create a descriptive security group name
        2. Fill in the description (e.g. "Security group for Minecraft EC2 instance" ).
        3. Leave the default ssh inbound rule (Allow ssh from anywhere).
        4. Select "Add security group rule"
            - Type: "Custom TCP"
            - Port range: "25565" (this is the default Minecraft port)
            - Source type: "Anywhere"
6. In "Configure storage", select root volume size and type.
  Minimally, use 25GiB (but more can be useful) with the type "gp2" or "gp3.
7. Select "Launch Instance"

### Instance configuration

Connect to your instance via the public IP address listed on the instance page, or via the Public IPv4 DNS listed. This is done vis SSH as follows:

```
ssh ec2-user@<IPv4 address>
```

Set the timezone by choosing a TZ from the output of `timedatectl list-timezones`, then running `sudo timedatectl set-timezone <your timezone>`.
Run updates with `sudo dnf update`.

#### Hardening

The first step is to (at least slightly) harden the instance.

##### SELinux

By default, RHEL 9 will ship with [Selinux](https://en.wikipedia.org/wiki/Security-Enhanced_Linux) in `Enforcing` mode. To validate this run `getenforce`. To set SELinux to enforcing if it is not already, edit the `/etc/selinux/config` file and change `SELINUX=permissive` to `SELINUX=enforcing`. Now reboot the machine with `sudo reboot`

##### SSH access

Edit `/etc/ssh/sshd_config`. Find the line with `#PermitRootLogin prohibit-password` and change it to `PermitRootLogin no` (be mindful that we are removing the leading `#`). This disables ssh connections using the `root` user.

Also ensure that `PasswordAuthentication no` is set.

Write your changes to the file and reload `sshd` via `sudo systemctl restart sshd`

##### Automatic security updates (Optional)

To enable automatic security package updates using [DNF Automatic](https://dnf.readthedocs.io/en/latest/automatic.html), do the following:

First run `sudo dnf install dnf-automatic`. Then edit '/etc/dnf/automatic.conf'. In this file, set the `upgrade-type` to `security`.
The default behavior we are about to enable installs updates daily at 6AM (with variance of +- 1 hour), if you want to change this, you can create an override on the timer file by running `sudo systemctl edit dnf-automatic-install.timer`. See [here](https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html) for info on how timers work.

Finally, run `sudo systemctl enable --now dnf-automatic-install.timer`.

### User creation

We now want to create a non-root user to run Minecraft (and any other services we may want later on).

To do this, as `ec2-user` we will run `sudo useradd -m minecraft` to make a new user `minecraft`.
We can now switch to this user with `sudo su - minecraft`. From here, we are the `minecraft` user. To make logging in easier, we will add our SSH pubkey to `/home/minecraft/.ssh/authorized_keys` (you will have to create the folder and file).

Once you have added your public key, the file should look similar to:
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGJR9c8TxmqMwUkXlbZ9j2t30B2KyyanJ0jDCEuufE16
```
Run `chmod 600 /home/minecraft/.ssh/authorized_keys`

Now, from a new terminal on our computer we should be able to ssh into the box with `ssh minecraft@<public ip>`.

Finally, we want to enable linger for this user as we will have processes running under it when there is not a login session for the user.

This is done by running `sudo loginctl enable-linger minecraft` as the `ec2-user`.


## Minecraft deployment

First, we need to install `podman` to run our container(s).

As the `ec2-user`, run `sudo dnf install podman` run `podman -v` and ensure the version is >= 4.6. If not, install from source.

Unless specified, all steps under this will be done as the `minecraft` user. As such, you should use an ssh connection logged in as that user.

The Minecraft server will be using the '[minecraft-server](https://docker-minecraft-server.readthedocs.io/en/latest/)' container image. This allows for easier deployment and management.

### Quadlets

To run the container, we will utilize a [Podman Quadlet](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html). To create this, first make the `/home/minecraft/.config/containers/systemd` directory. This directory will hold the Quadlet files we will create.


#### Volume

We will create a Volume unit that will store the persistent state from our container. To do this we will create the file `/home/minecraft/.config/containers/systemd/minecraft.volume` with the following contents:

```
[Volume]

```

This will create a default volume that we can reference later.

#### Minecraft Server Unit


To the same directory, add `minecraft.container`:
```
[Unit]
Description=Minecraft container
After=network.target

[Container]
Image=docker.io/itzg/minecraft-server:stable
ContainerName=minecraft
Environment=EULA=TRUE
Environment=MAX_MEMORY=3G
Environment=TZ=America/Los_Angele
Volume=minecraft.volume:/data:z
PublishPort=25565:25565

[Service]
Restart=always
TimeoutStartSec=900

[Install]
WantedBy=multi-user.target
```

All we need to do now is run `systemctl --user daemon-reload` to generate the Systemd unit files from these Quadlets as well as `systemctl --user start minecraft`.

This will create a Systemd unit file that will run after the system reaches the `multi-user` target (only after the `network` target has been reached to ensure network access). The container that is ran will use the volume we created earlier as the `minecraft.volume` file will ensure that that Podman volume exists.

We can see the logs from the server by running `podman logs minecraft`. Once the server has finished loading (look at the logs), you can connect to the server at `<your public ip>:25565`.

### Modded Minecraft

Running modded is supported via the current container image. To make the process easier we can use a [modrinth](www.modrinth.com) modpack. For this tutorial I will use [Simply Optimized](https://modrinth.com/modpack/sop).

We can modify the original server by editing the `minecraft.container` file from [Minecraft Server Unit](#Minecraft-Server-Unit). In the "Technical Information" section there is a Project ID that we will need later.

All we need to do is set another environment variable by adding the following to the `[Container]` section:

```
Environment=MOD_PLATFORM=MODRINTH
Environment=MODRINTH_MODPACK=https://modrinth.com/modpack/sop/version/7NypPfsi
```

Now run `systemctl --user daemon-reload` to generate the Systemd unit files from these Quadlets as well as `systemctl --user restart minecraft`.


## Further work

As this is intended to be "quick and dirty", there has been no effort put into backups, bot protection, or real security.

