# Tiny image: 12 MB Alpine + gnuplot
FROM alpine:3.20

RUN apk add --no-cache bash gnuplot curl coreutils

# Copy code
COPY collector/collector.sh collector/render.sh /opt/
COPY config.env /opt/config.env

# Create data volume
VOLUME ["/data"]

# Default command runs both scripts in background loops
CMD bash -c '\
  while :; do /opt/collector.sh; sleep "${SCRAPE_INTERVAL:-15}"; done & \
  while :; do /opt/render.sh;   sleep "${RENDER_INTERVAL:-30}"; done & \
  wait -n'