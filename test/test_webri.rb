# frozen_string_literal: true

require 'test_helper'
require 'open-uri'
require 'open3'
require 'cgi'

class TestWebRI < Minitest::Test

  # Housekeeping.

  def test_option_help
    webri_session('', '--help') do |stdin, stdout, stderr|
      lines = stdout.readlines
      assert_start_with('Usage: webri [options] name', lines[2])
    end
  end

  def test_option_version
    version = WebRI::VERSION
    assert_match(/\d+\.\d+\.\d+/, version)
  end

  # Errors.

  def test_no_name
    webri_session('') do |stdin, stdout, stderr|
      output = stdout.readpartial(4096)
      assert_start_with('No name given', output)
    end
  end

  def test_multiple_names
    webri_session('Foo Bar') do |stdin, stdout, stderr|
      output = stdout.readpartial(4096)
      assert_start_with('Multiple names given', output)
    end
  end

  # Classes and modules.

  def test_class_nosuch_name
    type = :class
    name = get_nosuch_name(type)
    webri_session(name) do |stdin, stdout, stderr|
      assert_found_line(stdout,0, type, name)
      assert_show(stdout, stdin, type, yes: true)
    end
  end

  def test_class_exact_name
    type = :class
    name = 'ArgumentError'
    assert_exact_name(type, name)
    webri_session(name) do |stdin, stdout, stderr|
      assert_found_line(stdout,1, type, name)
      assert_name_line(stdout, name)
      assert_opening_line(stdout, name)
      assert_command_line(stdout, name)
    end
  end

  def test_class_partial_name_ambiguous
    type = :class
    name = 'Dat'
    assert_partial_name_ambiguous(type, name)
    webri_session(name) do |stdin, stdout, stderr|
      assert_found_line(stdout,2, type, name)
      assert_show(stdout, stdin, type, yes: true)
    end
  end

  def test_class_partial_name_unambiguous
    type = :class
    name =  'ZeroDivision'
    assert_partial_name_unambiguous(type, name, multiple_paths: false)
    webri_session(name) do |stdin, stdout, stderr|
      assert_found_line(stdout,1, type, name)
      assert_name_line(stdout, name)
      assert_open_line(stdin, stdout, name, yes: true)
    end
  end

  # Files.

  def test_file_nosuch_name
    type = :file
    name = get_nosuch_name(type)
    short_name = name.sub('ruby:', '')
    webri_session(name) do |stdin, stdout, stderr|
      assert_found_line(stdout,0, type, short_name)
      assert_show(stdout, stdin, type, yes: true)
    end
  end

  def test_file_exact_name
    type = :file
    short_name = 'literals'
    assert_exact_name(type, short_name)
    name = "ruby:#{short_name}"
    webri_session(name) do |stdin, stdout, stderr|
      assert_found_line(stdout,1, type, short_name)
      assert_name_line(stdout, short_name)
      assert_opening_line(stdout, short_name)
      assert_command_line(stdout, short_name)
    end
  end

  def test_file_partial_name_ambiguous
    type = :file
    short_name = 'o'
    assert_partial_name_ambiguous(type, short_name)
    name = "ruby:#{short_name}"
    webri_session(name) do |stdin, stdout, stderr|
      assert_found_line(stdout,2, type, short_name)
      assert_show(stdout, stdin, type, yes: true)
    end
  end

  def test_file_partial_name_unambiguous_one_path
    type = :file
    short_name =  'maintainer'
    assert_partial_name_unambiguous(type , short_name, multiple_paths: false)
    name = "ruby:#{short_name}"
    webri_session(name) do |stdin, stdout, stderr|
      assert_found_line(stdout,1, type, short_name)
      assert_name_line(stdout, short_name)
      assert_open_line(stdin, stdout, short_name, yes: true)
    end
  end

  def test_file_partial_name_unambiguous_multiple_paths
    type = :file
    short_name = 'method'
    assert_partial_name_unambiguous(type , short_name, multiple_paths: true)
    name = "ruby:#{short_name}"
    webri_session(name) do |stdin, stdout, stderr|
      assert_found_line(stdout,2, type, short_name)
      assert_show(stdout, stdin, type, yes: true)
    end
  end

  # Singleton methods.

  def test_singleton_method_nosuch_name
    type = :singleton_method
    name = get_nosuch_name(type)
    webri_session(name) do |stdin, stdout, stderr|
      assert_found_line(stdout,0, type, name)
      assert_show(stdout, stdin, type, yes: true)
    end
  end

  def test_singleton_method_exact_name
    type = :singleton_method
    name = '::umask'
    assert_exact_name(type, name)
    webri_session(name) do |stdin, stdout, stderr|
      assert_found_line(stdout,1, type, name)
      assert_name_line(stdout, name)
      assert_opening_line(stdout, name)
      assert_command_line(stdout, name)
    end
  end

  def test_singleton_method_partial_name_ambiguous
    type = :singleton_method
    name = '::wri'
    assert_partial_name_ambiguous(type, name)
    webri_session(name) do |stdin, stdout, stderr|
      assert_found_line(stdout,2, type, name)
      assert_show(stdout, stdin, type, yes: true)
    end
  end

  def test_singleton_method_partial_name_unambiguous_one_path
    type = :singleton_method
    name =  '::zca'
    assert_partial_name_unambiguous(type , name, multiple_paths: false)
    webri_session(name) do |stdin, stdout, stderr|
      assert_found_line(stdout,1, type, name)
      assert_name_line(stdout, name)
      assert_open_line(stdin, stdout, name, yes: true)
    end
  end

  def zzz_test_singleton_method_partial_name_unambiguous_multiple_paths
    type = :singleton_method
    name = 'method'
    assert_partial_name_unambiguous(type , name, multiple_paths: true)
    webri_session(name) do |stdin, stdout, stderr|
      assert_found_line(stdout,2, type, name)
      assert_show(stdout, stdin, type, yes: true)
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
      last_index = choice_count - 1
      writeln(stdin, last_index.to_s)
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

  NoSuchName = {
    class:            'NoSuChClAsS',
    singleton_method: '::nOsUcHsInGlEtOnMeThOd',
    instance_method:  '#nOsUcHiNsTaNcEmEtHoD',
    file:             'ruby:nOsUcHfIlE',
  }

  def setup
    return if defined?(@@test_names)
    @@test_names = {}
    io = URI.open('https://docs.ruby-lang.org/en/master/table_of_contents.html')
    @toc_html = io.read
    build_test_class_names
    build_test_file_names
    build_test_singleton_method_names
    build_test_instance_method_names
  end

  def build_test_class_names
    @@test_names[:class] = {}
    names = @@test_names[:class]
    name = NoSuchName[:class]
    lines = get_name_lines(name)
    lines.each do |line|
      _, _, name, path = line.split(/\s+/)
      name.sub!(/:$/, '')
      path.gsub!(/[()]/, '')
      names[name] = path
    end
  end

  def build_test_file_names
    @@test_names[:file] = {}
    names = @@test_names[:file]
    name = NoSuchName[:file]
    lines = get_name_lines(name)
    lines.each do |line|
      _, _, name, path = line.split(/\s+/)
      name.sub!(/:$/, '')
      path.gsub!(/[()]/, '')
      names[name] = [] unless names.include?(name)
      names[name].push(path)
    end
  end

  def build_test_singleton_method_names
    @@test_names[:singleton_method] = {}
    names = @@test_names[:singleton_method]
    name = NoSuchName[:singleton_method]
    lines = get_name_lines(name)
    lines.each do |line|
      _, _, name, _, class_name = line.split(/\s+/)
      class_name.gsub!(/[()]/, '')
      names[name] = [] unless names.include?(name)
      names[name].push(class_name)
    end
  end

  def build_test_instance_method_names
    @@test_names[:instance_method] = {}
    names = @@test_names[:instance_method]
    name = NoSuchName[:instance_method]
    lines = get_name_lines(name)
    lines.each do |line|
      _, _, name, _, class_name = line.split(/\s+/)
      class_name.gsub!(/[()]/, '')
      names[name] = [] unless names.include?(name)
      names[name].push(class_name)
    end
  end

  def get_name_lines(name)
    name_lines = []
    webri_session(name) do |stdin, stdout, stderr|
      # Get the count of items.
      lines = read(stdout).split("\n")
      lines.last.match(/(\d+)/)
      count = $1.to_s.to_i
      # Get the items
      writeln(stdin, 'y')
      (0..count - 1).each do
        line = stdout.readline.chomp
        name_lines.push(line)
      end
    end
    name_lines
  end

  # def get_item_locations(type)
  #   name = @@test_names[type][:nosuch]
  #   items = {}
  #   webri_session(name) do |stdin, stdout, stderr|
  #     # Get the count of items.
  #     lines = read(stdout).split("\n")
  #     lines.last.match(/(\d+)/)
  #     count = $1.to_s.to_i
  #     # Get the items
  #     writeln(stdin, 'y')
  #     i = 0
  #     stdout.each_line do |line|
  #       line.chomp!
  #       index_pattern = /^\s*\d+\s*:\s*/
  #       line.sub!(index_pattern, '')
  #       name, location = line.split(' ')
  #       name.sub!(/:$/, '')
  #       items[name] = [] unless items[name]
  #       items[name].push(location)
  #       i += 1
  #       break if i == count
  #     end
  #   end
  #   items
  # end

  # def get_test_names_for_classes
  #   # Get test names for classes.
  #   class_locations = get_item_locations(:class)
  #   class_names = class_locations.keys # A class does not have a location; just use the names.
  #   # Find a full class name that no other class name starts with.
  #   class_names.each do |name_to_try|
  #     selected_names = class_names.select do |name|
  #       name.start_with?(name_to_try)
  #     end
  #     if selected_names.size == 1
  #       @@test_names[:class][:full_unique] = name_to_try
  #       break
  #     end
  #   end
  #   # Find an abbreviated class name matching only one name.
  #   class_names.each do |class_name|
  #     found = false
  #     (3..4).each do |len|
  #       abbrev = class_name[0..len]
  #       selected_names = class_names.select do |name|
  #         name.start_with?(abbrev) && name.size != abbrev.size
  #       end
  #       if selected_names.size == 1
  #         @@test_names[:class][:abbrev_unique] = abbrev
  #         found = true
  #         break
  #       end
  #       break if found
  #     end
  #     break if found
  #   end
  #   # Find an abbreviated class name matching multiple names.
  #   class_names.each do |class_name|
  #     found = false
  #     (3..4).each do |len|
  #       abbrev = class_name[0..len]
  #       selected_names = class_names.select do |name|
  #         name.start_with?(abbrev)
  #       end
  #       if (5..7).include?(selected_names.size)
  #         @@test_names[:class][:abbrev_multi] = abbrev
  #         found = true
  #         break
  #       end
  #       break if found
  #     end
  #     break if found
  #   end
  # end

  # def get_test_names(type)
  #   locations = get_item_locations(type)
  #   found_names = @@test_names[type]
  #   # Find full names matching only one name,
  #   # one with single path and one with multiple paths.
  #   find_full_names(locations, found_names)
  #   # Find abbreviated names matching only one name,
  #   # one with single path and one with multiple paths.
  #   find_abbrev_names(locations, found_names)
  # end

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
    assert_start_with('Opening ', opening_line)
    assert_match(name, opening_line)
  end

  def assert_command_line(stdout, name)
    command_line = stdout.readline
    command_word, start_word, url = command_line.split(' ')
    assert_equal('Command', command_word.sub(':', ''))
    assert_equal('start', start_word.sub("'", ''))
    url.gsub!("'", '')
    _, fragment = url.split('#')
    io = URI.open(url)
    classes = [Tempfile, StringIO]
    assert(classes.include?(io.class))
    unless fragment
      assert_match(name, url)
      return
    end
    # There is a fragment.
    # Make sure it's on the page
    html = io.read
    assert_match(fragment, html)
    # If the name matches the url, assert it and we're done.
    if name.match(url)
      assert_match(name, url)
      return
    end
    # The name does not match the url,
    # that means the name has special characters (such as '=')
    # that in the url are represented as triplets (such as '-3D').
    # TODO: Verify the fragment in the command.
    # url_ = url
    # s = ''
    # while url_.match(/(-[A-F0-9]{2})/)
    #   removed = url_.slice!(-3..-1)
    #   s += removed[1..].hex.chr
    #   name.slice!(/.$/)
    # end
    # url_ = url_ + '-' unless url_.end_with?('-')
    # url_ = url_ + s
  end

  def assert_show_line(stdout)
    # Cannot use readline for this because it has no trailing newline.
    show_line = read(stdout)
    assert_start_with('Show ', show_line)
    show_line.match(/(\d+)/)
    choice_count = $1.to_i
    assert_instance_of(Integer, choice_count)
    assert_operator(choice_count, :>, 1)
    choice_count
  end

  def assert_open_lines(stdin, stdout, name, yes:)
    # Cannot use readline for this because it has no trailing newline.
    open_line = read(stdout)
    assert_start_with('Open ', open_line)
    answer = yes ? 'y' : 'n'
    stdin.puts(answer)
    return unless yes
    assert_opening_line(stdout, name)
    assert_command_line(stdout, name)
  end

  def assert_open_line(stdin, stdout, name, yes:)
    # Cannot use readline for this because it has no trailing newline.
    open_line = read(stdout)
    assert_start_with('Open', open_line)
    return unless yes
    stdin.puts('y')
    assert_opening_line(stdout, name)
    assert_command_line(stdout, name)
  end

  def assert_choose_line(stdout, choice_count)
    # Cannot use readline for this because it has no trailing newline.
    choose_line = read(stdout)
    assert_start_with('Choose', choose_line)
    assert_match((0..choice_count - 1).to_s, choose_line)
  end

  def assert_show(stdout, stdin, type, yes: true)
    choice_count = assert_show_line(stdout)
    writeln(stdin, yes ? 'y' : 'n')
    return unless yes
    # Verify the choices.
    # Each choice line ends with newline, so use readline.
    choices = []
    (0...choice_count).each do |i|
      choice_line = stdout.readline
      choice_index, choice = choice_line.split(':', 2)
      choice = choice.split(': ').first.strip
      choices.push(choice)
      assert_match("#{i}", choice_index)
    end
    assert_choose_line(stdout, choice_count)
    index = 0
    writeln(stdin, index.to_s)
    choice = choices[index]
    target_path = case type
                  when :class
                    choice.gsub('::', '/')
                  when :file
                    choice.split('.').first
                  when :singleton_method
                    method_name = choice.split(' ').first
                  else
                    choice
                  end
    assert_opening_line(stdout, target_path)
    assert_command_line(stdout, target_path)
  end

  def get_nosuch_name(type)
    name = NoSuchName[type]
    # Name must not be even part of a class name.
    names = @@test_names[type].keys.select do |name_|
      name_.start_with?(name)
    end
    assert_empty(names)
    name
  end

  def assert_exact_name(type, name)
    # Name must be an name and not a partial of any other name.
    names = @@test_names[type].keys.select do |name_|
      name_.start_with?(name)
    end
    assert_operator(names.size, :==, 1)
  end

  def assert_partial_name_ambiguous(type, name)
    # Name must be a partial for multiple names.
    names = @@test_names[type].keys.select do |name_|
      name_.start_with?(name) && name_ != name
    end
    assert_operator(names.size, :>, 1, names)
  end

  def assert_partial_name_unambiguous(type, name, multiple_paths:)
    # Name must be a partial for one name.
    names = @@test_names[type].keys.select do |name_|
      name_.start_with?(name) && name_ != name
    end
    assert_operator(names.size, :==, 1)
    return unless multiple_paths
    name = names.first
    paths = @@test_names[type][name]
    assert_operator(paths.size, :>, 1)
  end

end
