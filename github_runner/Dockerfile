ARG BUILD_FROM
FROM $BUILD_FROM

# Install runtime dependencies required by the GitHub Actions runner
RUN apt-get update && apt-get install -y \
    curl \
    jq \
    python3 \
    libicu-dev \
    libkrb5-3 \
    zlib1g \
    iputils-ping \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Allow the GitHub runner to run as root so it can use /data persistence.
ENV RUNNER_ALLOW_RUNASROOT=1

# Create directories used by the add-on.
RUN mkdir -p /home/runner /data/runner

# Copy the add-on entrypoint
COPY run.sh /
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
