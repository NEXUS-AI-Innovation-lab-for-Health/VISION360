FROM python:3.12-slim

WORKDIR /app

# Statique POC web
COPY poc-web/ .

EXPOSE 8001
CMD ["python", "-m", "http.server", "8001"]
