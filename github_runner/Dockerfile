ARG BUILD_FROM
FROM $BUILD_FROM

# Install runtime dependencies required by the GitHub Actions runner
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        git \
        jq \
        libicu67 \
        libssl1.1 \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create a dedicated directory for the runner installation
RUN mkdir -p /home/runner

# Copy the add-on entrypoint
COPY run.sh /
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
