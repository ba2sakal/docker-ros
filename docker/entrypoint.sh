#!/bin/bash
set -e

# Function to print welcome information
print_welcome_info() {
    echo "ZED ROS2 Docker Image"
    echo "---------------------"
    echo 'ROS distro: ' $ROS_DISTRO
    echo 'DDS middleware: ' $RMW_IMPLEMENTATION
    echo 'ROS 2 Workspaces:' $COLCON_PREFIX_PATH
    echo 'ROS 2 Domain ID:' $ROS_DOMAIN_ID
    echo 'Machine IPs:' $ROS_IP
    echo "---"  
    echo 'Available ZED packages:'
    ros2 pkg list | grep zed
    echo "---------------------" 
}

# source ROS workspace
source /opt/ros/$ROS_DISTRO/setup.bash
[[ -f $WORKSPACE/devel/setup.bash ]] && source $WORKSPACE/devel/setup.bash
[[ -f $WORKSPACE/install/setup.bash ]] && source $WORKSPACE/install/setup.bash

# exec as dockeruser with configured UID/GID
if [[ $DOCKER_UID && $DOCKER_GID ]]; then
    if ! getent group $DOCKER_GID > /dev/null 2>&1; then
        groupadd -g $DOCKER_GID $DOCKER_USER
    fi
    if ! getent passwd $DOCKER_UID > /dev/null 2>&1; then
        useradd -s /bin/bash \
                -u $DOCKER_UID \
                -g $DOCKER_GID \
                --create-home \
                --home-dir /home/$DOCKER_USER \
                --groups sudo,video \
                --password "$(openssl passwd -1 $DOCKER_USER)" \
                $DOCKER_USER && \
                touch /home/$DOCKER_USER/.sudo_as_admin_successful
        cp /root/.bashrc /home/$DOCKER_USER
        ln -s $WORKSPACE /home/$DOCKER_USER/ws
        chown -h $DOCKER_UID:$DOCKER_GID $WORKSPACE /home/$DOCKER_USER/ws /home/$DOCKER_USER/.sudo_as_admin_successful
        if [[ -d $WORKSPACE/src ]]; then
            chown -R $DOCKER_USER:$DOCKER_USER $WORKSPACE/src
        fi
    fi
    [[ $(pwd) == "$WORKSPACE" ]] && cd /home/$DOCKER_USER/ws

    print_welcome_info
    exec gosu $DOCKER_USER "$@"
else
    print_welcome_info
    exec "$@"
fi
