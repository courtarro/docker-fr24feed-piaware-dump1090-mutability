FROM debian:jessie

ARG FR24_VER=1.0.18-5

# APT Packages
RUN apt-get update &&\
    apt-get install -y --no-install-recommends wget libusb-1.0-0-dev pkg-config ca-certificates cmake build-essential supervisor &&\
	apt-get install -y --no-install-recommends git build-essential debhelper tcl8.6-dev autoconf python3-dev python-virtualenv libz-dev net-tools tclx8.4 tcllib tcl-tls itcl3 python3-venv dh-systemd init-system-helpers &&\
    apt-get clean &&\
    rm -rf /var/lib/apt/lists/*

RUN mkdir /docker

# Set up RTL-SDR
ADD rtl-sdr /docker/rtl-sdr
WORKDIR /docker/rtl-sdr
RUN mkdir build &&\
    cd build &&\
    cmake ../ -DINSTALL_UDEV_RULES=ON -DDETACH_KERNEL_DRIVER=ON &&\
    make &&\
    make install &&\
    ldconfig

# dump1090
ADD dump1090 /docker/dump1090
WORKDIR /docker/dump1090
RUN DUMP1090_VERSION='localver' make &&\
    cp dump1090 /usr/local/bin/ &&\
	mkdir -p /var/lib/dump1090 &&\
    cp -r public_html /var/lib/dump1090/public_html/

# FlightRadar24
WORKDIR /docker
RUN wget https://repo-feed.flightradar24.com/linux_x86_64_binaries/fr24feed_${FR24_VER}_amd64.tgz &&\
    tar zxf fr24feed_${FR24_VER}_amd64.tgz &&\
	cp fr24feed_amd64/fr24feed /usr/local/bin

# FlightAware
ADD piaware /docker/piaware
WORKDIR /docker/piaware
RUN ./sensible-build.sh jessie &&\
    cd package-jessie &&\
	dpkg-buildpackage -b &&\
	cd .. &&\
	dpkg -i piaware_*_*.deb

# Configuration
ADD config.js /var/lib/dump1090/public_html/
ADD fr24feed.ini piaware.conf /etc/

# Supervisor
RUN mkdir -p /var/log/supervisor
ADD supervisor /etc/supervisor

EXPOSE 8754 8080 30001 30002 30003 30004 30005 30104

# Limited user changes
RUN groupadd -g 1000 dump &&\
    useradd -r -u 1000 -g dump dump

ENTRYPOINT ["supervisord"]
CMD ["-c", "/etc/supervisor/supervisord.conf"]