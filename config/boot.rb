# frozen_string_literal: true

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup' # Set up gems listed in the Gemfile.
# Bootsnap speeds up normal web/listener boots. Administrative runners can
# opt out with DISABLE_BOOTSNAP=1 when investigating a native cache crash,
# preserving a safe diagnostic path without changing the production service.
require 'bootsnap/setup' unless ENV['DISABLE_BOOTSNAP'] == '1'
