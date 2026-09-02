# qualisys_docker
Docker setup for the mocap4ros2_qualisys ROS 2 driver, used to stream and record motion capture data from a Qualisys motion capture system on ROS 2 Humble. Provides a ready-to-build Dockerfile, a Docker Compose service, and configurable driver parameters (IP, port, QoS); recorded rosbag2 sessions live in bags/ and are excluded from version control.

## Overview

This repository packages the ROS 2 [mocap4ros2_qualisys](https://github.com/CentroEPiaggio/mocap4ros2_qualisys) driver (CentroEPiaggio fork) into a Docker image so it can be built and run without installing ROS 2 or the driver's dependencies on the host machine.

## Repository structure

```
.
├── Dockerfile                          # Image based on ros:humble-ros-base, clones and builds mocap4ros2_qualisys
├── compose.yaml                        # Docker Compose service to build/run the container
├── entrypoint.sh                       # Sources the ROS 2 environment and workspace before running the command
├── config/
│   └── qualisys_driver_params.yaml     # Node parameters (Qualisys system IP/port, QoS, etc.)
└── bags/                               # rosbag2 recordings (excluded from the repository, see .gitignore)
```

## Requirements

- Docker and Docker Compose
- Host network reachable from the Qualisys system (the container uses `network_mode: host`)

## Configuration

Edit `config/qualisys_driver_params.yaml` to set the IP address (`host_name`) and port (`host_port`) of the Qualisys server, along with the node's QoS parameters.

## Build and run

```bash
docker compose build
docker compose up -d
docker compose exec qualisys bash
```

Inside the container, the ROS 2 (`humble`) environment and the `mocap_ws` workspace are sourced automatically.

## The `bags/` folder

The `bags/` folder is mounted into the container at `/home/ros/bags` and is meant to hold `ros2 bag record` recordings from acquisition sessions. Its contents are **not tracked in git** (see `.gitignore`) since they consist of large, locally generated binary data.
