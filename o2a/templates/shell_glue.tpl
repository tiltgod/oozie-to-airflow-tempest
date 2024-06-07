{#
  Copyright 2019 Google LLC

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
#}
{% import "macros/props.tpl" as props_macro %}

{{ task_id | to_var }} = GlueJobOperator(
    task_id={{ task_id | to_python }},
    job_name={{ job_name | to_python }},
    script_location={{ script_location | to_python }},
    s3_bucket={{ s3_bucket | to_python }},
    iam_role_name={{ iam_role_name | to_python }},
    region_name={{ region_name | to_python }},
    script_args={{ script_args | to_python }},
    params={{ props_macro.props(action_node_properties=action_node_properties) }},
    trigger_rule={{ trigger_rule | to_python }},
)
