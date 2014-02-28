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

ActiveRecord::Schema.define(version: 20140228013139) do

  create_table "commits", force: true do |t|
    t.integer  "stack_id",                null: false
    t.integer  "author_id",               null: false
    t.integer  "committer_id",            null: false
    t.string   "sha",          limit: 40, null: false
    t.string   "message",                 null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "state"
  end

  add_index "commits", ["author_id"], name: "index_commits_on_author_id"
  add_index "commits", ["committer_id"], name: "index_commits_on_committer_id"
  add_index "commits", ["stack_id"], name: "index_commits_on_stack_id"

  create_table "deploys", force: true do |t|
    t.integer  "stack_id",        null: false
    t.integer  "since_commit_id", null: false
    t.integer  "until_commit_id", null: false
    t.string   "status"
    t.text     "output"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "deploys", ["since_commit_id"], name: "index_deploys_on_since_commit_id"
  add_index "deploys", ["stack_id"], name: "index_deploys_on_stack_id"
  add_index "deploys", ["until_commit_id"], name: "index_deploys_on_until_commit_id"

  create_table "output_chunks", force: true do |t|
    t.integer  "deploy_id"
    t.text     "text"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "output_chunks", ["deploy_id"], name: "index_output_chunks_on_deploy_id"

  create_table "stacks", force: true do |t|
    t.string   "repo_name",                          null: false
    t.string   "repo_owner",                         null: false
    t.string   "environment", default: "production", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "branch",      default: "master",     null: false
  end

  add_index "stacks", ["repo_owner", "repo_name", "environment"], name: "stack_unicity", unique: true

  create_table "users", force: true do |t|
    t.integer  "github_id"
    t.string   "name",       null: false
    t.string   "email",      null: false
    t.string   "login"
    t.string   "api_url"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
