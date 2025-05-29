# frozen_string_literal: true

require 'test_helper'
require 'open-uri'
require 'open3'

class TestWebRI < Minitest::Test

  # Housekeeping.

  def test_help
    webri_session('', '--help') do |stdin, stdout, stderr|
      output = read(stdout)
      assert_match('Usage: webri [options] name', output)
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
      output = read(stdout)
      assert_match(/Found one class or module name starting with '#{name}'./, output)
      check_web_page(output)
    end
  end

  def test_class_all_choices
    name = 'Nosuch' # Should offer all choices and open chosen page.
    webri_session(name) do |stdin, stdout, stderr|
      output = read(stdout)
      assert_match(/Found no class or module name starting with '#{name}'./, output)
      assert_match(/Show names of all \d+ classes and modules?/, output)
      check_choices(stdin, stdout, output)
      writeln(stdin, '0')
      output = read(stdout)
      check_web_page(output)
    end
  end

  def test_class_multiple_choices
    name = 'Ar'
    webri_session(name) do |stdin, stdout, stderr|
      output = read(stdout)
      assert_match(/Found \d+ class and module names starting with '#{name}'./, output)
      check_choices(stdin, stdout, output)
      writeln(stdin, '0')
      output = read(stdout)
      check_web_page(output)
    end
  end

  def test_class_one_choice
    name = 'Arr'
    webri_session(name) do |stdin, stdout, stderr|
      output = read(stdout)
      assert_match(/Found one class or module name starting with '#{name}'./, output)
      writeln(stdin, 'y')
      output = read(stdout)
      check_web_page(output)
    end
  end

  # Files.

  def test_file_no_choice
    short_name = 'yjit'
    name = "ruby:#{short_name}" # Should offer no choices and open page immediately.
    webri_session(name) do |stdin, stdout, stderr|
      output = read(stdout)
      assert_match(/Found one file name starting with '#{short_name}'./, output)
      check_web_page(output)
    end
  end

  def test_file_all_choices
    short_name = 'nosuch'
    name = "ruby:#{short_name}" # Should offer all choices and open chosen page.
    webri_session(name) do |stdin, stdout, stderr|
      output = read(stdout)
      assert_match(/Found no file name starting with '#{short_name}'./, output)
      assert_match(/Show names of all \d+ files?/, output)
      check_choices(stdin, stdout, output)
      writeln(stdin, '0')
      output = read(stdout)
      check_web_page(output)
    end
  end

  def test_file_multiple_choices_multiple_entries
    short_name = 'c'
    name = "ruby:#{short_name}" # Should offer multiple choices and open chosen page.
    webri_session(name) do |stdin, stdout, stderr|
      output = read(stdout)
      assert_match(/Found \d+ file names starting with '#{short_name}'./, output)
      check_choices(stdin, stdout, output)
      writeln(stdin, '0')
      output = read(stdout)
      check_web_page(output)
    end
  end

  def test_file_multiple_choices_one_entry_multiple_choices
    short_name = 'method'
    name = "ruby:#{short_name}" # Should offer multiple choices and open chosen page.
    webri_session(name) do |stdin, stdout, stderr|
      output = read(stdout)
      output.match(/(\d+)/)
      # This test is for a file name that has multiple paths.
      # Check whether it's so for the given file name.
      # If not, we need to change the file name for this test.
      choice_count = $1.to_i
      assert_operator(choice_count, :>, 1, 'File name should have multiple paths.')
      assert_match(/Found \d+ file names starting with '#{short_name}'./, output)
      check_choices(stdin, stdout, output)
      writeln(stdin, '0')
      output = read(stdout)
      check_web_page(output)
    end
  end

  def test_file_one_choice
    short_name = 'yji'
    name = "ruby:#{short_name}" # Should offer one choice and open page if requested.
    webri_session(name) do |stdin, stdout, stderr|
      output = read(stdout)
      assert_match(/Found one file name starting with '#{short_name}'./, output)
      writeln(stdin, 'y')
      output = read(stdout)
      check_web_page(output)
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

  def check_choices(stdin, stdout, output)
    # String argument output must contain the count of choices.
    output.match(/(\d+)/)
    choice_count = $1.to_i
    assert_operator(choice_count, :>, 1)
    writeln(stdin, 'y')
    # Verify the choices.
    # Each choice line ends with newline, so use readline.
    for i in 0...choice_count do
      output = stdout.readline
      assert_match("#{i}:", output)
    end
    # Cannot use readline for this because it has no trailing newline.
    output = read(stdout)
    assert_match(/^Choose/, output)
  end

  def check_web_page(output)
    lines = output.split("\n")
    case lines.size
    when 5
      # Two extra lines: 'Found', and what was found.
      found_line = lines.shift
      assert_match(/Found/, found_line)
      page_line = lines.shift
      assert_match(/\.html/, page_line)
    when 3
    else
      assert(false, 'Trailing line count not 3 or 5.')
      return
    end
    web_line = lines.shift
    assert_match(/Web page:/, web_line)
    url_line = lines.shift
    returned_value = URI.open(url_line.chomp.strip)
    classes = [Tempfile, StringIO]
    assert(classes.include?(returned_value.class))
    command_line = lines.shift
    assert_match(/Command:/, command_line)
  end

  def read(stdout)
    stdout.readpartial(4096)
  end

  def writeln(stdin, s)
    stdin.write(s + "\n")
  end
end
