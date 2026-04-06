ARG BUILD_FROM
FROM $BUILD_FROM

RUN useradd -m -s /bin/bash runner


# Install runtime dependencies required by the GitHub Actions runner
RUN apt-get update && apt-get install -y \
    curl \
    jq \
    python3 \
    sudo \
    libicu-dev \
    libkrb5-3 \
    zlib1g \
    iputils-ping \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Set up the runner user
RUN echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create a dedicated directory for the runner installation
RUN mkdir -p /home/runner

# Copy the add-on entrypoint
COPY run.sh /
RUN chmod a+x /run.sh

USER runner

CMD [ "/run.sh" ]
