# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2020_07_16_204019) do

  create_table "api_clients", force: :cascade do |t|
    t.text "permissions", limit: 65535
    t.integer "creator_id", limit: 4
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name", limit: 255, default: ""
    t.integer "stack_id", limit: 4
    t.index ["creator_id"], name: "index_api_clients_on_creator_id"
  end

  create_table "check_runs", force: :cascade do |t|
    t.integer "stack_id", null: false
    t.integer "commit_id", null: false
    t.bigint "github_id", null: false
    t.string "name", null: false
    t.string "conclusion", limit: 20
    t.string "title", limit: 1024
    t.string "details_url"
    t.string "html_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["commit_id"], name: "index_check_runs_on_commit_id"
    t.index ["github_id", "commit_id"], name: "index_check_runs_on_github_id_and_commit_id", unique: true
    t.index ["stack_id"], name: "index_check_runs_on_stack_id"
  end

  create_table "commit_deployment_statuses", force: :cascade do |t|
    t.integer "commit_deployment_id"
    t.string "status"
    t.integer "github_id"
    t.string "api_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["commit_deployment_id"], name: "index_commit_deployment_statuses_on_commit_deployment_id"
  end

  create_table "commit_deployments", force: :cascade do |t|
    t.integer "commit_id"
    t.integer "task_id"
    t.integer "github_id"
    t.string "api_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "sha", limit: 40
    t.index ["commit_id", "task_id"], name: "index_commit_deployments_on_commit_id_and_task_id", unique: true
    t.index ["task_id"], name: "index_commit_deployments_on_task_id"
  end

  create_table "commits", force: :cascade do |t|
    t.integer "stack_id", limit: 4, null: false
    t.integer "author_id", limit: 4
    t.integer "committer_id", limit: 4
    t.string "sha", limit: 40, null: false
    t.text "message", limit: 65535, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "detached", default: false, null: false
    t.datetime "authored_at", null: false
    t.datetime "committed_at", null: false
    t.integer "additions", limit: 4
    t.integer "deletions", limit: 4
    t.integer "pull_request_number"
    t.string "pull_request_title", limit: 1024
    t.integer "pull_request_id"
    t.boolean "locked", default: false, null: false
    t.integer "lock_author_id", limit: 4
    t.string "pull_request_head_sha", limit: 40
    t.index ["author_id"], name: "index_commits_on_author_id"
    t.index ["committer_id"], name: "index_commits_on_committer_id"
    t.index ["created_at"], name: "index_commits_on_created_at"
    t.index ["sha", "stack_id"], name: "index_commits_on_sha_and_stack_id", unique: true
    t.index ["stack_id"], name: "index_commits_on_stack_id"
  end

  create_table "deliveries", force: :cascade do |t|
    t.integer "hook_id", limit: 4, null: false
    t.string "status", limit: 50, default: "pending", null: false
    t.string "url", limit: 4096, null: false
    t.string "content_type", limit: 255, null: false
    t.string "event", limit: 50, null: false
    t.text "payload", limit: 16777215, null: false
    t.integer "response_code", limit: 4
    t.text "response_headers", limit: 65535
    t.text "response_body", limit: 65535
    t.datetime "delivered_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hook_id", "event", "status"], name: "index_deliveries_on_hook_id_and_event_and_status"
    t.index ["hook_id", "status"], name: "index_deliveries_on_hook_id_and_status"
  end

  create_table "github_hooks", force: :cascade do |t|
    t.integer "stack_id", limit: 4
    t.integer "github_id", limit: 4
    t.string "event", limit: 50, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "secret", limit: 255
    t.string "api_url", limit: 255
    t.string "type", limit: 255
    t.string "organization", limit: 39
    t.index ["organization", "event"], name: "index_github_hooks_on_organization_and_event", unique: true
    t.index ["stack_id", "event"], name: "index_github_hooks_on_stack_id_and_event", unique: true
  end

  create_table "hooks", force: :cascade do |t|
    t.integer "stack_id", limit: 4
    t.string "delivery_url", limit: 4096, null: false
    t.string "content_type", limit: 4, default: "json", null: false
    t.string "secret", limit: 255
    t.string "events", limit: 255, default: "", null: false
    t.boolean "insecure_ssl", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["stack_id"], name: "index_hooks_on_stack_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.integer "team_id", limit: 4
    t.integer "user_id", limit: 4
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["team_id", "user_id"], name: "index_memberships_on_team_id_and_user_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "output_chunks", force: :cascade do |t|
    t.integer "task_id", limit: 4
    t.text "text", limit: 16777215
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["task_id"], name: "index_output_chunks_on_task_id"
  end

  create_table "pull_request_assignments", force: :cascade do |t|
    t.integer "pull_request_id"
    t.integer "user_id"
    t.index ["pull_request_id"], name: "index_pull_request_assignments_on_pull_request_id"
    t.index ["user_id"], name: "index_pull_request_assignments_on_user_id"
  end

  create_table "pull_requests", force: :cascade do |t|
    t.integer "stack_id", null: false
    t.integer "number", null: false
    t.string "title", limit: 256
    t.integer "github_id", limit: 8
    t.string "api_url", limit: 1024
    t.string "state"
    t.integer "head_id"
    t.boolean "mergeable"
    t.integer "additions", default: 0, null: false
    t.integer "deletions", default: 0, null: false
    t.string "merge_status", limit: 30, null: false
    t.string "rejection_reason"
    t.datetime "merge_requested_at"
    t.integer "merge_requested_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "branch"
    t.datetime "revalidated_at"
    t.datetime "merged_at"
    t.string "base_ref", limit: 1024
    t.integer "base_commit_id"
    t.integer "user_id"
    t.boolean "review_request", default: false
    t.index ["head_id"], name: "index_pull_requests_on_head_id"
    t.index ["merge_requested_by_id"], name: "index_pull_requests_on_merge_requested_by_id"
    t.index ["merge_status"], name: "index_pull_requests_on_merge_status"
    t.index ["stack_id", "github_id"], name: "index_pull_requests_on_stack_id_and_github_id", unique: true
    t.index ["stack_id", "merge_status"], name: "index_pull_requests_on_stack_id_and_merge_status"
    t.index ["stack_id", "number"], name: "index_pull_requests_on_stack_id_and_number", unique: true
    t.index ["stack_id"], name: "index_pull_requests_on_stack_id"
    t.index ["user_id"], name: "index_pull_requests_on_user_id"
  end

  create_table "release_statuses", force: :cascade do |t|
    t.integer "stack_id", null: false
    t.integer "commit_id", null: false
    t.integer "user_id"
    t.string "state", limit: 10, null: false
    t.string "description", limit: 1024
    t.string "target_url", limit: 1024
    t.bigint "github_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["commit_id", "github_id"], name: "index_deploy_statuses_on_commit_id_and_github_id"
    t.index ["stack_id", "commit_id"], name: "index_deploy_statuses_on_stack_id_and_commit_id"
    t.index ["user_id"], name: "index_deploy_statuses_on_user_id"
  end

  create_table "repositories", force: :cascade do |t|
    t.string "owner", limit: 39, null: false
    t.string "name", limit: 100, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.boolean "review_stacks_enabled", default: false
    t.integer "provisioning_behavior", default: 0
    t.string "provisioning_label_name"
    t.index ["owner", "name"], name: "repository_unicity", unique: true
  end

  create_table "stacks", force: :cascade do |t|
    t.string "environment", limit: 50, default: "production", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "branch", limit: 255, default: "master", null: false
    t.string "deploy_url", limit: 255
    t.string "lock_reason", limit: 4096
    t.integer "tasks_count", limit: 4, default: 0, null: false
    t.boolean "continuous_deployment", default: false, null: false
    t.integer "undeployed_commits_count", limit: 4, default: 0, null: false
    t.text "cached_deploy_spec", limit: 65535
    t.integer "lock_author_id", limit: 4
    t.boolean "ignore_ci"
    t.datetime "inaccessible_since"
    t.integer "estimated_deploy_duration", default: 1, null: false
    t.datetime "continuous_delivery_delayed_since"
    t.datetime "locked_since"
    t.boolean "merge_queue_enabled", default: false, null: false
    t.datetime "last_deployed_at"
    t.integer "repository_id", null: false
    t.datetime "archived_since"
    t.string "lock_reason_code"
    t.string "provision_status", default: "deprovisioned", null: false
    t.string "type", default: "Shipit::Stack"
    t.index ["archived_since"], name: "index_stacks_on_archived_since"
    t.index ["lock_reason_code"], name: "index_stacks_on_lock_reason_code"
    t.index ["provision_status"], name: "index_stacks_on_provision_status"
    t.index ["repository_id", "environment"], name: "stack_unicity", unique: true
    t.index ["repository_id"], name: "index_stacks_on_repository_id"
    t.index ["type"], name: "index_stacks_on_type"
  end

  create_table "statuses", force: :cascade do |t|
    t.string "state", limit: 255
    t.string "target_url", limit: 255
    t.text "description", limit: 65535
    t.string "context", limit: 255, default: "default", null: false
    t.integer "commit_id", limit: 4
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "stack_id", null: false
    t.index ["commit_id"], name: "index_statuses_on_commit_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.integer "stack_id", limit: 4, null: false
    t.integer "since_commit_id", limit: 4
    t.integer "until_commit_id", limit: 4
    t.string "status", limit: 10, default: "pending", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "user_id", limit: 4
    t.boolean "rolled_up", default: false, null: false
    t.string "type", limit: 20
    t.integer "parent_id", limit: 4
    t.integer "additions", limit: 4, default: 0
    t.integer "deletions", limit: 4, default: 0
    t.text "definition", limit: 65535
    t.binary "gzip_output"
    t.boolean "rollback_once_aborted", default: false, null: false
    t.text "env"
    t.integer "confirmations", default: 0, null: false
    t.boolean "allow_concurrency", default: false, null: false
    t.datetime "started_at"
    t.datetime "ended_at"
    t.boolean "ignored_safeties", default: false, null: false
    t.integer "aborted_by_id"
    t.integer "rollback_once_aborted_to_id"
    t.index ["rolled_up", "created_at", "status"], name: "index_tasks_on_rolled_up_and_created_at_and_status"
    t.index ["since_commit_id"], name: "index_tasks_on_since_commit_id"
    t.index ["stack_id", "allow_concurrency", "status"], name: "index_active_tasks"
    t.index ["stack_id", "allow_concurrency"], name: "index_tasks_on_stack_id_and_allow_concurrency"
    t.index ["stack_id", "status", "type"], name: "index_tasks_by_stack_and_status"
    t.index ["status"], name: "index_tasks_on_status"
    t.index ["type", "stack_id", "parent_id"], name: "index_tasks_by_stack_and_parent"
    t.index ["until_commit_id"], name: "index_tasks_on_until_commit_id"
    t.index ["user_id"], name: "index_tasks_on_user_id"
  end

  create_table "teams", force: :cascade do |t|
    t.integer "github_id", limit: 4
    t.string "api_url", limit: 255
    t.string "slug", limit: 50
    t.string "name", limit: 255
    t.string "organization", limit: 39
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization", "slug"], name: "index_teams_on_organization_and_slug", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.integer "github_id", limit: 4
    t.string "name", limit: 255, null: false
    t.string "email", limit: 255
    t.string "login", limit: 39
    t.string "api_url", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "avatar_url", limit: 255
    t.string "encrypted_github_access_token"
    t.string "encrypted_github_access_token_iv"
    t.index ["github_id"], name: "index_users_on_github_id"
    t.index ["login"], name: "index_users_on_login"
    t.index ["updated_at"], name: "index_users_on_updated_at"
  end

end
