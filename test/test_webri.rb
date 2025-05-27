# frozen_string_literal: true

require 'test_helper'
require 'open-uri'
require 'open3'

class TestWebRI < Minitest::Test

  def test_that_it_has_a_version_number
    refute_nil WebRI::VERSION
  end

  # Open a webri session and yield its IO streams.
  def webri_session(name)
    command = "ruby bin/webri --noop #{name}"
    Open3.popen3(command) do |stdin, stdout, stderr, wait_thread|
      yield stdin, stdout, stderr
    end

  end

  def test_file_multiple_choices
    short_name = 'c'
    name = "ruby:#{short_name}" # Should offer multiple choices and open chosen page.
    webri_session(name) do |stdin, stdout, stderr|
      out = stdout.readpartial(4096)
      assert_match(/Found \d+ file names starting with '#{short_name}'./, out)
      stdin.write_nonblock("y\n")
      out = stdout.readpartial(4096)
      assert_match(/Choose/, out)
      stdin.write_nonblock("0\n")
      out = stdout.readpartial(4096)
      assert_match(/Web page:/, out)
    end
  end

  def test_file_one_choice
    short_name = 'yji'
    name = "ruby:#{short_name}" # Should offer one choice and open page if requested.
    webri_session(name) do |stdin, stdout, stderr|
      out = stdout.readpartial(4096)
      assert_match(/Found one file name starting with '#{short_name}'./, out)
      stdin.write_nonblock("y\n")
      out = stdout.readpartial(4096)
      assert_match(/Web page:/, out)
    end
  end

  def test_file_no_choice
    short_name = 'yjit'
    name = "ruby:#{short_name}" # Should offer no choices and open page immediately.
    webri_session(name) do |stdin, stdout, stderr|
      out = stdout.readpartial(4096)
      assert_match(/Found one file name starting with '#{short_name}'./, out)
      assert_match(/Web page:/, out)
    end
  end

  def test_file_all_choices
    short_name = 'nosuch'
    name = "ruby:#{short_name}" # Should offer all choices and open chosen page.
    webri_session(name) do |stdin, stdout, stderr|
      out = stdout.readpartial(4096)
      assert_match(/Found no file name starting with '#{short_name}'./, out)
      stdin.write_nonblock("y\n")
      out = stdout.readpartial(8192)
      stdin.write_nonblock("0\n")
      out = stdout.readpartial(4096)
      assert_match(/Web page:/, out)
    end
  end

end
