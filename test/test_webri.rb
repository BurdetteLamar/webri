# frozen_string_literal: true

require 'test_helper'
require 'open-uri'
require 'open3'

class TestWebRI < Minitest::Test

  # Housekeeping.

  def test_help
    webri_session('', '--help') do |stdin, stdout, stderr|
      out = stdout.readpartial(4096)
      assert_match('Usage: webri [options] name', out)
    end
  end

  def test_version
    version = WebRI::VERSION
    assert_match(/\d+\.\d+\.\d+/, version)
  end

  # Errors.

  def test_no_name
    webri_session('') do |stdin, stdout, stderr|
      err = stderr.readpartial(4096)
      assert_match('No name given.', err)
    end
  end

  # Classes and modules.

  def test_class_no_choice
    name = 'Array'
    webri_session(name) do |stdin, stdout, stderr|
      out = stdout.readpartial(4096)
      assert_match(/Found one class or module name starting with '#{name}'./, out)
      assert_match('Web page:', out)
    end
  end

  def test_class_all_choices
    name = 'Nosuch' # Should offer all choices and open chosen page.
    webri_session(name) do |stdin, stdout, stderr|
      out = stdout.readpartial(4096)
      assert_match(/Found no class or module name starting with '#{name}'./, out)
      assert_match(/Show names of all \d+ classes and modules?/, out)
      check_choices(stdin, stdout, out)
      stdin.write("0\n")
      out = stdout.readpartial(4096)
      assert_match('Web page:', out)
    end
  end

  # Files.

  def test_file_no_choice
    short_name = 'yjit'
    name = "ruby:#{short_name}" # Should offer no choices and open page immediately.
    webri_session(name) do |stdin, stdout, stderr|
      out = stdout.readpartial(4096)
      assert_match(/Found one file name starting with '#{short_name}'./, out)
      assert_match('Web page:', out)
    end
  end

  def test_file_all_choices
    short_name = 'nosuch'
    name = "ruby:#{short_name}" # Should offer all choices and open chosen page.
    webri_session(name) do |stdin, stdout, stderr|
      out = stdout.readpartial(4096)
      assert_match(/Found no file name starting with '#{short_name}'./, out)
      assert_match(/Show names of all \d+ files?/, out)
      check_choices(stdin, stdout, out)
      stdin.write("0\n")
      out = stdout.readpartial(4096)
      assert_match('Web page:', out)
    end
  end

  def test_file_multiple_choices
    short_name = 'c'
    name = "ruby:#{short_name}" # Should offer multiple choices and open chosen page.
    webri_session(name) do |stdin, stdout, stderr|
      out = stdout.readpartial(4096)
      assert_match(/Found \d+ file names starting with '#{short_name}'./, out)
      stdin.write("y\n")
      out = stdout.readpartial(4096)
      assert_match('Choose', out)
      stdin.write("0\n")
      out = stdout.readpartial(4096)
      assert_match('Web page:', out)
    end
  end

  def test_file_one_choice
    short_name = 'yji'
    name = "ruby:#{short_name}" # Should offer one choice and open page if requested.
    webri_session(name) do |stdin, stdout, stderr|
      out = stdout.readpartial(4096)
      assert_match(/Found one file name starting with '#{short_name}'./, out)
      stdin.write("y\n")
      out = stdout.readpartial(4096)
      assert_match('Web page:', out)
    end
  end

  # Infrastructure.

  # Open a webri session and yield its IO streams.
  # Option --noop means don't actually open the web page.
  def webri_session(name, options_s = '--noop')
    command = "ruby bin/webri #{options_s} #{name}"
    Open3.popen3(command) do |stdin, stdout, stderr, wait_thread|
      yield stdin, stdout, stderr
    end
  end

  def check_choices(stdin, stdout, out)
    out.match(/(\d+)/)
    choice_count = $1.to_i
    stdin.write("y\n")
    # Verify that the correct number of choices are offered.
    for i in 0...choice_count do
      out = stdout.readline
      assert_match("#{i}", out)
    end
    # Cannot use readline for this because it has no trailing newline.
    out = stdout.readpartial(4096)
    assert_match(/^Choose/, out)
  end

end
