# frozen_string_literal: true

require_relative 'test_helper'
require 'open-uri'
require 'open3'
require 'cgi'
require 'rbconfig'

class TestWebRI < Minitest::Test

  # Test housekeeping.

  def test_option_help
    webri_session('', '--help') do |stdin, stdout, stderr|
      lines = stdout.readlines
      assert_start_with('Usage: webri [options] name', lines[3])
    end
  end

  def test_option_version
    version = WebRI::VERSION
    assert_match(/\d+\.\d+\.\d+/, version)
  end

  def test_option_release
    a = RUBY_VERSION.split('.')
    release = a[0..1].join('.')
    webri_session("Array --release #{release}") do |stdin, stdout, stderr|
      _, _, opening_line, command_line = stdout.readlines
      assert_match(release, opening_line)
      assert_match(release, command_line)
    end
  end

  # Test errors.

  def test_no_name_given
    webri_session('') do |stdin, stdout, stderr|
      output = stdout.readpartial(4096)
      assert_start_with('No name given', output)
    end
  end

  def test_multiple_names_given
    webri_session('Foo Bar') do |stdin, stdout, stderr|
      output = stdout.readpartial(4096)
      assert_start_with('Multiple names given', output)
    end
  end

  def test_nonexistent_name_given
    webri_session('foo') do |stdin, stdout, stderr|
      output = stdout.readpartial(4096)
      assert_start_with('No documentation available', output)
    end
  end

  def test_option_release_invalid
    webri_session("--release foo") do |stdin, stdout, stderr|
      lines = stdout.readlines
      assert_start_with('Unknown', lines[0])
      assert_start_with('Master', lines[1])
      assert_start_with('Supported', lines[2])
      assert_start_with('Unsupported', lines[3])
    end
  end

  # Test classes and modules.

  def test_class_nosuch_name
    type = :class
    name = get_nosuch_name(type)
    webri_session(name) do |stdin, stdout, stderr|
      assert_found_line(stdout, 0, type, name)
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

  # Test files.

  def test_file_nosuch_name
    type = :file
    name = get_nosuch_name(type)
    short_name = name.sub('ruby:', '')
    webri_session(name) do |stdin, stdout, stderr|
      assert_found_line(stdout, 0, type, short_name)
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
    short_name = 'p'
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
    short_name = get_partial_name_unambiguous(type, multiple_paths: true)
    unless short_name
      puts "Warning: Method #{__method__} could not get a suitable name."
      return
    end
    name = "ruby:#{short_name}"
    webri_session(name) do |stdin, stdout, stderr|
      assert_found_line(stdout,2, type, short_name)
      assert_show(stdout, stdin, type, yes: true)
    end
  end

  # Test singleton methods.

  def test_singleton_method_nosuch_name
    type = :singleton_method
    name = get_nosuch_name(type)
    webri_session(name) do |stdin, stdout, stderr|
      assert_found_line(stdout, 0, type, name)
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

  def test_singleton_method_partial_name_unambiguous_multiple_paths
    type = :singleton_method
    name = '::wra'
    assert_partial_name_unambiguous(type , name, multiple_paths: true)
    webri_session(name) do |stdin, stdout, stderr|
      assert_found_line(stdout,2, type, name)
      assert_show(stdout, stdin, type, yes: true)
    end
  end

  # Test instance methods.

  def test_instance_method_nosuch_name
    type = :instance_method
    name = get_nosuch_name(type)
    webri_session(name) do |stdin, stdout, stderr|
      assert_found_line(stdout, 0, type, name)
      assert_show(stdout, stdin, type, yes: true)
    end
  end

  def test_instance_method_exact_name
    type = :instance_method
    name = '#yield_self'
    assert_exact_name(type, name)
    webri_session(name) do |stdin, stdout, stderr|
      assert_found_line(stdout,1, type, name)
      assert_name_line(stdout, name)
      assert_opening_line(stdout, name)
      assert_command_line(stdout, name)
    end
  end

  def test_instance_method_partial_name_ambiguous
    type = :instance_method
    name = '#wri'
    assert_partial_name_ambiguous(type, name)
    webri_session(name) do |stdin, stdout, stderr|
      assert_found_line(stdout,2, type, name)
      assert_show(stdout, stdin, type, yes: true)
    end
  end

  def test_instance_method_partial_name_unambiguous_one_path
    type = :instance_method
    name =  '#yield_sel'
    assert_partial_name_unambiguous(type , name, multiple_paths: false)
    webri_session(name) do |stdin, stdout, stderr|
      assert_found_line(stdout,1, type, name)
      assert_name_line(stdout, name)
      assert_open_line(stdin, stdout, name, yes: true)
    end
  end

  def test_instance_method_partial_name_unambiguous_multiple_paths
    type = :instance_method
    name = '#yea'
    assert_partial_name_unambiguous(type , name, multiple_paths: true)
    webri_session(name) do |stdin, stdout, stderr|
      assert_found_line(stdout,2, type, name)
      assert_show(stdout, stdin, type, yes: true)
    end
  end

  # Infrastructure.

  # Open a webri session and yield its IO streams.
  # Option --noop, which we use for all tests, means don't actually open the web page.
  def webri_session(name, options_s = '--noop')
    if RbConfig::CONFIG['host_os'].match(/linux/) && name.start_with?('#')
      name = name.sub(/^#/, '\\\\#')
    end
    command = "ruby bin/webri #{options_s} #{name}"
    Open3.popen3(command) do |stdin, stdout, stderr, wait_thread|
      yield stdin, stdout, stderr
    end
  end

  def read(stdout)
    stdout.readpartial(4096)
  end

  NoSuchName = {
    class:            'NoSuChClAsS',
    singleton_method: '::nOsUcHsInGlEtOnMeThOd',
    instance_method:  '#nOsUcHiNsTaNcEmEtHoD',
    file:             'ruby:nOsUcHfIlE',
  }

  def setup
    return if defined?(@@test_names)
    # Get the url from --info and fetch the toc html.
    webri_session('--info') do |stdin, stdout, stderr|
      lines = stdout.readlines
      url_line = lines[1]
      url = url_line.split(' ').last
      url.gsub!("'", '')
      io = URI.open(url)
      @toc_html = io.read
    end
    # Build the names from the toc html.
    @@test_names = {}
    build_test_class_names
    build_test_file_names
    build_test_singleton_method_names
    build_test_instance_method_names
  end

  def build_test_class_names
    type = :class
    @@test_names[type] = {}
    names = @@test_names[type]
    # Get names by trying for a nonexistent name.
    name = NoSuchName[type]
    lines = get_name_lines(name)
    lines.each do |line|
      # The line looks something like this:
      #    1349:  Zlib::GzipFile::CRCError: (Zlib/GzipFile/CRCError.html)
      _, _, name, path = line.split(/\s+/)
      name.sub!(/:$/, '')    # Trim the trailing colon from the name.
      path.gsub!(/[()]/, '') # Trim the parentheses from the path.
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
      stdin.puts('y')
      (0..count - 1).each do
        line = stdout.readline.chomp
        name_lines.push(line)
      end
    end
    name_lines
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
    assert_start_with('Opening ', opening_line)
    assert_match(name, opening_line)
  end

  def assert_command_line(stdout, name)
    command_line = stdout.readline
    command_word, opener_word, url = command_line.split(' ')
    opener_word.sub!("'", '')
    command_word.sub!(':', '')
    assert_equal('Command', command_word)
    opener_words = %w[xdg-open open start]
    assert_includes(opener_words, opener_word)
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
    # The name does not match the url.
    # Try to fix the method name to make it match
    fixed_name = case name
            when /^::/
              name.sub(/::/, 'method-c-')
            when /^#/
              name.sub(/#/, 'method-i-')
            else
              assert(false)
            end
    if fragment.start_with?(fixed_name)
      assert_match(fixed_name, fragment)
      return
    end
    # The name ends with special characters such as '?',
    # and fragment ends with encoded characters such as '-3F'.
    # Try to fix the name to make it match.
    fixed_fragment = fragment
    replacement_chars = []
    while fixed_fragment[-3] == '-' do
      encoded_string = fixed_fragment.slice!(-3..-1)
      encoded_string.slice!(0, 1)
      replacement_char = encoded_string.hex.chr
      replacement_chars.push(replacement_char)
    end
    replacement_string = replacement_chars.join('')
    pattern = /method-\w$/
    fixed_fragment += '-' if fixed_fragment.match(pattern)
    fixed_fragment += replacement_string
    assert_equal(fixed_name, fixed_fragment)
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
    assert_match('choose', choose_line)
  end

  def assert_show(stdout, stdin, type, yes: true)
    choice_count = assert_show_line(stdout)
    stdin.puts(yes ? 'y' : 'n')
    return unless yes
    # Verify the choices.
    # Each choice line ends with newline, so use readline.
    choices = []
    (0...choice_count).each do |i|
      choice_line = stdout.readline
      choice_index, choice = choice_line.split(':', 2)
      choice = choice.split(' ').first.strip
      choices.push(choice)
      assert_match("#{i}", choice_index)
    end
    assert_choose_line(stdout, choice_count)
    index = 0
    stdin.puts(index.to_s)
    choice = choices[index]
    target_path = case type
                  when :class
                    choice.gsub('::', '/')
                  when :file
                    choice.split('.').first
                  when :singleton_method, :instance_method
                    choice.split(' ').first
                  else
                    fail choice
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

  def get_partial_name_unambiguous(type, multiple_paths:)
    names = @@test_names[type]
    names.keys.each do |candidate_name|
      partial_name = candidate_name[0..-2]
      abbreviated_names = []
      names.each_pair do |other_name, paths|
        next unless other_name.start_with?(partial_name)
        next if multiple_paths && paths.size < 2
        abbreviated_names.push(other_name)
      end
      if abbreviated_names.size == 1
        return partial_name
      end
    end
    nil
  end

end
