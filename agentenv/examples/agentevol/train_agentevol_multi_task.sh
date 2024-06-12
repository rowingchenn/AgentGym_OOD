# slurm config
numgpu=8

exp_name="agentevol_llama2_7b_all_task"
iter_num=4
n_epochs=1

# accelerator config
num_processes=8
main_process_port=8872
config_file=""

# training arguments
iter_data_path="./iter_data/iter_data_all_task"

# agent model
model_train_path="meta-llama/Llama-2-7b-chat-hf"
output_dir="outputs/${exp_name}"

batch_size=2
eval_batch_size=1
gradient_accumulation_steps=2
max_input_length=4096
max_round=10
num_workers=8
learning_rate=1e-5
weight_decay=0
warmup_step=-100
clip_grad_norm=1
seed=42

# logging and saving
logging_epoch_freq=1
logging_step_freq=10
saving_epoch_freq=1
evaluating_epoch_freq=100

# wandb config
wandb_log=True
wandb_project="agentenv"
wandb_run_name="${exp_name}"

# environment parameters
data_len=200
timeout=2400

task_list=("webshop" "alfworld" "textcraft" "sciworld" "sqlgym" "lmrlgym_wordle" "lmrlgym_maze" "babyai" "weather" "movie" "todo" "academia" "sheet" "webarena")

# eval parameters
test_file_list=(
    "PATH/TO/webshop_test.json"
    "PATH/TO/alfworld_test.json"
    "PATH/TO/textcraft_test.json"
    "PATH/TO/sciworld_test_small.json"
    "PATH/TO/sqlgym_test_small.json"
    "PATH/TO/wordle_test.json"
    "PATH/TO/maze_test.json"
    "PATH/TO/babyai_test.json"
    "PATH/TO/tool_weather_test.json"
    "PATH/TO/tool_movie_test.json"
    "PATH/TO/tool_todo_test.json"
    "PATH/TO/tool_academia_test.json"
    "PATH/TO/tool_sheet_test.json"
    "PATH/TO/webarena_test.json"
)

# inference parameters
sample_num=3
inference_file_list=("webshop.json" "alfworld.json" "textcraft.json" "sciworld.json" "sqlgym.json" "wordle.json" "maze.json" "babyai.json" "weather.json" "movie.json" "todo.json" "academia.json" "sheet.json" "webarena.json")
max_round_list=("10" "30" "20" "30" "1" "8" "15" "20" "10" "12" "15" "12" "15" "25")
env_server_base_list=(
    "http://127.0.0.1:59312"
    "http://127.0.0.1:59315"
    "http://127.0.0.1:59221"
    "http://127.0.0.1:59313"
    "http://127.0.0.1:59320"
    "http://127.0.0.1:59321/wordle"
    "http://127.0.0.1:59322/maze"
    "http://127.0.0.1:59229"
    "http://127.0.0.1:59213"
    "http://127.0.0.1:59214"
    "http://127.0.0.1:59216"
    "http://127.0.0.1:59215"
    "http://127.0.0.1:59217"
    "http://127.0.0.1:59210"
)


for ((ITER = 0; ITER < iter_num; ITER++))
do
    iter_save_path="${output_dir}/iter_${ITER}"
    mkdir -p "${iter_save_path}"
    
    # Step 1: Train
    accelerate launch \
            --config_file "${config_file}" \
            --num_processes=${num_processes} \
            --main_process_port=${main_process_port} \
        train_agentevol.py \
                --train_file ${iter_data_path}/train_iter_${ITER}.json \
                --inference_file ${test_file_list[0]} \
                --test_file ${test_file_list[0]} \
                --iter_num ${ITER} \
                --iter_data_path ${iter_data_path} \
                --model_train_path ${model_train_path} \
                --model_save_path ${iter_save_path}/model \
                --task_name ${task_list[0]} \
                --batch_size ${batch_size} \
                --eval_batch_size ${eval_batch_size} \
                --n_epochs ${n_epochs} \
                --num_workers ${num_workers} \
                --learning_rate ${learning_rate} \
                --weight_decay ${weight_decay} \
                --warmup_step ${warmup_step} \
                --clip_grad_norm ${clip_grad_norm} \
                --logging_epoch_freq ${logging_epoch_freq} \
                --logging_step_freq ${logging_step_freq} \
                --saving_epoch_freq ${saving_epoch_freq} \
                --evaluating_epoch_freq ${evaluating_epoch_freq} \
                --seed ${seed} \
                --max_input_length ${max_input_length} \
                --sample_num ${sample_num} \
                --max_round ${max_round_list[0]} \
                --gradient_accumulation_steps ${gradient_accumulation_steps} \
                --wandb_log ${wandb_log} \
                --wandb_project ${wandb_project} \
                --wandb_run_name ${wandb_run_name} \
                --env_server_base ${env_server_base_list[0]} \
                --data_len ${data_len} \
                --timeout ${timeout} \
                > ${iter_save_path}/train_iter_${ITER}.log 2>&1
    
    # Step 2: Distributed evaluation on test dataset
    for index in {0..7};
    do
        cur_task=${task_list[$index]}
        cur_port=$((main_process_port + index))
        cur_test_file="${test_file_list[$index]}"
        cur_max_round=${max_round_list[$index]}
        cur_env_server_base=${env_server_base_list[$index]}
        cur_eval_output_file="${iter_save_path}/eval_iter_${ITER}_task_${cur_task}.jsonl"

        accelerate launch \
                --config_file ${config_file} \
                --num_processes=${num_processes} \
                --main_process_port=${cur_port} \
            ../../utils/distributed_eval_task.py \
                    --model_path ${iter_save_path}/model \
                    --output_file ${cur_eval_output_file} \
                    --inference_file ${cur_test_file} \
                    --task_name ${cur_task} \
                    --eval_batch_size ${eval_batch_size} \
                    --num_workers ${num_workers} \
                    --seed ${seed} \
                    --do_sample False \
                    --max_round ${cur_max_round} \
                    --env_server_base ${cur_env_server_base} \
                    --data_len ${data_len} \
                    --timeout ${timeout} \
                    > ${iter_save_path}/eval_${cur_task}.log 2>&1
    done

    # Step 2: Single process evaluation on test dataset
    for index in {8..12};
    do
        cur_task=${task_list[$index]}
        cur_test_file="${test_file_list[$index]}"
        cur_max_round=${max_round_list[$index]}
        cur_env_server_base=${env_server_base_list[$index]}
        cur_eval_output_file="${iter_save_path}/eval_iter_${ITER}_task_${cur_task}.jsonl"
        python -u base_eval_template.py \
                --model_path ${iter_save_path}/model \
                --data_path  ${cur_test_file} \
                --output_file ${cur_eval_output_file} \
                --task_name ${cur_task} \
                --seed ${seed} \
                --max_round ${cur_max_round} \
                --env_server_base ${cur_env_server_base} \
                > ${iter_save_path}/eval_${cur_task}.log 2>&1
    done


    # Step 3: Distributed inference on exploration dataset
    inference_output_file=${iter_save_path}/inference_iter_${ITER}.jsonl
    for index in {0..7};
    do
        cur_task=${task_list[$index]}
        cur_port=$((main_process_port + index))
        cur_inference_file=./small_exploration_data/${inference_file_list[$index]}
        cur_max_round=${max_round_list[$index]}
        cur_env_server_base=${env_server_base_list[$index]}
        cur_inference_output_file=${iter_save_path}/inference_${cur_task}_iter_${ITER}.jsonl

        accelerate launch \
                --config_file ${config_file} \
                --num_processes=${num_processes} \
                --main_process_port=${cur_port} \
            ../../utils/distributed_eval_task.py \
                    --model_path ${iter_save_path}/model \
                    --output_file ${cur_inference_output_file} \
                    --inference_file ${cur_inference_file} \
                    --task_name ${cur_task} \
                    --eval_batch_size ${eval_batch_size} \
                    --num_workers ${num_workers} \
                    --seed ${seed} \
                    --do_sample False \
                    --max_round ${cur_max_round} \
                    --env_server_base ${cur_env_server_base} \
                    --data_len ${data_len} \
                    --timeout ${timeout} \
                    > ${iter_save_path}/inference_${cur_task}.log 2>&1
    done
    
    # Step 3: Single process inference on exploration dataset
    for index in {8..10};
    do
        cur_task=${task_list[$index]}
        cur_inference_file=./small_exploration_data/${inference_file_list[$index]}
        cur_max_round=${max_round_list[$index]}
        cur_env_server_base=${env_server_base_list[$index]}
        cur_inference_output_file=${iter_save_path}/inference_${cur_task}_iter_${ITER}.jsonl

        python -u base_eval_template.py \
                --model_path ${iter_save_path}/model \
                --data_path  ${cur_inference_file} \
                --output_file ${cur_inference_output_file} \
                --task_name ${cur_task} \
                --seed ${seed} \
                --max_round ${cur_max_round} \
                --env_server_base ${cur_env_server_base} \
                > ${iter_save_path}/inference_${cur_task}.log 2>&1
    done


    # Step 4: Filter
    next_iter_file=${iter_data_path}/train_iter_$((ITER + 1)).json
    python ../../utils/agentevol_filter.py \
        --inference_output_file_path ${iter_save_path} \
        --cur_iter_file ${iter_data_path}/train_iter_${ITER}.json \
        --next_iter_file ${next_iter_file} \
        --add_original_data True \
        > ${iter_save_path}/filter.log 2>&1
done