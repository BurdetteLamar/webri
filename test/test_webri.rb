# frozen_string_literal: true

require 'open3'
require 'json'

require_relative 'test_helper'

class TestWebRI < Minitest::Test

  CLASS = 'class/module'
  SINGLETON = 'singleton method'
  INSTANCE = 'instance method'
  FILE = 'file'

  # Tests.

  def test_option_version
    webri_session(nil, one_shot: true, options_s: '--version') do |stdin, stdout, stderr, lines|
      line = lines.next
      assert_equal(line, WebRI::VERSION, 'version')
      assert_enum_done(lines)
    end
  end

  def test_exact_class_name
    [:exact_simple, :exact_nested].each do |type|
      name = @values[:classes][type]
      do_exact_name(name, CLASS)
    end
  end

  # Setup.

  def setup
    return if @values
    @values = {}
    release_name = '4.0'
    data_file_path = File.expand_path("../data/#{release_name}.json", __dir__)
    json = open(data_file_path).read
    values = JSON.parse(json, create_additions: true)
    # classes_for_method = values['classes_for_method']
    hrefs_for_name = values['hrefs_for_name']
    names_by_type = hrefs_for_name.group_by do |name, hrefs|
      case name
      when /^::/
        :singleton_methods
      when /^#/
        :instance_methods
      when /^[A-Z]/
        :classes
      when  /^fatal$/
        :classes
      when /^ruby:/
        :files
      else
        fail name
      end
    end
    name_values = {}
    [:classes, :files].each do |type|
      name_values[type] = {}
      names = names_by_type[type].map {|a| a.first }
      names.each do |name|
        next if name.size == 1
        # Find other names that begin with this name.
        pattern = Regexp.new("^#{name}.") # Note the trailing dot.
        other_names = names.select {|_name| _name.match(pattern)}
        if other_names.empty?
          if name.match('::')
            name_values[type][:exact_nested] = name
            name_values[type][:partial_nested] = name.chop
          elsif type == :classes
            name_values[type][:exact_simple] = name
            name_values[type][:partial_simple] = name.chop
          else
            name_values[type][:exact] = name
            name_values[type][:partial] = name.chop
          end
        end
        if type == :classes
          name_values[type][:nosuch_simple] = 'Nosuch'
          name_values[type][:nosuch_nested] = 'Nosuch::Foo'
        else
          name_values[type][:nosuch] = 'ruby::nosuch'
        end
        @values[type] = name_values[type]
      end
    end
  end

  # Helpers.

  def do_exact_name(name, type)
    webri_session(name, one_shot: true) do |stdin, stdout, stderr, lines|
      assert_found_one_name(lines, type, name)
      assert_enum_done(lines)
    end
    webri_session(name, one_shot: false) do |stdin, stdout, stderr, lines|
      assert_found_one_name(lines, type, name)
      assert_prompt(lines.next)
      assert_enum_done(lines)
    end
  end

  # There are two cases for partials:
  # - The selection is unique: page opened.
  # - The selection is not unique: second selection required.

  def do_partial_name_select(name, type)
    webri_session do |stdin, stdout, stderr|
      read_to_prompt(stdout)
      stdin.puts name
      stdin.flush
      lines = read_to_select(stdout)
      assert_found_multiple_names(lines, type, name)
      stdin.puts '0'
      lines = read_to_prompt(stdout)
      assert_match('Opening', lines.next)
    end
  end

  def zzz_test_exact_singleton_name
    NAMES[:singleton][:exact].each do |name|
      do_exact_name(name, SINGLETON)
    end
  end

  def zzz_test_exact_instance_name
    NAMES[:instance][:exact].each do |name|
      do_exact_name(name, INSTANCE)
    end
  end

  def zzz_test_exact_file_name
    NAMES[:file][:exact].each do |name|
      do_exact_name(name, FILE)
    end
  end

  def zzz_test_partial_class_name_select
    NAMES[:class][:partial].each do |name|
      do_partial_name_select(name, CLASS)
    end
  end

  def ztest_partial_singleton_name_select
    NAMES[:singleton][:partial].each do |name|
      do_partial_name_select(name, SINGLETON)
    end
  end

  def ztest_partial_instance_name_select
    NAMES[:instance][:partial].each do |name|
      do_partial_name_select(name, INSTANCE)
    end
  end

  def ztest_partial_file_name_select
    NAMES[:file][:partial].each do |name|
      do_partial_name_select(name, FILE)
    end
  end

  # Assertions

  def assert_prompt(line)
    assert_match(/webri>\s+$/, line)
  end

  def assert_enum_done(lines)
    begin
      lines.next
      assert false
    rescue StopIteration
      assert true
    end
  end

  def assert_found_one_name(lines, type, name)
    message = "#{type} #{name}."
    line = lines.next
    assert_match(/^Found one/, line, message)
    assert_match(type, line, message)
    assert_match(name, line, message)
    if [SINGLETON, INSTANCE].include?(type)
      line = lines.next
      assert_match("Found one #{CLASS}", line, message)
    end
    line = lines.next
    assert_match('Opening', line, message)
  end

  def assert_found_multiple_names(lines, type, name)
    message = "#{type} #{name}."
    line = lines.next
    assert_match(/^Found \d+ #{type} names/, line, message)
    line = lines.reduce { |_, value| value }
    assert_match(/^Type/, line, message)
  end

  def assert_found_no_name(lines, type, name)
    message = "#{type} #{name}."
    line = lines.next
    assert_match(/^Found no/, line, message)
    assert_match(type, line, message)
    assert_match(name, line, message)
    line = lines.next
    assert_match('Show', line, message)
  end

  # Infrastructure.

  # Open a webri session and yield its IO streams.
  def webri_session(name, one_shot:, options_s: '')
    options_s += ' --noop --noreline --noansi --release 4.0'
    if name.nil?
      # No name; we're testing options: --info, --version, --help
      command = "ruby ./exe/webri #{options_s}"
      Open3.popen3(command) do |stdin, stdout, stderr, wait_thread|
        stdin.flush
        lines = read_to(stdout, /./)
        yield stdin, stdout, stderr, lines
      ensure
        stdin.close
        wait_thread.value
      end
    elsif one_shot
      # Put name on command line; no REPL.
      command = "ruby ./exe/webri #{options_s} #{name}"
      Open3.popen3(command) do |stdin, stdout, stderr, wait_thread|
        stdin.flush
        lines = read_to(stdout, 'Opening')
        yield stdin, stdout, stderr, lines
      ensure
        stdin.close
        wait_thread.value
      end
    else
      # Don't put name on command line; drop into REPL.
      command = "ruby ./exe/webri #{options_s}"
      Open3.popen3(command) do |stdin, stdout, stderr, wait_thread|
        read_to_prompt(stdout)
        stdin.puts name
        stdin.flush
        lines = read_to_prompt(stdout)
        yield stdin, stdout, stderr, lines
      ensure
        stdin.close
        wait_thread.value
      end
    end
  end

  def read_to(io, pattern)
    output = +""
    loop do
      output << io.readpartial(1024)
      break if output.match?(pattern)
    end
    output.split(/\R/).to_enum
  end

  def read_to_select(io)
    read_to(io, /^Type a number/)
  end

  def read_to_prompt(io)
    read_to(io, /webri>\s+$/)
  end


  # def read(stdout)
  #   stdout.readpartial(4096)
  # end
  #
  # NoSuchName = {
  #   class:            'NoSuChClAsS',
  #   singleton_method: '::nOsUcHsInGlEtOnMeThOd',
  #   instance_method:  '#nOsUcHiNsTaNcEmEtHoD',
  #   page:             'ruby:nOsUcHpAgE',
  # }
  #
  # def zzz_setup
  #   return if defined?(@@test_names)
  #   # Get the url from --info and fetch the toc html.
  #   webri_session('--info') do |stdin, stdout, stderr|
  #     lines = stdout.readlines
  #     url_line = lines[1]
  #     url = url_line.split(' ').last
  #     url.gsub!("'", '')
  #     io = URI.open(url)
  #     @toc_html = io.read
  #   end
  #   # Build the names from the toc html.
  #   @@test_names = {}
  #   build_test_class_names
  #   build_test_file_names
  #   build_test_singleton_method_names
  #   build_test_instance_method_names
  # end
  #
  # def build_test_class_names
  #   type = :class
  #   @@test_names[type] = {}
  #   names = @@test_names[type]
  #   # Get names by trying for a nonexistent name.
  #   name = NoSuchName[type]
  #   lines = get_name_lines(name)
  #   lines.each do |line|
  #     # The line looks something like this:
  #     #    1349:  Zlib::GzipFile::CRCError: (Zlib/GzipFile/CRCError.html)
  #     _, _, name, path = line.split(/\s+/)
  #     name.sub!(/:$/, '')    # Trim the trailing colon from the name.
  #     path.gsub!(/[()]/, '') # Trim the parentheses from the path.
  #     names[name] = path
  #   end
  # end
  #
  # def build_test_file_names
  #   @@test_names[:page] = {}
  #   names = @@test_names[:page]
  #   name = NoSuchName[:page]
  #   lines = get_name_lines(name)
  #   lines.each do |line|
  #     _, _, name, path = line.split(/\s+/)
  #     name.sub!(/:$/, '')
  #     path.gsub!(/[()]/, '')
  #     names[name] = [] unless names.include?(name)
  #     names[name].push(path)
  #   end
  # end
  #
  # def build_test_singleton_method_names
  #   @@test_names[:singleton_method] = {}
  #   names = @@test_names[:singleton_method]
  #   name = NoSuchName[:singleton_method]
  #   lines = get_name_lines(name)
  #   lines.each do |line|
  #     _, _, name, _, class_name = line.split(/\s+/)
  #     class_name.gsub!(/[()]/, '')
  #     names[name] = [] unless names.include?(name)
  #     names[name].push(class_name)
  #   end
  # end
  #
  # def build_test_instance_method_names
  #   @@test_names[:instance_method] = {}
  #   names = @@test_names[:instance_method]
  #   name = NoSuchName[:instance_method]
  #   lines = get_name_lines(name)
  #   lines.each do |line|
  #     _, _, name, _, class_name = line.split(/\s+/)
  #     class_name.gsub!(/[()]/, '')
  #     names[name] = [] unless names.include?(name)
  #     names[name].push(class_name)
  #   end
  # end
  #
  # def get_name_lines(name)
  #   name_lines = []
  #   webri_session do |stdin, stdout, stderr|
  #     put_name(name, stdin, stdout)
  #     _ = stdout.readline # Found line
  #     show_line = read(stdout)
  #     show_line.match(/(\d+)/)
  #     count = $1.to_s.to_i
  #     # Get the items
  #     stdin.puts('y')
  #     (0..count - 1).each do
  #       line = stdout.readline.chomp
  #       name_lines.push(line)
  #     end
  #   end
  #   name_lines
  # end
  #
  # def find_full_names(locations, found_names)
  #   names_to_find = {
  #     single_path: :full_unique_single_path,
  #     multi_path: :full_unique_multi_path,
  #   }
  #   names = locations.keys
  #   names.each do |name_to_try|
  #     selected_names = names.select do |name|
  #       name.start_with?(name_to_try) && name != name_to_try
  #     end
  #     if selected_names.size == 0
  #       locations_ = locations[name_to_try]
  #       if locations_.size == 1
  #         found_names[names_to_find[:single_path]] = name_to_try
  #       else
  #         found_names[names_to_find[:multi_path]] = name_to_try
  #       end
  #       break if names_found?(found_names, names_to_find)
  #     end
  #     break if names_found?(found_names, names_to_find)
  #   end
  # end
  #
  # def find_abbrev_names(locations, found_names)
  #   names_to_find = {
  #     single_path: :abbrev_unique_single_path,
  #     multi_path: :abbrev_unique_multi_path,
  #   }
  #   names = locations.keys
  #   names.each do |file_name|
  #     (3..4).each do |len|
  #       abbrev = file_name[0..len]
  #       selected_names = names.select do |name|
  #         name.start_with?(abbrev) && name.size != abbrev.size
  #       end
  #       if selected_names.size == 1
  #         name = selected_names.first
  #         locations_ = locations[name]
  #         if locations_.size == 1
  #           found_names[names_to_find[:single_path]] = abbrev
  #         else
  #           found_names[names_to_find[:multi_path]] = abbrev
  #         end
  #         break if names_found?(found_names, names_to_find)
  #       end
  #       break if names_found?(found_names, names_to_find)
  #     end
  #     break if names_found?(found_names, names_to_find)
  #   end
  # end
  #
  # def names_found?(found_names, names_to_find)
  #   found_names.keys.intersection(names_to_find.values) == names_to_find
  # end
  #
  # def assert_start_with(expected, actual)
  #   message = "'#{actual}' should start with '#{expected}'."
  #   assert(actual.start_with?(expected), message)
  # end
  #
  # def put_name(name, stdin, stdout)
  #   assert_prompt(stdout)
  #   stdin.puts(name)
  # end
  #
  # def assert_prompt(stdout)
  #   prompt = read(stdout)
  #   assert_match('webri', prompt)
  # end
  #
  # TypeWord = {
  #   class: 'class/module',
  #   page: 'page',
  #   singleton_method: 'singleton method',
  #   instance_method: 'instance method',
  # }
  # def assert_found_line(stdout, count, type, name)
  #   found_line = stdout.readline
  #   assert_match('Found', found_line)
  #   pattern = case count
  #             when 0
  #               'no'
  #             when 1
  #               'one'
  #             else
  #               /\d+/
  #             end
  #   assert_match(pattern, found_line)
  #   assert_match(TypeWord[type], found_line)
  #   assert_match(name, found_line)
  # end
  #
  # def assert_name_line(stdout, name)
  #   name_line = stdout.readline
  #   assert_match(name, name_line)
  # end
  #
  # def assert_opening_line(stdout, name)
  #   opening_line = stdout.readline
  #   assert_start_with('Opening ', opening_line)
  #   assert_match(name, opening_line)
  # end
  #
  # def assert_command_line(stdout, name)
  #   command_line = stdout.readline
  #   command_word, opener_word, url = command_line.split(' ')
  #   opener_word.sub!("'", '')
  #   command_word.sub!(':', '')
  #   assert_equal('Command', command_word)
  #   opener_words = %w[xdg-open open start]
  #   assert_includes(opener_words, opener_word)
  #   url.gsub!("'", '')
  #   _, fragment = url.split('#')
  #   io = URI.open(url)
  #   classes = [Tempfile, StringIO]
  #   assert(classes.include?(io.class))
  #   unless fragment
  #     assert_match(name, url)
  #     return
  #   end
  #   # There is a fragment.
  #   # Make sure it's on the page
  #   html = io.read
  #   assert_match(fragment, html)
  #   # If the name matches the url, assert it and we're done.
  #   if name.match(url)
  #     assert_match(name, url)
  #     return
  #   end
  #   # The name does not match the url.
  #   # Try to fix the method name to make it match
  #   fixed_name = case name
  #           when /^::/
  #             name.sub(/::/, 'method-c-')
  #           when /^#/
  #             name.sub(/#/, 'method-i-')
  #           else
  #             assert(false)
  #           end
  #   if fragment.start_with?(fixed_name)
  #     assert_match(fixed_name, fragment)
  #     return
  #   end
  #   # The name has with special characters such as '?',
  #   # and fragment has triplets of characters such as '-3F'.
  #   # Build a fixed fragment that has characters instead of triplets.
  #   a = fragment.split(/-[A-F0-9][A-F0-9]/)
  #   assert_operator(a.size, :<, 3)
  #   leader, trailer = *a
  #   trailer ||= ''
  #   triplets = fragment.slice(leader.size..)
  #   unless trailer.empty?
  #     triplets_len = triplets.size - trailer.size
  #     triplets.slice!(triplets_len..)
  #   end
  #   replacement_chars = []
  #   until triplets.empty?
  #     duple = triplets.slice!(0..2).slice!(1..)
  #     replacement_char = duple.hex.chr
  #     replacement_chars.push(replacement_char)
  #   end
  #   replacement_string = replacement_chars.join('')
  #   leader += '-' if leader.match(/method-\w$/)
  #   fixed_fragment = leader + replacement_string + trailer
  #   assert_equal(fixed_name, fixed_fragment)
  # end
  #
  # def assert_show_line(stdout)
  #   # Cannot use readline for this because it has no trailing newline.
  #   show_line = read(stdout)
  #   assert_start_with('Show ', show_line)
  #   show_line.match(/(\d+)/)
  #   choice_count = $1.to_i
  #   assert_instance_of(Integer, choice_count)
  #   assert_operator(choice_count, :>, 1)
  #   choice_count
  # end
  #
  # def assert_open_lines(stdin, stdout, name, yes:)
  #   # Cannot use readline for this because it has no trailing newline.
  #   open_line = read(stdout)
  #   assert_start_with('Open ', open_line)
  #   answer = yes ? 'y' : 'n'
  #   stdin.puts(answer)
  #   return unless yes
  #   assert_opening_line(stdout, name)
  #   assert_command_line(stdout, name)
  # end
  #
  # def assert_open_line(stdin, stdout, name, yes:)
  #   # Cannot use readline for this because it has no trailing newline.
  #   open_line = read(stdout)
  #   assert_start_with('Open', open_line)
  #   return unless yes
  #   stdin.puts('y')
  #   assert_opening_line(stdout, name)
  #   assert_command_line(stdout, name)
  # end
  #
  # def assert_choose_line(stdout, choice_count)
  #   # Cannot use readline for this because it has no trailing newline.
  #   choose_line = read(stdout)
  #   assert_match('choose', choose_line)
  # end
  #
  # def assert_show(stdout, stdin, type, yes: true)
  #   choice_count = assert_show_line(stdout)
  #   stdin.puts(yes ? 'y' : 'n')
  #   return unless yes
  #   # Verify the choices.
  #   # Each choice line ends with newline, so use readline.
  #   choices = []
  #   (0...choice_count).each do |i|
  #     choice_line = stdout.readline
  #     choice_index, choice = choice_line.split(':', 2)
  #     choice = choice.split(' ').first.strip
  #     choices.push(choice)
  #     # Check the indexes of the first few.
  #     next if i > 4
  #     assert_match("#{i}", choice_index)
  #   end
  #   # No duplicate choices.
  #   assert_empty(choices - choices.uniq)
  #   assert_choose_line(stdout, choice_count)
  #   index = 0
  #   stdin.puts(index.to_s)
  #   choice = choices[index]
  #   target_path = case type
  #                 when :class
  #                   choice.gsub('::', '/')
  #                 when :page
  #                   choice.split('.').first
  #                 when :singleton_method, :instance_method
  #                   choice.split(' ').first
  #                 else
  #                   fail choice
  #                 end
  #   assert_opening_line(stdout, target_path)
  #   assert_command_line(stdout, target_path)
  # end
  #
  # def get_nosuch_name(type)
  #   name = NoSuchName[type]
  #   # Name must not be even part of a class name.
  #   names = @@test_names[type].keys.select do |name_|
  #     name_.start_with?(name)
  #   end
  #   assert_empty(names)
  #   name
  # end
  #
  # def assert_exact_name(type, name)
  #   # Name must be an name and not a partial of any other name.
  #   names = @@test_names[type].keys.select do |name_|
  #     name_.start_with?(name)
  #   end
  #   assert_operator(names.size, :==, 1)
  # end
  #
  # def assert_partial_name_ambiguous(type, name)
  #   # Name must be a partial for multiple names.
  #   names = @@test_names[type].keys.select do |name_|
  #     name_.start_with?(name) && name_ != name
  #   end
  #   assert_operator(names.size, :>, 1, names)
  # end
  #
  # def assert_partial_name_unambiguous(type, name, multiple_paths:)
  #   # Name must be a partial for one name.
  #   names = @@test_names[type].keys.select do |name_|
  #     name_.start_with?(name) && name_ != name
  #   end
  #   assert_operator(names.size, :==, 1, name)
  #   return unless multiple_paths
  #   name = names.first
  #   paths = @@test_names[type][name]
  #   assert_operator(paths.size, :>, 1, name)
  # end
  #
  # def get_partial_name_unambiguous(type, multiple_paths:)
  #   names = @@test_names[type]
  #   names.keys.each do |candidate_name|
  #     partial_name = candidate_name[0..-2]
  #     abbreviated_names = []
  #     names.each_pair do |other_name, paths|
  #       next unless other_name.start_with?(partial_name)
  #       next if multiple_paths && paths.size < 2
  #       abbreviated_names.push(other_name)
  #     end
  #     if abbreviated_names.size == 1
  #       return partial_name
  #     end
  #   end
  #   nil
  # end

end
