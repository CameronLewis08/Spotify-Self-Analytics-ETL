from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.sensors.external_task import ExternalTaskSensor
from callbacks.slack_callback import slack_failure_callback

DEFAULT_ARGS = {
    "owner": "ae",
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
    "on_failure_callback": slack_failure_callback,
}

with DAG(
    dag_id="spotify_transform",
    schedule="0 0 * * *",
    start_date=datetime(2026, 1, 1),
    catchup=False,
    default_args=DEFAULT_ARGS,
    tags=["spotify", "dbt", "transform"],
) as dag:

    # ExternalTaskSensor pauses this DAG until a specific task in another DAG succeeds.
    # This is how the two DAGs are chained without merging them into one.
    #
    # TODO: fill in external_dag_id and external_task_id.
    #   We want to wait until the "load_to_rds" task in "spotify_el" has succeeded
    #   for the same logical date as this run.
    wait_for_el = ExternalTaskSensor(
        task_id="wait_for_el_dag",
        external_dag_id=...,       # TODO: which DAG?
        external_task_id=...,      # TODO: which task in that DAG?
        timeout=3600,              # give the EL dag up to 1 hour before failing
        poke_interval=60,          # check every 60 seconds
    )

    # BashOperator runs a shell command on the Airflow worker (the EC2 instance).
    # dbt Core is installed on EC2, so we can invoke it directly from here.
    #
    # TODO: fill in the bash_command to run dbt.
    #   - cd to where your dbt project lives on EC2
    #   - run: dbt run --profiles-dir <path to profiles.yml directory>
    run_dbt = BashOperator(
        task_id="run_dbt",
        bash_command=...,   # TODO: dbt run command
    )

    # TODO: add a dbt test task after run_dbt.
    #   dbt test runs all schema tests defined in your models' .yml files.
    #   If any test fails, the task fails and Slack fires — good signal that data quality broke.
    test_dbt = BashOperator(
        task_id="test_dbt",
        bash_command=...,   # TODO: dbt test command
    )

    # TODO: express the dependency chain: wait_for_el >> run_dbt >> test_dbt
