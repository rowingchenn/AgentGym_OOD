# Evaluation args
model_path="Qwen/Qwen2.5-7B-Instruct"
inference_file="/home/weichen/AgentGym_OOD/agentenv-webarena/webarena/config_files/test_inference_files/test.json"
output_file="/home/weichen/AgentGym_OOD/agentenv/results/test_output_files.json"
task_name="webarena"
seed="42"

# environment parameters
max_round="15"
env_server_base="http://127.0.0.1:8000"

python -u /home/weichen/AgentGym_OOD/agentenv/examples/basic/base_eval_template.py \
        --model_path "${model_path}" \
        --inference_file "${inference_file}" \
        --output_file "${output_file}" \
        --task_name "${task_name}" \
        --seed "${seed}" \
        --max_round "${max_round}" \
        --env_server_base "${env_server_base}"
