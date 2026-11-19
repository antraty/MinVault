FROM alpine:3.21

# hadolint ignore=DL3018
RUN apk add --no-cache bash ca-certificates rclone restic tzdata && \
    mkdir -p /staging /status /var/log/minvault /run/minvault

COPY backup.sh /usr/local/bin/backup.sh
COPY restore.sh /usr/local/bin/restore.sh
COPY restore-test.sh /usr/local/bin/restore-test.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY crontab /etc/minvault/crontab.example
RUN chmod 0755 /usr/local/bin/backup.sh /usr/local/bin/restore.sh /usr/local/bin/restore-test.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
