ARG BASE_IMAGE

############ dependencies ######################################################
FROM ${BASE_IMAGE} as dependencies

USER root
SHELL ["/bin/bash", "-c"]
ARG DEBIAN_FRONTEND=noninteractive

# create workspace folder structure
ENV WORKSPACE=/docker-ros/ws
WORKDIR $WORKSPACE
RUN mkdir -p src/target src/upstream src/downstream

# install ROS bootstrapping tools
RUN apt-get update && \
    apt-get install -y \
        git \
        python3-rosdep \
        python3-vcstool \
    && rm -rf /var/lib/apt/lists/*

# copy contents of repository
COPY . src/target

# clone .repos upstream dependencies
ARG GIT_HTTPS_SERVER=
ARG GIT_HTTPS_USER=
ARG GIT_HTTPS_PASSWORD=
RUN if [[ -n ${GIT_HTTPS_SERVER} ]]; then \
        git config --global url.https://${GIT_HTTPS_USER}:${GIT_HTTPS_PASSWORD}@${GIT_HTTPS_SERVER}.insteadOf https://${GIT_HTTPS_SERVER} ; \
    fi
ARG GIT_SSH_PRIVATE_KEY=
ARG GIT_SSH_KNOWN_HOST_KEYS=
RUN if [[ -n ${GIT_SSH_PRIVATE_KEY} ]]; then \
        echo -e ${GIT_SSH_PRIVATE_KEY} > /tmp/ssh_id && \
        chmod 400 /tmp/ssh_id && \
        git config --global core.sshCommand "ssh -i /.ssh_key" && \
        mkdir -p ~/.ssh && \
        touch ~/.ssh/known_hosts && \
        echo -e ${GIT_SSH_KNOWN_HOST_KEYS} >> ~/.ssh/known_hosts ; \
    fi
COPY docker/docker-ros/docker/recursive_vcs_import.py /usr/local/bin
RUN apt-get update && \
    apt-get install -y python-is-python3 && \
    rm -rf /var/lib/apt/lists/*

ARG VCS_IMPORT_FILE=".repos"
ARG ENABLE_RECURSIVE_VCS_IMPORT="true"
RUN if [[ $ENABLE_RECURSIVE_VCS_IMPORT == 'true' ]]; then \
        /usr/local/bin/recursive_vcs_import.py src src/upstream ; \
    elif [[ -f src/target/${VCS_IMPORT_FILE} ]]; then \
        vcs import --recursive src/upstream < src/target/${VCS_IMPORT_FILE} ; \
    fi


############ dependencies-install ##############################################
FROM ${BASE_IMAGE} AS dependencies-install
ARG TARGETARCH
ARG GIT_HTTPS_URL
ARG GIT_HTTPS_USER
ARG GIT_HTTPS_PASSWORD
ENV TARGETARCH=${TARGETARCH}
ENV DOCKER_ROS=1

USER root
SHELL ["/bin/bash", "-c"]
ARG DEBIAN_FRONTEND=noninteractive

# user setup
ENV DOCKER_USER=dockeruser
ENV DOCKER_UID=
ENV DOCKER_GID=

# ROS setup
ENV RCUTILS_COLORIZED_OUTPUT=1
ENV WORKSPACE=/docker-ros/ws
ENV COLCON_HOME=$WORKSPACE/.colcon
WORKDIR $WORKSPACE


# install essential build tools and dependencies for install script
RUN apt-get update && \
    apt-get install -y \
        build-essential \
        gosu \
        python-is-python3 \
        python3-pip \
    && rm -rf /var/lib/apt/lists/*

# configure pip
RUN python -m pip config --global set global.break-system-packages true

# # copy install script from dependencies stage
# COPY --from=dependencies $WORKSPACE/.install-dependencies.sh $WORKSPACE/.install-dependencies.sh

# # install dependencies
# RUN apt-get update && \
#     $WORKSPACE/.install-dependencies.sh && \
#     rm -rf /var/lib/apt/lists/*

######################################################################################################
ARG ZED_SDK_MAJOR=4
ARG ZED_SDK_MINOR=1
ARG ZED_SDK_PATCH=0
ARG JETPACK_MAJOR=5
ARG JETPACK_MINOR=0
ARG L4T_MAJOR=35
ARG L4T_MINOR=1

ARG ROS2_DIST=humble       # ROS2 distribution

# ZED ROS2 Wrapper dependencies version
ARG XACRO_VERSION=2.0.8
ARG DIAGNOSTICS_VERSION=3.0.0
ARG AMENT_LINT_VERSION=0.12.4
ARG GEOGRAPHIC_INFO_VERSION=1.0.4
ARG ROBOT_LOCALIZATION_VERSION=3.4.2

ENV DEBIAN_FRONTEND noninteractive

# ZED SDK link
ENV ZED_SDK_URL="https://stereolabs.sfo2.cdn.digitaloceanspaces.com/zedsdk/${ZED_SDK_MAJOR}.${ZED_SDK_MINOR}/ZED_SDK_Tegra_L4T${L4T_MAJOR}.${L4T_MINOR}_v${ZED_SDK_MAJOR}.${ZED_SDK_MINOR}.${ZED_SDK_PATCH}.zstd.run"

# Check that this SDK exists
RUN if [ "$(curl -I "${ZED_SDK_URL}" -o /dev/null -s -w '%{http_code}\n' | head -n 1)" = "200" ]; then \
        echo "The URL points to something."; \
    else \
        echo "The URL does not point to a .run file or the file does not exist."; \
        exit 1; \
    fi

# Disable apt-get warnings
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 42D5A192B819C5DA || true && \
  apt-get update || true && apt-get install -y --no-install-recommends apt-utils dialog && \
  rm -rf /var/lib/apt/lists/*

ENV TZ=Europe/Paris

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \ 
  apt-get update && \
  apt-get install --yes lsb-release wget less udev sudo build-essential cmake python3 python3-dev python3-pip python3-wheel git jq libpq-dev zstd usbutils && \    
  rm -rf /var/lib/apt/lists/*

RUN echo "# R${L4T_MAJOR} (release), REVISION: ${L4T_MINOR}" > /etc/nv_tegra_release && \
  apt-get update -y || true && \
  apt-get install -y --no-install-recommends zstd wget less cmake curl gnupg2 \
  build-essential python3 python3-pip python3-dev python3-setuptools libusb-1.0-0-dev -y && \
  pip install protobuf && \
  wget -q --no-check-certificate -O ZED_SDK_Linux_JP.run \
  ${ZED_SDK_URL} && \
  chmod +x ZED_SDK_Linux_JP.run ; ./ZED_SDK_Linux_JP.run silent skip_tools && \
  rm -rf /usr/local/zed/resources/* && \
  rm -rf ZED_SDK_Linux_JP.run && \
  rm -rf /var/lib/apt/lists/*

# Install the ZED ROS2 Wrapper
ENV ROS_DISTRO ${ROS2_DIST}

# Install missing dependencies
WORKDIR /root/ros2_ws/src
RUN wget https://github.com/ros/xacro/archive/refs/tags/${XACRO_VERSION}.tar.gz -O - | tar -xvz && mv xacro-${XACRO_VERSION} xacro && \
  wget https://github.com/ros/diagnostics/archive/refs/tags/${DIAGNOSTICS_VERSION}.tar.gz -O - | tar -xvz && mv diagnostics-${DIAGNOSTICS_VERSION} diagnostics && \
  wget https://github.com/ament/ament_lint/archive/refs/tags/${AMENT_LINT_VERSION}.tar.gz -O - | tar -xvz && mv ament_lint-${AMENT_LINT_VERSION} ament-lint && \
  wget https://github.com/cra-ros-pkg/robot_localization/archive/refs/tags/${ROBOT_LOCALIZATION_VERSION}.tar.gz -O - | tar -xvz && mv robot_localization-${ROBOT_LOCALIZATION_VERSION} robot-localization && \
  wget https://github.com/ros-geographic-info/geographic_info/archive/refs/tags/${GEOGRAPHIC_INFO_VERSION}.tar.gz -O - | tar -xvz && mv geographic_info-${GEOGRAPHIC_INFO_VERSION} geographic-info && \
  cp -r geographic-info/geographic_msgs/ . && \
  rm -rf geographic-info && \
  git clone https://github.com/ros-drivers/nmea_msgs.git --branch ros2 && \  
  git clone https://github.com/ros/angles.git --branch humble-devel

# Check that all the dependencies are satisfied
WORKDIR $WORKSPACE
RUN apt-get update -y || true && rosdep update && \
  rosdep install --from-paths src --ignore-src -r -y && \
  rm -rf /var/lib/apt/lists/*

# Install cython
RUN python3 -m pip install --upgrade cython

# Build the dependencies and the ZED ROS2 Wrapper
RUN /bin/bash -c "source /opt/ros/$ROS_DISTRO/install/setup.bash && \
  colcon build --parallel-workers $(nproc) --symlink-install \
  --event-handlers console_direct+ --base-paths src \
  --cmake-args ' -DCMAKE_BUILD_TYPE=Release' \
  ' -DCMAKE_LIBRARY_PATH=/usr/local/cuda/lib64/stubs' \
  ' -DCMAKE_CXX_FLAGS="-Wl,--allow-shlib-undefined"' \
  ' --no-warn-unused-cli' "
  ###################################################################################################################################################

# install ROS CLI tools
RUN source /opt/ros/$ROS_DISTRO/install/setup.bash && \
    apt-get update && \
    if [[ "$ROS_VERSION" == "1" ]]; then \
        apt-get install -y \
            python3-catkin-tools ; \
    elif [[ "$ROS_VERSION" == "2" ]]; then \
        apt-get install -y \
            python3-colcon-common-extensions ; \
    fi \
    && rm -rf /var/lib/apt/lists/*

# install desired ROS 2 middleware
ARG RMW_IMPLEMENTATION="rmw_cyclonedds_cpp"
ENV RMW_IMPLEMENTATION=${RMW_IMPLEMENTATION}
RUN source /opt/ros/$ROS_DISTRO/install/setup.bash && \
    if [[ "$ROS_VERSION" == "2" ]]; then \
        apt-get update && \
        RMW_PACKAGE=ros-$ROS_DISTRO-$(echo $RMW_IMPLEMENTATION | tr '_' '-') && \
        apt-get install -y $RMW_PACKAGE && \
        rm -rf /var/lib/apt/lists/* ; \
    fi

# source ROS
RUN echo "source /opt/ros/$ROS_DISTRO/install/setup.bash" >> ~/.bashrc

# set entrypoint
ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-${TARGETARCH} /tini
RUN chmod +x /tini
COPY docker/docker-ros/docker/entrypoint.sh /
ENTRYPOINT ["/tini", "--", "/entrypoint.sh"]

############ dev ###############################################################
FROM dependencies-install as dev

# copy contents of repository from dependencies stage
COPY --from=dependencies $WORKSPACE/src $WORKSPACE/src

CMD ["bash"]

############ build #############################################################
FROM dev as build

# build ROS workspace
RUN if [[ -x "$(command -v colcon)" ]]; then \
        source /opt/ros/${ROS_DISTRO}/install/setup.bash && \
        colcon build --parallel-workers $(nproc) --symlink-install --event-handlers console_direct+ --base-paths src --cmake-args ' -DCMAKE_BUILD_TYPE=Release' ' -DCMAKE_LIBRARY_PATH=/usr/local/cuda/lib64/stubs' ' -DCMAKE_CXX_FLAGS="-Wl,--allow-shlib-undefined"' ' --no-warn-unused-cli' ; \
    elif [[ -x "$(command -v catkin)" ]]; then \
        catkin config --install --extend /opt/ros/${ROS_DISTRO} && \
        catkin build -DCMAKE_BUILD_TYPE=Release --force-color --no-status --summarize ; \
    fi

############ run ###############################################################
FROM dependencies-install as run

# copy ROS install space from build stage
COPY --from=build $WORKSPACE/install install
RUN ldconfig
RUN echo "[[ -f $WORKSPACE/devel/setup.bash ]] && source $WORKSPACE/devel/setup.bash" >> ~/.bashrc && \
    echo "[[ -f $WORKSPACE/install/setup.bash ]] && source $WORKSPACE/install/setup.bash" >> ~/.bashrc

# setup command
ARG COMMAND
ENV DEFAULT_CMD=${COMMAND}
CMD bash -c "${DEFAULT_CMD}"