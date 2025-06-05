# frozen_string_literal: true

require 'test_helper'
require 'open-uri'
require 'open3'

class TestWebRI < Minitest::Test

  # Housekeeping.

  def test_help
    webri_session('', '--help') do |stdin, stdout, stderr|
      lines = stdout.readlines
      assert_start_with('Usage: webri [options] name', lines[2])
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

  def test_class_exact_name
    name = @@test_names.dig(:class, :full_unique_single_path)
    refute_nil(name)
    webri_session(name) do |stdin, stdout, stderr|
      assert_found_line(stdout,1, :class, name)
      assert_name_line(stdout, name)
      assert_opening_line(stdout, name)
      assert_command_line(stdout, name)
    end
  end

  def zzz_test_class_nosuch_name
    name = @@test_names[:class][:nosuch] # Should offer all choices; open chosen page.
    refute_nil(name)
    webri_session(name) do |stdin, stdout, stderr|
      output = read(stdout)
      assert_match(/Found no class\/module name starting with '#{name}'./, output)
      assert_match(/Show names of all \d+ classes\/modules?/, output)
      check_choices(stdin, stdout, output)
      writeln(stdin, '0')
      output = read(stdout)
      check_web_page(name, output)
    end
  end

  def zzz_test_class_partial_name_ambiguous
    name = @@test_names[:class][:abbrev_multi] # Should offer multiple choices; open chosen choice.
    refute_nil(name)
    webri_session(name) do |stdin, stdout, stderr|
      output = read(stdout)
      assert_match(/Found \d+ class\/module names starting with '#{name}'./, output)
      check_choices(stdin, stdout, output)
      writeln(stdin, '0')
      output = read(stdout)
      check_web_page(name, output)
    end
  end

  def zzz_test_class_partial_name_unambiguous
    name = @@test_names[:class][:abbrev_unique_single_path] # Should offer one choice; open if yes.
    refute_nil(name)
    webri_session(name) do |stdin, stdout, stderr|
      output = read(stdout)
      assert_match(/Found one class\/module name starting with '#{name}'./, output)
      writeln(stdin, 'y')
      output = read(stdout)
      check_web_page(name, output)
    end
  end

  # Files.

  def zzz_test_file_exact_name
    short_name = @@test_names[:file][:full_unique_single_path] # Should open page.
    refute_nil(short_name)
    name = "ruby:#{short_name}"
    webri_session(name) do |stdin, stdout, stderr|
      output = read(stdout)
      assert_match(/Found one file name starting with '#{short_name}'./, output)
      check_web_page(name, output)
    end
  end

  def zzz_test_file_nosuch_name
    short_name = @@test_names[:file][:nosuch]  # Should offer all choices; open chosen page.
    refute_nil(short_name)
    name = "ruby:#{short_name}"
    webri_session(name) do |stdin, stdout, stderr|
      output = read(stdout)
      assert_match(/Found no file name starting with '#{short_name}'./, output)
      assert_match(/Show names of all \d+ files?/, output)
      check_choices(stdin, stdout, output)
      writeln(stdin, '0')
      output = read(stdout)
      check_web_page(name, output)
    end
  end

  def zzz_test_file_partial_name_ambiguous
    short_name = @@test_names[:file][:abbrev_unique_multi_path] # Should offer multiple choices and open chosen page.
    refute_nil(short_name)
    name = "ruby:#{short_name}"
    webri_session(name) do |stdin, stdout, stderr|
      output = read(stdout)
      assert_match(/Found \d+ file names starting with '#{short_name}'./, output)
      check_choices(stdin, stdout, output)
      writeln(stdin, '0')
      output = read(stdout)
      check_web_page(name, output)
    end
  end

  def zzz_test_file_partial_name_unambiguous_multiple_paths
    short_name = @@test_names[:file][:abbrev_unique_multi_path] # Should offer multiple choices and open chosen page.
    refute_nil(short_name)
    name = "ruby:#{short_name}"
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
      check_web_page(name, output)
    end
  end

  def zzz_test_file_partial_name_unambiguous_one_path
    short_name = @@test_names[:file][:abbrev_unique_single_path] # Should offer one choice; open if yes.
    refute_nil(short_name)
    name = "ruby:#{short_name}"
    webri_session(name) do |stdin, stdout, stderr|
      output = read(stdout)
      assert_match(/Found one file name starting with '#{short_name}'./, output)
      writeln(stdin, 'y')
      output = read(stdout)
      check_web_page(name, output)
    end
  end

  # Singleton methods.

  def zzz_test_singleton_method_exact_name
    name = @@test_names[:singleton_method][:full_unique_single_path] # Should open page.
    refute_nil(name)
    webri_session(name) do |stdin, stdout, stderr|
      output = read(stdout)
      assert_match(/Found one singleton method name starting with '#{name}'./, output)
      check_web_page(name, output)
    end
  end

  def zzz_test_singleton_method_nosuch_name
    name = @@test_names[:singleton_method][:nosuch]  # Should offer all choices; open chosen page.
    refute_nil(name)
    webri_session(name) do |stdin, stdout, stderr|
      output = read(stdout)
      assert_match(/Found no singleton method name starting with '#{name}'./, output)
      assert_match(/Show names of all \d+ singleton methods?/, output)
      check_choices(stdin, stdout, output)
      writeln(stdin, '0')
      output = read(stdout)
      check_web_page(name, output)
    end
  end

  def zzz_test_singleton_method_partial_name_ambiguous
    name = @@test_names[:singleton_method][:abbrev_unique_multi_path] # Should offer multiple choices and open chosen page.
    refute_nil(name)
    webri_session(name) do |stdin, stdout, stderr|
      output = read(stdout)
      assert_match(/Found \d+ singleton method names starting with '#{name}'./, output)
      check_choices(stdin, stdout, output)
      writeln(stdin, '0')
      output = read(stdout)
      check_web_page(name, output)
    end
  end

  def zzz_test_singleton_method_partial_name_unambiguous_multiple_paths
    name = @@test_names[:singleton_method][:abbrev_unique_multi_path] # Should offer multiple choices and open chosen page.
    refute_nil(name)
    webri_session(name) do |stdin, stdout, stderr|
      output = read(stdout)
      output.match(/(\d+)/)
      # This test is for a singleton method name that has multiple paths.
      # Check whether it's so for the given singleton method name.
      # If not, we need to change the singleton method name for this test.
      choice_count = $1.to_i
      assert_operator(choice_count, :>, 1, 'Single method name should have multiple paths.')
      assert_match(/Found \d+ singleton method names starting with '#{name}'./, output)
      check_choices(stdin, stdout, output)
      writeln(stdin, '0')
      output = read(stdout)
      check_web_page(name, output)
    end
  end

  def zzz_test_singleton_method_partial_name_unambiguous_one_path
    name = @@test_names[:singleton_method][:abbrev_unique_single_path] # Should offer one choice; open if yes.
    refute_nil(name)
    webri_session(name) do |stdin, stdout, stderr|
      output = read(stdout)
      assert_match(/Found one singleton method name starting with '#{name}'./, output)
      writeln(stdin, 'y')
      output = read(stdout)
      check_web_page(name, output)
    end
  end

  # Instance methods.

  def zzz_test_instance_method_exact_name
    name = @@test_names[:instance_method][:full_unique_single_path] # Should open page.
    webri_session(name) do |stdin, stdout, stderr|
      output = read(stdout)
      assert_match(/Found one instance method name starting with '#{name}'./, output)
      check_web_page(name, output)
    end
  end

  def zzz_test_instance_method_nosuch_name
    name = @@test_names[:instance_method][:nosuch]  # Should offer all choices; open chosen page.
    refute_nil(name)
    webri_session(name) do |stdin, stdout, stderr|
      output = read(stdout)
      assert_match(/Found no instance method name starting with '#{name}'./, output)
      assert_match(/Show names of all \d+ instance methods?/, output)
      check_choices(stdin, stdout, output)
      writeln(stdin, '0')
      output = read(stdout)
      check_web_page(name, output)
    end
  end

  def zzz_test_instance_method_partial_name_ambiguous
    name = @@test_names[:instance_method][:abbrev_unique_multi_path] # Should offer multiple choices and open chosen page.
    webri_session(name) do |stdin, stdout, stderr|
      output = read(stdout)
      assert_match(/Found \d+ instance method names starting with '#{name}'./, output)
      check_choices(stdin, stdout, output)
      writeln(stdin, '0')
      output = read(stdout)
      check_web_page(name, output)
    end
  end

  def zzz_test_instance_method_partial_name_unambiguous_multiple_paths
    name = @@test_names[:instance_method][:abbrev_unique_multi_path] # Should offer multiple choices and open chosen page.
    webri_session(name) do |stdin, stdout, stderr|
      output = read(stdout)
      output.match(/(\d+)/)
      # This test is for a instance method name that has multiple paths.
      # Check whether it's so for the given instance method name.
      # If not, we need to change the instance method name for this test.
      choice_count = $1.to_i
      assert_operator(choice_count, :>, 1, 'Single method name should have multiple paths.')
      assert_match(/Found \d+ instance method names starting with '#{name}'./, output)
      check_choices(stdin, stdout, output)
      writeln(stdin, '0')
      output = read(stdout)
      check_web_page(name, output)
    end
  end

  def zzz_test_instance_method_partial_name_unambiguous_one_path
    name = @@test_names[:instance_method][:abbrev_unique_single_path] # Should offer one choice; open if yes.
    webri_session(name) do |stdin, stdout, stderr|
      output = read(stdout)
      assert_match(/Found one instance method name starting with '#{name}'./, output)
      writeln(stdin, 'y')
      output = read(stdout)
      check_web_page(name, output)
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

  # def check_web_page(name, output)
  #   lines = output.split("\n")
  #   command_line_no = lines.index {|line| line.match('Command') }
  #   command_line = lines[command_line_no]
  #   # Get the page.
  #   url = command_line.split(' ').last.sub("'", '')
  #   io = URI.open(url)
  #   classes = [Tempfile, StringIO]
  #   assert(classes.include?(io.class))
  #   # Check that the method is on the page.
  #   _, fragment = url.split('#')
  #   if fragment
  #     html = io.read
  #     assert_match(fragment, html)
  #   end
  # end

  def read(stdout)
    stdout.readpartial(4096)
  end

  def writeln(stdin, s)
    stdin.write(s + "\n")
  end

  def setup
    return if defined?(@@test_names)
    @@test_names = {
      class: {
        nosuch: 'NoSuChClAsS',
      },
      singleton_method: {
        nosuch: '::nOsUcHmEtHoD'
      },
      instance_method: {
        nosuch: '#nOsUcHmEtHoD'
      },
      file: {
        nosuch: 'ruby:nOsUcHfIlE',
      },
    }
    get_test_names(:class)
    get_test_names(:file)
    get_test_names(:singleton_method)
    get_test_names(:instance_method)
    p @@test_names[:class]
    p @@test_names[:singleton_method]
    p @@test_names[:instance_method]
    p @@test_names[:file]
  end

  def get_item_locations(type)
    name = @@test_names[type][:nosuch]
    items = {}
    webri_session(name) do |stdin, stdout, stderr|
      # Get the count of items.
      lines = read(stdout).split("\n")
      lines.last.match(/(\d+)/)
      count = $1.to_s.to_i
      # Get the items
      writeln(stdin, 'y')
      i = 0
      stdout.each_line do |line|
        line.chomp!
        index_pattern = /^\s*\d+\s*:\s*/
        line.sub!(index_pattern, '')
        name, location = line.split(' ')
        name.sub!(/:$/, '')
        items[name] = [] unless items[name]
        items[name].push(location)
        i += 1
        break if i == count
      end
    end
    items
  end

  def get_test_names_for_classes
    # Get test names for classes.
    class_locations = get_item_locations(:class)
    class_names = class_locations.keys # A class does not have a location; just use the names.
    # Find a full class name that no other class name starts with.
    class_names.each do |name_to_try|
      selected_names = class_names.select do |name|
        name.start_with?(name_to_try)
      end
      if selected_names.size == 1
        @@test_names[:class][:full_unique] = name_to_try
        break
      end
    end
    # Find an abbreviated class name matching only one name.
    class_names.each do |class_name|
      found = false
      (3..4).each do |len|
        abbrev = class_name[0..len]
        selected_names = class_names.select do |name|
          name.start_with?(abbrev) && name.size != abbrev.size
        end
        if selected_names.size == 1
          @@test_names[:class][:abbrev_unique] = abbrev
          found = true
          break
        end
        break if found
      end
      break if found
    end
    # Find an abbreviated class name matching multiple names.
    class_names.each do |class_name|
      found = false
      (3..4).each do |len|
        abbrev = class_name[0..len]
        selected_names = class_names.select do |name|
          name.start_with?(abbrev)
        end
        if (5..7).include?(selected_names.size)
          @@test_names[:class][:abbrev_multi] = abbrev
          found = true
          break
        end
        break if found
      end
      break if found
    end
  end

  def get_test_names(type)
    locations = get_item_locations(type)
    found_names = @@test_names[type]
    # Find full names matching only one name,
    # one with single path and one with multiple paths.
    find_full_names(locations, found_names)
    # Find abbreviated names matching only one name,
    # one with single path and one with multiple paths.
    find_abbrev_names(locations, found_names)
  end

  def find_full_names(locations, found_names)
    names_to_find = {
      single_path: :full_unique_single_path,
      multi_path: :full_unique_multi_path,
    }
    names = locations.keys
    names.each do |name_to_try|
      selected_names = names.select do |name|
        name.start_with?(name_to_try) && name != name_to_try
      end
      if selected_names.size == 0
        locations_ = locations[name_to_try]
        if locations_.size == 1
          found_names[names_to_find[:single_path]] = name_to_try
        else
          found_names[names_to_find[:multi_path]] = name_to_try
        end
        break if names_found?(found_names, names_to_find)
      end
      break if names_found?(found_names, names_to_find)
    end
  end

  def find_abbrev_names(locations, found_names)
    names_to_find = {
      single_path: :abbrev_unique_single_path,
      multi_path: :abbrev_unique_multi_path,
    }
    names = locations.keys
    names.each do |file_name|
      (3..4).each do |len|
        abbrev = file_name[0..len]
        selected_names = names.select do |name|
          name.start_with?(abbrev) && name.size != abbrev.size
        end
        if selected_names.size == 1
          name = selected_names.first
          locations_ = locations[name]
          if locations_.size == 1
            found_names[names_to_find[:single_path]] = abbrev
          else
            found_names[names_to_find[:multi_path]] = abbrev
          end
          break if names_found?(found_names, names_to_find)
        end
        break if names_found?(found_names, names_to_find)
      end
      break if names_found?(found_names, names_to_find)
    end
  end

  def names_found?(found_names, names_to_find)
    found_names.keys.intersection(names_to_find.values) == names_to_find
  end

  def assert_start_with(expected, actual)
    message = "'#{actual}' should start with '#{expected}'."
    assert(actual.start_with?(expected), message)
  end

  TypeWord = {
    class: 'class/module',
    file: 'file',
    singleton_method: 'singleton method',
    instance_method: 'instance method',
  }
  def assert_found_line(stdout, count, type, name)
    found_line = stdout.readline
    assert_start_with('Found', found_line)
    pattern = case count
              when 0
                'no'
              when 1
                'one'
              else
                /\d+/
              end
    assert_match(pattern, found_line)
    assert_match(TypeWord[type], found_line)
    assert_match(name, found_line)
  end

  def assert_name_line(stdout, name)
    name_line = stdout.readline
    assert_match(name, name_line)
  end

  def assert_opening_line(stdout, name)
    opening_line = stdout.readline
    assert_start_with('Opening', opening_line)
    assert_match(name, opening_line)
  end

  def assert_command_line(stdout, name)
    command_line = stdout.readline
    command_word, start_word, url = command_line.split(' ')
    assert_equal('Command', command_word.sub(':', ''))
    assert_equal('start', start_word.sub("'", ''))
    url.gsub!("'", '')
    assert_match(name, url)
    io = URI.open(url)
    classes = [Tempfile, StringIO]
    assert(classes.include?(io.class))
    _, fragment = url.split('#')
    if fragment
      html = io.read
      assert_match(fragment, html)
    end
  end


end
