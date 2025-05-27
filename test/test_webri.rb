# frozen_string_literal: true

require 'test_helper'
require 'open-uri'
require 'open3'

class TestWebRI < Minitest::Test

  def test_that_it_has_a_version_number
    refute_nil WebRI::VERSION
  end

  def zzz_test_foo
    out = system('ruby ./bin/webri Foo')
    puts out
  end

  def webri_session(name)
    command = "ruby -d bin/webri #{name}"
    Open3.popen3(command) do |stdin, stdout, stderr, wait_thread|
      yield stdin, stdout, stderr
    end

  end

  def test_file_multiple_choices
    webri_session('ruby:c') do |stdin, stdout, stderr|
      out = stdout.readpartial(4096)
      assert_match(/file names starting with/, out)
      stdin.write_nonblock("y\n")
      out = stdout.readpartial(4096)
      assert_match(/Choose/, out)
      stdin.write_nonblock("0\n")
      out = stdout.readpartial(4096)
      assert_match(/Opening/, out)
    end
  end

  def zzz_test_foo
    Open3.popen3('ruby bin/webri ruby:c') do |stdin, stdout, stderr, wait_thread|
      puts stdout.readpartial(4096)
      stdin.write_nonblock("y\n")
      puts stdout.readpartial(4096)
      stdin.write_nonblock("2\n")
    end

  end
end
