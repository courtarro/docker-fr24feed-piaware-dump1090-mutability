FROM debian:stretch

ARG FR24_VER=1.0.24-5
ARG UID=1000
ARG GID=1000

# APT Packages
RUN apt-get update &&\
    apt-get install -y --no-install-recommends wget libusb-1.0-0-dev pkg-config ca-certificates cmake build-essential supervisor nginx && \
    apt-get install -y --no-install-recommends git build-essential debhelper librtlsdr-dev libncurses5-dev tcl8.6-dev autoconf python3-dev python-virtualenv libz-dev net-tools tclx8.4 tcllib tcl-tls itcl3 python3-venv dh-systemd devscripts init-system-helpers libboost-system-dev libboost-program-options-dev libboost-regex-dev libboost-filesystem-dev &&\
    apt-get clean &&\
    rm -rf /var/lib/apt/lists/*

RUN mkdir /docker

# dump1090
COPY dump1090 /docker/dump1090
WORKDIR /docker/dump1090
RUN DUMP1090_VERSION='localver' make -j4 BLADERF=no &&\
    cp dump1090 /usr/local/bin/ &&\
    mkdir -p /var/lib/dump1090 &&\
    cp -r public_html /var/lib/dump1090/public_html/

# FlightRadar24
WORKDIR /docker
RUN wget https://repo-feed.flightradar24.com/linux_x86_64_binaries/fr24feed_${FR24_VER}_amd64.tgz &&\
    tar zxf fr24feed_${FR24_VER}_amd64.tgz &&\
    cp fr24feed_amd64/fr24feed /usr/local/bin

# FlightAware
COPY piaware /docker/piaware
WORKDIR /docker/piaware
RUN ./sensible-build.sh stretch &&\
    cd package-stretch &&\
    dpkg-buildpackage -b &&\
    cd .. &&\
    dpkg -i piaware_*_*.deb

# Configuration
COPY config.js /var/lib/dump1090/public_html/
COPY fr24feed.ini piaware.conf /etc/

# Limited user setup
RUN groupadd -g ${GID} docker &&\
    useradd -r -d /docker -u ${UID} -g docker docker
RUN chown docker:docker /docker &&\
    chown docker:docker /var/cache/piaware

# Supervisor
COPY supervisor /etc/supervisor

# nginx
COPY nginx.conf /etc/nginx/

EXPOSE 8754 8080 30001 30002 30003 30004 30005 30104

WORKDIR /docker
ENTRYPOINT ["supervisord"]
CMD ["-c", "/etc/supervisor/supervisord.conf"]
