# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20170130113633) do

  create_table "api_clients", force: :cascade do |t|
    t.text     "permissions", limit: 65535
    t.integer  "creator_id",  limit: 4
    t.datetime "created_at",                             null: false
    t.datetime "updated_at",                             null: false
    t.string   "name",        limit: 255,   default: ""
    t.integer  "stack_id",    limit: 4
    t.index ["creator_id"], name: "index_api_clients_on_creator_id"
  end

  create_table "commit_deployment_statuses", force: :cascade do |t|
    t.integer  "commit_deployment_id"
    t.string   "status"
    t.integer  "github_id"
    t.string   "api_url"
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
    t.index ["commit_deployment_id"], name: "index_commit_deployment_statuses_on_commit_deployment_id"
  end

  create_table "commit_deployments", force: :cascade do |t|
    t.integer  "commit_id"
    t.integer  "task_id"
    t.integer  "github_id"
    t.string   "api_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["commit_id", "task_id"], name: "index_commit_deployments_on_commit_id_and_task_id", unique: true
    t.index ["task_id"], name: "index_commit_deployments_on_task_id"
  end

  create_table "commits", force: :cascade do |t|
    t.integer  "stack_id",     limit: 4,                     null: false
    t.integer  "author_id",    limit: 4,                     null: false
    t.integer  "committer_id", limit: 4,                     null: false
    t.string   "sha",          limit: 40,                    null: false
    t.text     "message",      limit: 65535,                 null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "detached",                   default: false, null: false
    t.datetime "authored_at",                                null: false
    t.datetime "committed_at",                               null: false
    t.integer  "additions",    limit: 4
    t.integer  "deletions",    limit: 4
    t.index ["author_id"], name: "index_commits_on_author_id"
    t.index ["committer_id"], name: "index_commits_on_committer_id"
    t.index ["created_at"], name: "index_commits_on_created_at"
    t.index ["stack_id"], name: "index_commits_on_stack_id"
  end

  create_table "deliveries", force: :cascade do |t|
    t.integer  "hook_id",          limit: 4,                            null: false
    t.string   "status",           limit: 50,       default: "pending", null: false
    t.string   "url",              limit: 4096,                         null: false
    t.string   "content_type",     limit: 255,                          null: false
    t.string   "event",            limit: 50,                           null: false
    t.text     "payload",          limit: 16777215,                     null: false
    t.integer  "response_code",    limit: 4
    t.text     "response_headers", limit: 65535
    t.text     "response_body",    limit: 65535
    t.datetime "delivered_at"
    t.datetime "created_at",                                            null: false
    t.datetime "updated_at",                                            null: false
    t.index ["created_at"], name: "index_deliveries_on_created_at"
    t.index ["hook_id", "event", "status"], name: "index_deliveries_on_hook_id_and_event_and_status"
    t.index ["status", "event"], name: "index_deliveries_on_status_and_event"
  end

  create_table "github_hooks", force: :cascade do |t|
    t.integer  "stack_id",     limit: 4
    t.integer  "github_id",    limit: 4
    t.string   "event",        limit: 50,  null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "secret",       limit: 255
    t.string   "api_url",      limit: 255
    t.string   "type",         limit: 255
    t.string   "organization", limit: 39
    t.index ["organization", "event"], name: "index_github_hooks_on_organization_and_event", unique: true
    t.index ["stack_id", "event"], name: "index_github_hooks_on_stack_id_and_event", unique: true
  end

  create_table "hooks", force: :cascade do |t|
    t.integer  "stack_id",     limit: 4
    t.string   "delivery_url", limit: 4096,                  null: false
    t.string   "content_type", limit: 4,    default: "json", null: false
    t.string   "secret",       limit: 255
    t.string   "events",       limit: 255,  default: "",     null: false
    t.boolean  "insecure_ssl",              default: false,  null: false
    t.datetime "created_at",                                 null: false
    t.datetime "updated_at",                                 null: false
    t.index ["stack_id"], name: "index_hooks_on_stack_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.integer  "team_id",    limit: 4
    t.integer  "user_id",    limit: 4
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
    t.index ["team_id", "user_id"], name: "index_memberships_on_team_id_and_user_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "output_chunks", force: :cascade do |t|
    t.integer  "task_id",    limit: 4
    t.text     "text",       limit: 16777215
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["task_id"], name: "index_output_chunks_on_task_id"
  end

  create_table "pull_requests", force: :cascade do |t|
    t.integer  "stack_id",                                    null: false
    t.integer  "number",                                      null: false
    t.string   "title",              limit: 256
    t.integer  "github_id",          limit: 8
    t.string   "api_url",            limit: 1024
    t.string   "state"
    t.integer  "head_id"
    t.boolean  "mergeable"
    t.integer  "additions",                       default: 0, null: false
    t.integer  "deletions",                       default: 0, null: false
    t.string   "merge_status",                                null: false
    t.datetime "merge_requested_at",                          null: false
    t.datetime "created_at",                                  null: false
    t.datetime "updated_at",                                  null: false
    t.index ["head_id"], name: "index_pull_requests_on_head_id"
    t.index ["stack_id", "github_id"], name: "index_pull_requests_on_stack_id_and_github_id", unique: true
    t.index ["stack_id", "merge_status"], name: "index_pull_requests_on_stack_id_and_merge_status"
    t.index ["stack_id", "number"], name: "index_pull_requests_on_stack_id_and_number", unique: true
    t.index ["stack_id"], name: "index_pull_requests_on_stack_id"
  end

  create_table "stacks", force: :cascade do |t|
    t.string   "repo_name",                         limit: 100,                          null: false
    t.string   "repo_owner",                        limit: 39,                           null: false
    t.string   "environment",                       limit: 50,    default: "production", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "branch",                            limit: 255,   default: "master",     null: false
    t.string   "deploy_url",                        limit: 255
    t.string   "lock_reason",                       limit: 4096
    t.integer  "tasks_count",                       limit: 4,     default: 0,            null: false
    t.boolean  "continuous_deployment",                           default: false,        null: false
    t.integer  "undeployed_commits_count",          limit: 4,     default: 0,            null: false
    t.text     "cached_deploy_spec",                limit: 65535
    t.integer  "lock_author_id",                    limit: 4
    t.boolean  "ignore_ci"
    t.datetime "inaccessible_since"
    t.integer  "estimated_deploy_duration",                       default: 1,            null: false
    t.datetime "continuous_delivery_delayed_since"
    t.datetime "locked_since"
    t.index ["repo_owner", "repo_name", "environment"], name: "stack_unicity", unique: true
  end

  create_table "statuses", force: :cascade do |t|
    t.string   "state",       limit: 255
    t.string   "target_url",  limit: 255
    t.text     "description", limit: 65535
    t.string   "context",     limit: 255,   default: "default", null: false
    t.integer  "commit_id",   limit: 4
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "stack_id",                                      null: false
    t.index ["commit_id"], name: "index_statuses_on_commit_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.integer  "stack_id",              limit: 4,                         null: false
    t.integer  "since_commit_id",       limit: 4,                         null: false
    t.integer  "until_commit_id",       limit: 4,                         null: false
    t.string   "status",                limit: 10,    default: "pending", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id",               limit: 4
    t.boolean  "rolled_up",                           default: false,     null: false
    t.string   "type",                  limit: 20
    t.integer  "parent_id",             limit: 4
    t.integer  "additions",             limit: 4,     default: 0
    t.integer  "deletions",             limit: 4,     default: 0
    t.text     "definition",            limit: 65535
    t.binary   "gzip_output"
    t.boolean  "rollback_once_aborted",               default: false,     null: false
    t.text     "env"
    t.integer  "confirmations",                       default: 0,         null: false
    t.boolean  "allow_concurrency",                   default: false,     null: false
    t.datetime "started_at"
    t.datetime "ended_at"
    t.index ["rolled_up", "created_at", "status"], name: "index_tasks_on_rolled_up_and_created_at_and_status"
    t.index ["since_commit_id"], name: "index_tasks_on_since_commit_id"
    t.index ["stack_id", "allow_concurrency", "status"], name: "index_active_tasks"
    t.index ["type", "stack_id", "parent_id"], name: "index_tasks_by_stack_and_parent"
    t.index ["type", "stack_id", "status"], name: "index_tasks_by_stack_and_status"
    t.index ["until_commit_id"], name: "index_tasks_on_until_commit_id"
    t.index ["user_id"], name: "index_tasks_on_user_id"
  end

  create_table "teams", force: :cascade do |t|
    t.integer  "github_id",    limit: 4
    t.string   "api_url",      limit: 255
    t.string   "slug",         limit: 50
    t.string   "name",         limit: 255
    t.string   "organization", limit: 39
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
    t.index ["organization", "slug"], name: "index_teams_on_organization_and_slug", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.integer  "github_id",                        limit: 4
    t.string   "name",                             limit: 255, null: false
    t.string   "email",                            limit: 255
    t.string   "login",                            limit: 39
    t.string   "api_url",                          limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "avatar_url",                       limit: 255
    t.string   "encrypted_github_access_token"
    t.string   "encrypted_github_access_token_iv"
    t.index ["login"], name: "index_users_on_login"
  end

end
