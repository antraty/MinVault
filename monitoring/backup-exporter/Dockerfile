FROM python:3.13-alpine

COPY exporter.py /usr/local/bin/backup-exporter.py
RUN chmod 0755 /usr/local/bin/backup-exporter.py

USER nobody
EXPOSE 9101
ENTRYPOINT ["python3", "/usr/local/bin/backup-exporter.py"]
