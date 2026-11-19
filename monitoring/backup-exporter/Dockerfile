FROM python:3.13-alpine@sha256:9ef1a599f863231c3d91e941389bfdc4a2d6070557243d54df1a4e57015b960e

COPY exporter.py /usr/local/bin/backup-exporter.py
RUN chmod 0755 /usr/local/bin/backup-exporter.py

USER nobody
EXPOSE 9101
ENTRYPOINT ["python3", "/usr/local/bin/backup-exporter.py"]
