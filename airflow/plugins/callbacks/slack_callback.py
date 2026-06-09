import os
import requests


def slack_failure_callback(context):
    # This function is passed as `on_failure_callback` in DAG default_args.
    # Airflow calls it automatically whenever a task fails, passing a `context` dict.
    #
    # Useful keys in context:
    #   context["dag"].dag_id             — name of the DAG
    #   context["task_instance"].task_id  — name of the failed task
    #   context["run_id"]                 — the DAG run identifier
    #   context["task_instance"].log_url  — direct link to the task log in Airflow UI
    #
    # TODO: build a Slack message string using the context values above.
    #
    # TODO: POST the message to the Slack webhook URL stored in env var SLACK_WEBHOOK_URL.
    #   Slack webhook payload format: { "text": "your message here" }
    #   Use requests.post(url, json={...})
    #
    # Hint: get the webhook URL with os.environ["SLACK_WEBHOOK_URL"]
    pass
