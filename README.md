# qualisys_docker
Docker setup for the mocap4ros2_qualisys ROS 2 driver, used to stream and record motion capture data from a Qualisys motion capture system on ROS 2 Humble. Provides a ready-to-build Dockerfile, a Docker Compose service, and configurable driver parameters (IP, port, QoS); recorded rosbag2 sessions live in bags/ and are excluded from version control.

## Overview

This repository packages the ROS 2 [mocap4ros2_qualisys](https://github.com/CentroEPiaggio/mocap4ros2_qualisys) driver (CentroEPiaggio fork) into a Docker image so it can be built and run without installing ROS 2 or the driver's dependencies on the host machine.

The driver is pinned to commit `05dcf0b` and patched (`patches/qualisys_driver_streaming.patch`) so that it streams every frame from QTM instead of polling the current frame every 100 ms. With the patch, `/rigid_bodies` and `/markers` are published at the full QTM capture rate (e.g. 200 Hz) instead of 10 Hz.

## Repository structure

```
.
├── Dockerfile                          # Image based on ros:humble-ros-base, clones, patches and builds mocap4ros2_qualisys
├── compose.yaml                        # Docker Compose service to build/run the container
├── entrypoint.sh                       # Sources the ROS 2 environment and workspace before running the command
├── config/
│   └── qualisys_driver_params.yaml     # Node parameters (Qualisys system IP/port, QoS, etc.)
├── patches/
│   └── qualisys_driver_streaming.patch # Full-rate streaming patch for the driver
├── scripts/
│   ├── record_mocap.sh                 # Records a bag with the pose of a single rigid body
│   └── rigid_body_filter.py            # Republishes one rigid body from /rigid_bodies as PoseStamped
└── bags/                               # rosbag2 recordings (excluded from the repository, see .gitignore)
```

## Requirements

- Docker and Docker Compose
- Host network reachable from the Qualisys system (the container uses `network_mode: host`)

## Network setup

The PC must be on the Qualisys LAN with a static IP. With NetworkManager (replace `enp7s0` with your Ethernet interface):

```bash
nmcli con add type ethernet ifname enp7s0 con-name qualisys \
  ipv4.method manual ipv4.addresses 192.168.254.51/24 ipv6.method disabled
nmcli con up qualisys
```

No gateway is set, so Internet traffic keeps going through the other interfaces. The QTM PC may not answer to `ping` (Windows firewall); what matters is that port 22222 is reachable:

```bash
timeout 3 bash -c 'echo > /dev/tcp/192.168.254.1/22222' && echo open
```

## Configuration

Edit `config/qualisys_driver_params.yaml` to set the IP address (`host_name`) and port (`port`) of the Qualisys server, along with the node's QoS parameters. The file is mounted into the container, so changes only need a driver restart, not a rebuild.

In QTM, the robot must be defined as a 6DOF body and real-time streaming must be enabled. The rigid body names published by the driver are the 6DOF body names in QTM (case-sensitive).

## Build and run

```bash
docker compose build
docker compose up -d
docker compose exec qualisys bash
```

Inside the container, the ROS 2 (`humble`) environment and the `mocap_ws` workspace are sourced automatically. The container uses the host timezone (`/etc/localtime` is mounted).

Start the driver:

```bash
ros2 launch qualisys_driver qualisys.launch.py
```

Published topics:

- `/rigid_bodies` (`mocap_msgs/RigidBodies`): name and pose of every 6DOF body
- `/markers` (`mocap_msgs/Markers`): unlabeled 3D markers

Positions are in meters in the QTM global frame (`frame_id: map`). Note that the driver only publishes when a topic has at least one subscriber, and `header.stamp` is the time the frame is received by the PC.

## Recording a rigid body

In a second shell in the container:

```bash
~/scripts/record_mocap.sh <experiment_name> [rigid_body]   # rigid_body defaults to traquad
```

The script checks that the driver is running, republishes the selected rigid body on `/<rigid_body>/pose` (`geometry_msgs/PoseStamped`, same timestamp as the driver), waits for the first message and records it to `~/bags/<experiment_name>_<YYYYMMDD_HHMMSS>`. Stop the recording with Ctrl+C.

## Clock synchronization

If the mocap bag has to be aligned with data recorded on another PC (e.g. robot states), the two clocks must be synchronized, for example with [chrony](https://chrony-project.org/) on both hosts (not in the container: with `network_mode: host` the container uses the host clock). One PC acts as server, the other as client, over any network both can reach (Wi-Fi works, with ~1–5 ms accuracy).

Server (`/etc/chrony/chrony.conf`):

```
local stratum 10
allow 192.168.1.0/24        # subnet shared by the two PCs
```

Client:

```
server <SERVER_IP> iburst minpoll 0 maxpoll 2
makestep 0.1 3
```

On Wi-Fi, disable power saving (`sudo iw dev <wifi_interface> set power_save off`) and check the offset with `chronyc tracking` before recording. A sharp robot motion at the start of each recording helps to verify the alignment afterwards.

## The `bags/` folder

The `bags/` folder is mounted into the container at `/home/ros/bags` and is meant to hold `ros2 bag record` recordings from acquisition sessions. Its contents are **not tracked in git** (see `.gitignore`) since they consist of large, locally generated binary data.
