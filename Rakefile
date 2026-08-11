# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create

desc "Generate documentation"
task :doc do
  `ruby bin/build_doc`
  Dir.chdir('doc/markdown') do
    `rdoc --op ../html .`
  end
end

task default: :test
