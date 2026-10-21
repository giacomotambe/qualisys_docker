#!/bin/bash
# Registra una bag con la posa di un solo rigid body (default: traquad)
# Uso: record_mocap.sh <nome_esperimento> [rigid_body]
set -e

if [ -z "$1" ]; then
    echo "Uso: $0 <nome_esperimento> [rigid_body]"
    exit 1
fi

EXPERIMENT="$1"
BODY="${2:-traquad}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BAG_DIR="$HOME/bags/${EXPERIMENT}_$(date +%Y%m%d_%H%M%S)"

if [[ "$EXPERIMENT" == */* ]]; then
    echo "Il nome dell'esperimento non può contenere '/'"
    exit 1
fi

source /opt/ros/humble/setup.bash
source /home/ros/mocap_ws/install/setup.bash

# Il driver deve essere già attivo
if ! ros2 topic list | grep -qx "/rigid_bodies"; then
    echo "/rigid_bodies non trovato: avvia prima 'ros2 launch qualisys_driver qualisys.launch.py'"
    exit 1
fi

python3 "$SCRIPT_DIR/rigid_body_filter.py" "$BODY" &
FILTER_PID=$!
trap 'kill -INT $FILTER_PID 2>/dev/null; wait $FILTER_PID 2>/dev/null' EXIT

# Aspetta che arrivi almeno un messaggio del rigid body
echo "In attesa di dati da '$BODY'..."
if ! timeout 10 ros2 topic echo --once "/$BODY/pose" geometry_msgs/msg/PoseStamped > /dev/null; then
    echo "Nessun dato da '$BODY' in 10 s: controlla il nome del 6DOF body in QTM"
    exit 1
fi

echo "Registrazione in $BAG_DIR (Ctrl+C per fermare)"
ros2 bag record -o "$BAG_DIR" "/$BODY/pose"
