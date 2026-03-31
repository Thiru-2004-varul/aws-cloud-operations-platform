FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV ENVIRONMENT=dev
ENV VIRTUAL_ENV=/app/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

RUN apt-get update -y && \
    apt-get install -y python3 python3-pip python3-venv curl && \
    apt-get clean

WORKDIR /app

RUN python3 -m venv /app/venv

COPY requirements.txt .

RUN pip3 install --no-cache-dir -r requirements.txt

COPY app.py .

EXPOSE 80

CMD ["python3", "app.py"]