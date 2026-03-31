from flask import Flask, jsonify
import boto3
import json
import time
import os

app = Flask(__name__)
start_time = time.time()

AWS_REGION = "ap-south-1"
PROJECT = "cloud-ops"
ENV = os.environ.get("ENVIRONMENT", "dev")


def get_secret(secret_name):
    client = boto3.client("secretsmanager", region_name=AWS_REGION)
    response = client.get_secret_value(SecretId=secret_name)
    return json.loads(response["SecretString"])


@app.route("/health")
def health():
    return jsonify({
        "status": "healthy",
        "uptime_seconds": int(time.time() - start_time),
        "environment": ENV
    }), 200


@app.route("/metrics")
def metrics():
    return jsonify({
        "uptime_seconds": int(time.time() - start_time),
        "status": "running",
        "environment": ENV
    }), 200


@app.route("/")
def index():
    return jsonify({
        "message": "aws-cloud-operations-platform",
        "environment": ENV
    }), 200


@app.route("/secret-test")
def secret_test():
    try:
        secret = get_secret(f"{PROJECT}/{ENV}/app/config")
        return jsonify({
            "status": "success",
            "message": "Secret fetched from AWS Secrets Manager",
            "environment": secret.get("environment"),
            "keys_available": list(secret.keys())
        }), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route("/db-config")
def db_config():
    try:
        secret = get_secret(f"{PROJECT}/{ENV}/db/credentials")
        return jsonify({
            "status": "success",
            "message": "DB credentials fetched from Secrets Manager",
            "host": secret.get("host"),
            "port": secret.get("port"),
            "dbname": secret.get("dbname"),
            "username": secret.get("username")
        }), 200
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)