import boto3
import json
import hvac
import os

AWS_REGION = "ap-south-1"
VAULT_ADDR = os.environ.get("VAULT_ADDR", "http://127.0.0.1:8200")
VAULT_TOKEN = os.environ.get("VAULT_TOKEN", "root-token")


def fetch_from_secrets_manager(secret_name):
    print(f"\nFetching from AWS Secrets Manager: {secret_name}")
    client = boto3.client("secretsmanager", region_name=AWS_REGION)
    response = client.get_secret_value(SecretId=secret_name)
    secret = json.loads(response["SecretString"])
    print(f"Success — keys: {list(secret.keys())}")
    return secret


def fetch_from_vault(path):
    print(f"\nFetching from HashiCorp Vault: {path}")
    client = hvac.Client(url=VAULT_ADDR, token=VAULT_TOKEN)
    response = client.secrets.kv.v2.read_secret_version(path=path)
    secret = response["data"]["data"]
    print(f"Success — keys: {list(secret.keys())}")
    return secret


if __name__ == "__main__":
    print("=== Secrets Fetch Test ===")

    print("\n--- AWS Secrets Manager ---")
    try:
        fetch_from_secrets_manager("cloud-ops/dev/db/credentials")
        fetch_from_secrets_manager("cloud-ops/dev/app/config")
    except Exception as e:
        print(f"Error: {e}")

    print("\n--- HashiCorp Vault ---")
    try:
        fetch_from_vault("cloud-ops/dev/db")
        fetch_from_vault("cloud-ops/dev/app")
    except Exception as e:
        print(f"Error: {e}")

    print("\n=== Done ===")