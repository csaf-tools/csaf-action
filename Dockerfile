#SPDX-FileCopyrightText: 2025 Intevation GmbH
#SPDX-License-Identifier: AGPL-3.0-or-later

FROM debian:bookworm-slim

WORKDIR /action/workspace
COPY nginx/ csaf_provider/ entrypoint.sh /action/workspace/

ARG csaf_version=3.3.0
ARG secvisogram_version=2.0.7


# Install nginx and node
# npm and hunspell for secvisogram
RUN DEBIAN_FRONTEND=noninteractive apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y nginx fcgiwrap npm hunspell wait-for-it wget curl && \
    DEBIAN_FRONTEND=noninteractive apt-get clean

# Setup nginx
RUN cp fcgiwrap.conf /etc/nginx/fcgiwrap.conf && \
    cp default.conf /etc/nginx/sites-enabled/default

# Get CSAF tools
RUN wget https://github.com/gocsaf/csaf/releases/download/v${csaf_version}/csaf-${csaf_version}-gnulinux-amd64.tar.gz && \
    tar -xzf csaf-${csaf_version}-gnulinux-amd64.tar.gz && \
    mkdir -p /usr/lib/cgi-bin/ /etc/csaf/ && \
    cp csaf-${csaf_version}-gnulinux-amd64/bin-linux-amd64/csaf_provider /usr/lib/cgi-bin/csaf_provider.go

# Install secvisogram
RUN wget https://github.com/secvisogram/csaf-validator-service/archive/refs/tags/v${secvisogram_version}.tar.gz -O secvisogram-csaf-validator-service-${secvisogram_version}.tar.gz && \
    tar -xzf secvisogram-csaf-validator-service-${secvisogram_version}.tar.gz

# Configure csaf_provider
# for validations.db
RUN mkdir -p /var/lib/csaf/ && \
    cp config.toml /etc/csaf/config.toml && \
    chgrp www-data /etc/csaf/config.toml && \
    chmod g+r,o-rwx /etc/csaf/config.toml

# Setup secvisogram
WORKDIR csaf-validator-service-${secvisogram_version}
RUN npm ci
WORKDIR /action/workspace

ENTRYPOINT ["/bin/bash", "-l", "-c"]
CMD ["/action/workspace/entrypoint.sh"]
