import json
import boto3
from datetime import date


class S3Loader:
    # TODO: write __init__ to accept a bucket name and create a boto3 S3 client.
    #   boto3.client("s3") will automatically use the EC2 instance's IAM role —
    #   no credentials needed in code when running on EC2.

    def land(self, endpoint: str, data: dict, run_date: date | None = None) -> str:
        # Writes raw API response JSON to S3 using the raw landing layer convention:
        #   s3://{bucket}/raw/spotify/{endpoint}/YYYY-MM-DD/response.json
        #
        # Using a date-partitioned prefix lets you re-run a specific day without
        # overwriting other days, and makes debugging easy.
        #
        # TODO: build the S3 key using the pattern above.
        #   - If run_date is None, default to today (date.today()).
        #
        # TODO: call self.s3.put_object() with:
        #   - Bucket: self.bucket
        #   - Key: the key you built
        #   - Body: json.dumps(data, default=str)  — default=str handles datetime objects
        #   - ContentType: "application/json"
        #
        # TODO: return the full s3:// URI so the caller can log it.
        pass
