FROM ros:humble-ros-base

ENV DEBIAN_FRONTEND=noninteractive
ENV ROS_DISTRO=humble

# Dipendenze di sistema
RUN apt-get update && apt-get install -y \
    python3-colcon-common-extensions \
    python3-vcstool \
    git \
    cmake \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Utente non-root (prima del workspace così /home/ros esiste)
RUN useradd -m -s /bin/bash -u 1000 ros

# Crea workspace e clona il repo con i submodule
WORKDIR /home/ros/mocap_ws/src
RUN git clone --recursive https://github.com/CentroEPiaggio/mocap4ros2_qualisys.git

# Importa dipendenze aggiuntive tramite vcs
RUN vcs import < mocap4ros2_qualisys/dependency_repos.repos || true

# Installa dipendenze ROS
WORKDIR /home/ros/mocap_ws
RUN . /opt/ros/humble/setup.sh && \
    rosdep update && \
    apt-get update && \
    rosdep install --from-paths src --ignore-src -r -y \
        --skip-keys "qualisys_cpp_sdk" && \
    rm -rf /var/lib/apt/lists/*

# Compila
RUN . /opt/ros/humble/setup.sh && \
    colcon build --symlink-install

# Permessi finali
RUN chown -R ros:ros /home/ros

# Entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER ros
RUN echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc && \
    echo "source /home/ros/mocap_ws/install/setup.bash" >> ~/.bashrc
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
