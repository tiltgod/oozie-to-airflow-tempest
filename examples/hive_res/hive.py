
from airflow import models
from airflow.providers.google.cloud.operators.dataproc import \
    DataprocSubmitJobOperator
from airflow.utils import dates
from o2a_lib import functions
from o2a_lib.property_utils import PropertySet

CONFIG = {}

JOB_PROPS = {
    "user.name": "ssuphapinyo",
    "nameNode": "hdfs://",
    "resourceManager": "localhost:8032",
    "queueName": "default",
    "examplesRoot": "examples",
    "oozie.use.system.libpath": "true",
    "oozie.wf.application.path": "${nameNode}/user/${user.name}/${examplesRoot}/apps/hive",
}

TASK_MAP = {
    "hive-script": ["hive-script"],
    "hive-query": ["hive-query"],
    "hive2-script": ["hive2-script"],
    "hive2-query": ["hive2-query"],
}

TEMPLATE_ENV = {**CONFIG, **JOB_PROPS, "functions": functions, "task_map": TASK_MAP}

with models.DAG(
    "hive",
    schedule_interval=None,  # Change to suit your needs
    start_date=dates.days_ago(0),  # Change to suit your needs
    user_defined_macros=TEMPLATE_ENV,
) as dag:
    hive_script = DataprocSubmitJobOperator(
        task_id="hive-script",
        trigger_rule="one_success",
        job=dict(
            placement=dict(
                cluster_name=CONFIG["dataproc_cluster"],
            ),
            hive_job=dict(
                script_variables={
                    "INPUT": "/user/{{functions.wf.user()}}/{{examplesRoot}}/apps/hive/input-data/",
                    "OUTPUT": "/user/{{functions.wf.user()}}/{{examplesRoot}}/apps/hive/output-data/",
                },
                properties=PropertySet(config=CONFIG, job_properties=JOB_PROPS).xml_escaped.merged,
                query_file_uri="{}/{}".format(CONFIG["gcp_uri_prefix"], "script.q"),
            ),
        ),
        gcp_conn_id=CONFIG["gcp_conn_id"],
        region=CONFIG["gcp_region"],
    )

    hive_query = DataprocSubmitJobOperator(
        task_id="hive-query",
        trigger_rule="one_success",
        job=dict(
            placement=dict(
                cluster_name=CONFIG["dataproc_cluster"],
            ),
            hive_job=dict(
                properties=PropertySet(config=CONFIG, job_properties=JOB_PROPS).xml_escaped.merged,
                query_list={
                    "queries": [
                        "DROP TABLE IF EXISTS test_query;\n CREATE EXTERNAL TABLE test_query (a INT) STORED AS TEXTFILE LOCATION '/user/{{functions.wf.user()}}/{{examplesRoot}}/apps/hive/input-data/';\n INSERT OVERWRITE DIRECTORY '/user/{{functions.wf.user()}}/{{examplesRoot}}/apps/hive/output-data/' SELECT * FROM test_query;"
                    ]
                },
            ),
        ),
        gcp_conn_id=CONFIG["gcp_conn_id"],
        region=CONFIG["gcp_region"],
    )

    hive2_script = DataprocSubmitJobOperator(
        task_id="hive2-script",
        trigger_rule="one_success",
        job=dict(
            placement=dict(
                cluster_name=CONFIG["dataproc_cluster"],
            ),
            hive_job=dict(
                script_variables={
                    "INPUT": "/user/{{functions.wf.user()}}/{{examplesRoot}}/apps/hive/input-data/",
                    "OUTPUT": "/user/{{functions.wf.user()}}/{{examplesRoot}}/apps/hive/output-data/",
                },
                properties=PropertySet(config=CONFIG, job_properties=JOB_PROPS).xml_escaped.merged,
                query_file_uri="{}/{}".format(CONFIG["gcp_uri_prefix"], "script.q"),
            ),
        ),
        gcp_conn_id=CONFIG["gcp_conn_id"],
        region=CONFIG["gcp_region"],
    )

    hive2_query = DataprocSubmitJobOperator(
        task_id="hive2-query",
        trigger_rule="one_success",
        job=dict(
            placement=dict(
                cluster_name=CONFIG["dataproc_cluster"],
            ),
            hive_job=dict(
                properties=PropertySet(config=CONFIG, job_properties=JOB_PROPS).xml_escaped.merged,
                query_list={
                    "queries": [
                        "DROP TABLE IF EXISTS test_query;\n CREATE EXTERNAL TABLE test_query (a INT) STORED AS TEXTFILE LOCATION '/user/{{functions.wf.user()}}/{{examplesRoot}}/apps/hive/input-data/';\n INSERT OVERWRITE DIRECTORY '/user/{{functions.wf.user()}}/{{examplesRoot}}/apps/hive/output-data/' SELECT * FROM test_query;"
                    ]
                },
            ),
        ),
        gcp_conn_id=CONFIG["gcp_conn_id"],
        region=CONFIG["gcp_region"],
    )

    hive_script.set_downstream(hive_query)
    hive2_script.set_downstream(hive2_query)
    hive_query.set_downstream(hive2_script)
