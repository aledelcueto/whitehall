#!/usr/bin/env rake
# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

# Our test suite generates ~17MB of logs at log level :info, switching
# to log level :warn reduces logging and increases execution speed.
ENV["LOG_LEVEL"] = "warn"

ENV['GOVUK_APP_DOMAIN'] = 'dev.gov.uk' unless ENV['GOVUK_APP_DOMAIN']

require File.expand_path('../config/application', __FILE__)
require 'ci/reporter/rake/minitest' if Rails.env.development? or Rails.env.test?

Knapsack.load_tasks if defined?(Knapsack)
Whitehall::Application.load_tasks
