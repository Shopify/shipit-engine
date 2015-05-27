# encoding: UTF-8
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

ActiveRecord::Schema.define(version: 20150518214944) do

  create_table "api_clients", force: :cascade do |t|
    t.text     "permissions", limit: 65535
    t.integer  "creator_id",  limit: 4
    t.datetime "created_at",                             null: false
    t.datetime "updated_at",                             null: false
    t.string   "name",        limit: 255,   default: ""
    t.integer  "stack_id",    limit: 4
  end

  add_index "api_clients", ["creator_id"], name: "index_api_clients_on_creator_id", using: :btree

  create_table "commits", force: :cascade do |t|
    t.integer  "stack_id",     limit: 4,                     null: false
    t.integer  "author_id",    limit: 4,                     null: false
    t.integer  "committer_id", limit: 4,                     null: false
    t.string   "sha",          limit: 40,                    null: false
    t.text     "message",      limit: 65535,                 null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "detached", default: false, null: false
    t.datetime "authored_at",                                null: false
    t.datetime "committed_at",                               null: false
    t.integer  "additions",    limit: 4
    t.integer  "deletions",    limit: 4
  end

  add_index "commits", ["author_id"], name: "index_commits_on_author_id", using: :btree
  add_index "commits", ["committer_id"], name: "index_commits_on_committer_id", using: :btree
  add_index "commits", ["created_at"], name: "index_commits_on_created_at", using: :btree
  add_index "commits", ["stack_id"], name: "index_commits_on_stack_id", using: :btree

  create_table "deliveries", force: :cascade do |t|
    t.integer  "hook_id",          limit: 4,                            null: false
    t.string   "status",           limit: 255,      default: "pending", null: false
    t.string   "url",              limit: 4096,                         null: false
    t.string   "content_type",     limit: 255,                          null: false
    t.string   "event",            limit: 255,                          null: false
    t.text     "payload",          limit: 16777215,                     null: false
    t.integer  "response_code",    limit: 4
    t.text     "response_headers", limit: 65535
    t.text     "response_body",    limit: 65535
    t.datetime "delivered_at"
    t.datetime "created_at",                                            null: false
    t.datetime "updated_at",                                            null: false
  end

  create_table "github_hooks", force: :cascade do |t|
    t.integer  "stack_id",     limit: 4
    t.integer  "github_id",    limit: 4
    t.string   "event",        limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "secret",       limit: 255
    t.string   "api_url",      limit: 255
    t.string   "type",         limit: 255
    t.string   "organization", limit: 255
  end

  add_index "github_hooks", ["organization", "event"], name: "index_github_hooks_on_organization_and_event", unique: true, using: :btree
  add_index "github_hooks", ["stack_id", "event"], name: "index_github_hooks_on_stack_id_and_event", unique: true, using: :btree

  create_table "hooks", force: :cascade do |t|
    t.integer  "stack_id",     limit: 4
    t.string   "url",          limit: 4096,                  null: false
    t.string   "content_type", limit: 4,    default: "json", null: false
    t.string   "secret",       limit: 255
    t.string   "events",       limit: 255,  default: "",     null: false
    t.boolean  "insecure_ssl", default: false,  null: false
    t.datetime "created_at",                                 null: false
    t.datetime "updated_at",                                 null: false
  end

  add_index "hooks", ["stack_id"], name: "index_hooks_on_stack_id", using: :btree

  create_table "memberships", force: :cascade do |t|
    t.integer  "team_id",    limit: 4
    t.integer  "user_id",    limit: 4
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
  end

  add_index "memberships", ["team_id", "user_id"], name: "index_memberships_on_team_id_and_user_id", unique: true, using: :btree
  add_index "memberships", ["user_id"], name: "index_memberships_on_user_id", using: :btree

  create_table "output_chunks", force: :cascade do |t|
    t.integer  "task_id",    limit: 4
    t.text     "text",       limit: 16777215
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "output_chunks", ["task_id"], name: "index_output_chunks_on_task_id", using: :btree

  create_table "stacks", force: :cascade do |t|
    t.string   "repo_name",                limit: 255,                          null: false
    t.string   "repo_owner",               limit: 255,                          null: false
    t.string   "environment",              limit: 255,   default: "production", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "branch",                   limit: 255,   default: "master",     null: false
    t.string   "deploy_url",               limit: 255
    t.string   "lock_reason",              limit: 255
    t.integer  "tasks_count",              limit: 4,     default: 0,            null: false
    t.boolean  "continuous_deployment",    default: false,        null: false
    t.integer  "undeployed_commits_count", limit: 4,     default: 0,            null: false
    t.text     "cached_deploy_spec",       limit: 65535
    t.integer  "lock_author_id",           limit: 4
    t.boolean  "ignore_ci"
  end

  add_index "stacks", ["repo_owner", "repo_name", "environment"], name: "stack_unicity", unique: true, using: :btree

  create_table "statuses", force: :cascade do |t|
    t.string   "state",       limit: 255
    t.string   "target_url",  limit: 255
    t.text     "description", limit: 65535
    t.string   "context",     limit: 255,   default: "default", null: false
    t.integer  "commit_id",   limit: 4
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "statuses", ["commit_id"], name: "index_statuses_on_commit_id", using: :btree

  create_table "tasks", force: :cascade do |t|
    t.integer  "stack_id",        limit: 4,                            null: false
    t.integer  "since_commit_id", limit: 4,                            null: false
    t.integer  "until_commit_id", limit: 4,                            null: false
    t.string   "status",          limit: 255,      default: "pending", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id",         limit: 4
    t.boolean  "rolled_up",       default: false,     null: false
    t.string   "type",            limit: 255
    t.integer  "parent_id",       limit: 4
    t.integer  "additions",       limit: 4,        default: 0
    t.integer  "deletions",       limit: 4,        default: 0
    t.text     "definition",      limit: 65535
    t.binary   "gzip_output",     limit: 16777215
  end

  add_index "tasks", ["rolled_up", "created_at", "status"], name: "index_tasks_on_rolled_up_and_created_at_and_status", using: :btree
  add_index "tasks", ["since_commit_id"], name: "index_tasks_on_since_commit_id", using: :btree
  add_index "tasks", ["stack_id"], name: "index_tasks_on_stack_id", using: :btree
  add_index "tasks", ["until_commit_id"], name: "index_tasks_on_until_commit_id", using: :btree
  add_index "tasks", ["user_id"], name: "index_tasks_on_user_id", using: :btree

  create_table "teams", force: :cascade do |t|
    t.integer  "github_id",    limit: 4
    t.string   "api_url",      limit: 255
    t.string   "slug",         limit: 255
    t.string   "name",         limit: 255
    t.string   "organization", limit: 255
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
  end

  add_index "teams", ["organization", "slug"], name: "index_teams_on_organization_and_slug", unique: true, using: :btree

  create_table "users", force: :cascade do |t|
    t.integer  "github_id",  limit: 4
    t.string   "name",       limit: 255, null: false
    t.string   "email",      limit: 255
    t.string   "login",      limit: 255
    t.string   "api_url",    limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "avatar_url", limit: 255
  end

  add_index "users", ["login"], name: "index_users_on_login", using: :btree

  add_foreign_key "memberships", "teams"
  add_foreign_key "memberships", "users"
end
