import shlex

from airflow import models
from airflow.operators import bash
from airflow.utils import dates
from o2a_lib import functions
from o2a_lib.property_utils import PropertySet

CONFIG = {}

JOB_PROPS = {
    "user.name": "ssuphapinyo",
    "nameNode": "hdfs://localhost:8020",
    "resourceManager": "localhost:8032",
    "queueName": "default",
    "examplesRoot": "examples",
    "oozie.wf.application.path": "${nameNode}/user/${user.name}/${examplesRoot}/apps/shell",
}

TASK_MAP = {"shell-node": ["shell-node_prepare", "shell-node"]}

TEMPLATE_ENV = {**CONFIG, **JOB_PROPS, "functions": functions, "task_map": TASK_MAP}

with models.DAG(
    "shell",
    schedule_interval=None,  # Change to suit your needs
    start_date=dates.days_ago(0),  # Change to suit your needs
    user_defined_macros=TEMPLATE_ENV,
) as dag:
    shell_node_prepare = bash.BashOperator(
        task_id="shell-node_prepare",
        trigger_rule="one_success",
        bash_command="$DAGS_FOLDER/../data/prepare.sh "
        "-c %s -r %s "
        "-d %s "
        "-m %s "
        % (
            CONFIG["dataproc_cluster"],
            CONFIG["gcp_region"],
            shlex.quote("/user/{{functions.wf.user()}}/{{examplesRoot}}/apps/shell/test"),
            shlex.quote("/user/{{functions.wf.user()}}/{{examplesRoot}}/apps/shell/test"),
        ),
        params=PropertySet(config=CONFIG, job_properties=JOB_PROPS).merged,
    )
    shell_node = bash.BashOperator(
        task_id="shell-node",
        trigger_rule="one_success",
        bash_command="gcloud dataproc jobs submit pig "
        "--cluster=%s "
        "--region=%s "
        "--execute %s" % (CONFIG["dataproc_cluster"], CONFIG["gcp_region"], shlex.quote("sh java -version")),
        params=PropertySet(
            config=CONFIG,
            job_properties=JOB_PROPS,
            action_node_properties={"mapred.job.queue.name": "{{queueName}}"},
        ).merged,
    )
    shell_node_prepare.set_downstream(shell_node)
