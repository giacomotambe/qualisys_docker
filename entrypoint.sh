#!/bin/bash
set -e
source /opt/ros/humble/setup.bash
source /home/ros/mocap_ws/install/setup.bash
exec "$@"
