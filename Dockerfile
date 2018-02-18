FROM ubuntu:xenial

ARG FR24_VER=1.0.18-5

# APT Packages
RUN apt-get update && \
    apt-get install -y wget libusb-1.0-0-dev pkg-config ca-certificates cmake build-essential supervisor --no-install-recommends && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir /docker

# Set up RTL-SDR
ADD rtl-sdr /docker/rtl-sdr
WORKDIR /docker/rtl-sdr
RUN mkdir build && \
    cd build && \
    cmake ../ -DINSTALL_UDEV_RULES=ON -DDETACH_KERNEL_DRIVER=ON && \
    make && \
    make install && \
    ldconfig

# dump1090
ADD dump1090 /docker/dump1090
WORKDIR /docker/dump1090
RUN DUMP1090_VERSION='localver' make && \
    cp dump1090 /usr/local/bin/ && \
	mkdir -p /var/lib/dump1090 && \
    cp -r public_html /var/lib/dump1090/public_html/
ADD config.js /var/lib/dump1090/public_html/

# FlightRadar24
WORKDIR /docker/
RUN wget https://repo-feed.flightradar24.com/linux_x86_64_binaries/fr24feed_${FR24_VER}_amd64.tgz &&\
    tar zxf fr24feed_${FR24_VER}_amd64.tgz &&\
	cp fr24feed_amd64/fr24feed /usr/local/bin
ADD fr24feed.ini /etc/fr24feed.ini

# Supervisor
RUN mkdir -p /var/log/supervisor
ADD supervisor /etc/supervisor

EXPOSE 8754 8080 30001 30002 30003 30004 30005 30104

# Limited user changes
RUN groupadd -g 1000 dump && \
    useradd -r -u 1000 -g dump dump

ENTRYPOINT ["supervisord"]
CMD ["-c", "/etc/supervisor/supervisord.conf"]