FROM debian:bookworm

ARG DEBIAN_DIST
ARG UPSTREAM_VERSION
ARG BUILD_VERSION
ARG FULL_VERSION
ARG ARCH
ARG UPSTREAM_RELEASE

RUN mkdir -p /output/usr/bin
RUN mkdir -p /output/usr/share/doc/uv
RUN mkdir -p /output/DEBIAN

COPY ${UPSTREAM_RELEASE}/* /output/usr/bin/
COPY uv-contents/DEBIAN/* /output/DEBIAN/
COPY uv-contents/copyright /output/usr/share/doc/uv/
COPY uv-contents/changelog.Debian /output/usr/share/doc/uv/
COPY uv-contents/README.md /output/usr/share/doc/uv/

RUN sed -i "s/DIST/$DEBIAN_DIST/" /output/usr/share/doc/uv/changelog.Debian
RUN sed -i "s/FULL_VERSION/$FULL_VERSION/" /output/usr/share/doc/uv/changelog.Debian
RUN sed -i "s/DIST/$DEBIAN_DIST/" /output/DEBIAN/control
RUN sed -i "s/UPSTREAM_VERSION/$UPSTREAM_VERSION/" /output/DEBIAN/control
RUN sed -i "s/BUILD_VERSION/$BUILD_VERSION/" /output/DEBIAN/control
RUN sed -i "s/SUPPORTED_ARCHITECTURES/$ARCH/" /output/DEBIAN/control

RUN dpkg-deb --build /output /uv_${FULL_VERSION}.deb
