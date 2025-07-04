# frozen_string_literal: true

require 'rbconfig'
require 'open-uri'
require 'rexml'
require 'cgi'
require 'reline'

# TODO: Use reline.
#
# TODO: Subroutinize.
# TODO: Make initialization faster.

# TODO: Choose dynamically the test names (rather than fixed)?
# TODO: Test on Linux.
# TODO: Test all releases(?).
# TODO: Test all pages(?).

# TODO: Make it work for naked method ('parse') or dotted method ('.parse').

# TODO: Support pager.

# TODO: Support .webrirc.
# TODO: Make it save options to .webrirc.
# TODO: Make it show .webrirc.

# A class to display Ruby online HTML documentation.
class WebRI

  # Site of the official documentation.
  DocSite = 'https://docs.ruby-lang.org/en/'

  # Get the info from the Ruby doc site's table of contents
  # and build our @index_for_type.
  def initialize(options = {})
    capture_options(options)
    set_doc_release
    get_toc_html
    build_indexes
    print_info if @info
    print @noreline
    if os_type == :linux && !@noreline
      repl_reline
    else
      repl_plain
    end
  end

  def repl_plain # Read-evaluate-print loop, without Reline.
    while true
      $stdout.write('webri> ')
      $stdout.flush
      response = $stdin.gets.chomp
      exit if response == 'exit'
      next if response.empty?
      if response.split(' ').size > 1
        puts "One name at a time, please."
        next
      end
      show(response)
    end
  end

  def repl_reline # Read-evaluate-print loop, with Reline.
    begin
      stty_save = `stty -g`.chomp
    rescue
    end

    begin
      completion_words= []
      @index_for_type.each_pair do |type, index|
        if type == :page
          completion_words += index.keys.map {|name| 'ruby:' + name }
        else
          completion_words += index.keys
        end
      end
      Reline.completion_proc = proc { |word|
        completion_words
      }
      while line = Reline.readline("webri> ", true)
        case line.chomp
        when 'exit'
          exit 0
        when ''
          # NOOP
        else
          if line.split(' ').size > 1
            puts "One name at a time, please."
            next
          end
          show(line)
        end
      end
    rescue Interrupt
      puts '^C'
      `stty #{stty_save}` if stty_save
      exit 0
    end
    puts
  end

  def set_doc_release
    supported_releases = []
    unsupported_releases = []
    master_release = nil
    io = URI.open('https://docs.ruby-lang.org/en/')
    lines = io.readlines
    lines.each do |line|
      next unless line.match(/<a/)
      doc = REXML::Document.new(line)
      _, release, end_of_support = doc.root.text.split(' ')
      break if release.start_with?('2')
      if end_of_support
        unsupported_releases.push(release)
      elsif release == 'master'
        master_release = release
      else
        supported_releases.push(release)
      end
    end
    all_releases = [master_release] + supported_releases + unsupported_releases
    if @doc_release
      unless all_releases.include?(@doc_release)
        puts "Unknown documentation release:  #{@doc_release}"
        puts "Available releases: #{all_releases.join(' ')}"
        exit
      end
    else
      a = RUBY_VERSION.split('.')
      @doc_release ||= a[0..1].join('.')
    end
  end

  def print_info
    puts "Ruby documentation release:  #{@doc_release}"
    puts "Ruby documentation URL:      #{@toc_url}"
    puts "Executable to open page:     #{opener_name}"
    puts "Names:"
    @index_for_type.each_pair do |type, items|
      puts format("  %5d %s names", items.count, type)
    end
    exit
  end

  def build_indexes
    # Index for each type of entry.
    # Each index has a hash; key is name, value is array of URIs.
    @index_for_type = {
      class: {}, # Has both classes and modules.
      singleton_method: {},
      instance_method: {},
      page: {},
    }
    # Iterate over the lines of the TOC page.
    lines = @toc_html.split("\n")
    i = 0
    while i < lines.count
      item_line = lines[i]
      i += 1
      next unless item_line.match('<li class="(\w+)"')
      class_attr_value = $1 # Save for later.
      # We have a pair of lines such as:
      #     <li class="file">
      #       <a href="COPYING.html">COPYING</a>
      anchor_line = lines[i] # Second line of pair.
      # Consume anchor_line.
      i += 1
      # We capture variables thus:
      # - +type+ is the value of attribute 'class'.
      # - +path+ is the value of attribute 'href'.
      # - +full_name+ is the HTML text.
      type = class_attr_value
      _, path, rest = anchor_line.split('"')
      full_name = rest.split(/<|>/)[1]
      full_name = CGI.unescapeHTML(full_name)
      case type
      when 'class', 'module'
        index = @index_for_type[:class]
        if index.include?(full_name)
          entry = index[full_name]
        else
          entry = ClassEntry.new(full_name)
          index[full_name] = entry
        end
        entry.paths.push(path) unless entry.paths.include?(path)
      when 'file'
        index = @index_for_type[:page]
        if index.include?(full_name)
          entry = index[full_name]
        else
          entry = FileEntry.new(full_name)
          index[full_name] = entry
        end
        entry.paths.push(path) unless entry.paths.include?(path)
      when 'method'
        case anchor_line
        when /method-c-/
          index = @index_for_type[:singleton_method]
          if index.include?(full_name)
            entry = index[full_name]
          else
            entry = SingletonMethodEntry.new(full_name)
            index[full_name] = entry
          end
          entry.paths.push(path) unless entry.paths.include?(path)
        when /method-i-/
          index = @index_for_type[:instance_method]
          if index.include?(full_name)
            entry = index[full_name]
          else
            entry = InstanceMethodEntry.new(full_name)
            index[full_name] = entry
          end
          entry.paths.push(path) unless entry.paths.include?(path)
        else
          fail anchor_line
        end
      else
        fail class_attr_val
      end
    end
  end

  def capture_options(options)
    @noop = options[:noop]
    @info = options[:info]
    @noreline = options[:noreline]
    @doc_release = options[:release]
  end

  def get_toc_html
    # Construct the doc release; e.g., '3.4'.
    # Get the doc table of contents as a temp file.
    @toc_url = DocSite + @doc_release + '/table_of_contents.html'
    begin
      toc_file = URI.open(@toc_url)
      @toc_html = toc_file.read
    rescue Socket::ResolutionError => x
      message = "#{x.class}: #{x.message}\nPossibly not connected to internet."
      $stderr.puts(message)
      exit
    end
  end

  class Entry

    attr_accessor :full_name, :paths

    def initialize(full_name)
      self.full_name = full_name
      self.paths = []
    end

    # Return hash of choice strings for entries.
    def self.choices(entries)
      choices = {}
      entries.each_pair do |name, entry|
        entry.paths.each do |path|
          choice = self.choice(name, path)
          choices[choice] = path
        end
      end
      Hash[choices.sort]
    end

    def self.uri(path)
      URI.parse(path)
    end

    # Return the full name from a choice string.
    def self.full_name_for_choice(choice)
      choice.split(' ').first.sub(/:$/, '')
    end

  end

  class ClassEntry < Entry

    # Return a choice for a path.
    def self.choice(name, path)
      "#{name} (#{path})"
    end

  end

  class FileEntry < Entry

    # Return a choice for a path.
    def self.choice(name, path)
      "#{name} (#{path})"
    end

  end

  class SingletonMethodEntry < Entry

    # Return a choice string for a path.
    def self.choice(full_name, path)
      class_name, _ = path.split('.html#method-c-')
      class_name.gsub!('/', '::')
      "#{full_name} (in #{class_name})"
    end

  end

  class InstanceMethodEntry < Entry

    # Return a choice string for a path.
    def self.choice(full_name, path)
      class_name, _ = path.split('.html#method-i-')
      class_name.gsub!('/', '::')
      "#{full_name} (in #{class_name})"
    end

  end

  # Show a page of Ruby documentation.
  def show(name)
    # Figure out what's asked for.
    case
    when name.match(/^[A-Z]/)
      show_class(name, @index_for_type[:class])
    when %w[fatal fata fat fa f].include?(name)
      show_class(name, @index_for_type[:class])
    when name.start_with?('ruby:')
      show_file(name, @index_for_type[:page])
    when name.start_with?('::')
      show_singleton_method(name, @index_for_type[:singleton_method])
    when name.start_with?('#')
      show_instance_method(name, @index_for_type[:instance_method])
    when name == '@help'
      show_help
    when name == '@readme'
      open_readme
    # when name.start_with?('.')
    #   show_method(name, @index_for_type[:singleton_method], @index_for_type[:instance_method])
    # when name.match(/^[a-z]/)
    #   show_method(name, @index_for_type[:singleton_method], @index_for_type[:instance_method])
    else
      puts "No documentation available for name '#{name}'."
    end
  end

  # Show class.
  def show_class(name, class_index)
    all_entries = @index_for_type[:class]
    all_choices = ClassEntry.choices(all_entries)
    # Find entries whose names that start with name.
    selected_entries = all_entries.select do |key, value|
      key.start_with?(name)
    end
    # Find paths for selected_choices
    selected_paths = []
    selected_entries.each_pair do |name, entry|
      entry.paths.each do |path|
        selected_paths.push(path)
      end
    end
    case selected_paths.size
    when 1
      selected_choices = ClassEntry.choices(selected_entries)
      choice = selected_choices.keys.first
      path = selected_choices.values.first
      puts "Found one class/module name starting with '#{name}'\n  #{choice}"
      full_name = ClassEntry.full_name_for_choice(choice)
      if name != full_name
        message = "Open page #{path}?"
        return unless get_boolean_answer(message)
      end
      path
    when 0
      puts "Found no class/module name starting with '#{name}'."
      message = "Show #{all_choices.size} class/module names?"
      return unless get_boolean_answer(message)
      choice_index = get_choice(all_choices.keys)
      return if choice_index.nil?
      path = all_choices[choice_index]
    else
      selected_choices = ClassEntry.choices(selected_entries)
      puts "Found #{selected_choices.size} class/module names starting with '#{name}'."
      message = "Show #{selected_choices.size} class/module names?'"
      return unless get_boolean_answer(message)
      key = get_choice(selected_choices.keys)
      return if key.nil?
      path = selected_choices[key]
    end
    uri = Entry.uri(path)
    open_page(name, uri)
  end

  # Show page.
  def show_file(name, file_index)
    # Target page is a free-standing page such as 'COPYING'.
    name = name.sub(/^ruby:/, '') # Discard leading 'ruby:'
    all_entries = @index_for_type[:page]
    all_choices = FileEntry.choices(all_entries)
    # Find entries whose names that start with name.
    selected_entries = all_entries.select do |key, value|
      key.start_with?(name)
    end
    # Find paths for selected_choices
    selected_paths = []
    selected_entries.each_pair do |name, entry|
      entry.paths.each do |path|
        selected_paths.push(path)
      end
    end
    case selected_paths.size
    when 1
      selected_choices = FileEntry.choices(selected_entries)
      choice = selected_choices.keys.first
      path = selected_choices.values.first
      puts "Found one page name starting with '#{name}'\n  #{choice}"
      full_name = FileEntry.full_name_for_choice(choice)
      if name != full_name
        message = "Open page #{path}?"
        return unless get_boolean_answer(message)
      end
      path
    when 0
      puts "Found no page name starting with '#{name}'."
      message = "Show names of all #{all_choices.size} pages?"
      return unless get_boolean_answer(message)
      key = get_choice(all_choices.keys)
      return if key.nil?
      path = all_choices[key]
    else
      selected_choices = FileEntry.choices(selected_entries)
      puts "Found #{selected_choices.size} page names starting with '#{name}'."
      message = "Show #{selected_choices.size} names?'"
      return unless get_boolean_answer(message)
      key = get_choice(selected_choices.keys)
      return if key.nil?
      path = selected_choices[key]
    end
    uri = Entry.uri(path)
    open_page(name, uri)
  end

  # Show singleton method.
  def show_singleton_method(name, singleton_method_index)
    # Target page is a singleton method such as ::new.
    all_entries = @index_for_type[:singleton_method]
    all_choices = SingletonMethodEntry.choices(all_entries)
    # Find entries whose names that start with name.
    selected_entries = all_entries.select do |key, value|
      key.start_with?(name)
    end
    # Find paths for selected_choices
    selected_paths = []
    selected_entries.each_pair do |name, entry|
      entry.paths.each do |path|
        selected_paths.push(path)
      end
    end
    selected_choices = SingletonMethodEntry.choices(selected_entries)
    case selected_paths.size
    when 1
      full_name = selected_entries.keys.first
      path = selected_choices.values.first
      puts "Found one singleton method name starting with '#{name}'\n  #{full_name}"
      if name != full_name
        uri = URI.parse(path)
        message = "Open page #{uri.path} at method #{full_name}?"
        return unless get_boolean_answer(message)
      end
      path
    when 0
      puts "Found no singleton method name starting with '#{name}'."
      message = "Show names of all #{all_choices.size} singleton methods?"
      return unless get_boolean_answer(message)
      choice = get_choice(all_choices.keys)
      return if choice.nil?
      full_name = SingletonMethodEntry.full_name_for_choice(choice)
      path = all_choices[choice]
    else
      puts "Found #{selected_paths.size} singleton method names starting with '#{name}'."
      message = "Show #{selected_paths.size} names?'"
      return unless get_boolean_answer(message)
      choice = get_choice(selected_choices.keys)
      return if choice.nil?
      full_name = SingletonMethodEntry.full_name_for_choice(choice)
      path = all_choices[choice]
    end
    uri = Entry.uri(path)
    open_page(full_name, uri)
  end

  # Show instance method.
  def show_instance_method(name, instance_method_index)
    # Target page is an instance method such as #to_s.
    all_entries = @index_for_type[:instance_method]
    all_choices = InstanceMethodEntry.choices(all_entries)
    # Find entries whose names that start with name.
    selected_entries = all_entries.select do |key, value|
      key.start_with?(name)
    end
    # Find paths for selected_choices
    selected_paths = []
    selected_entries.each_pair do |name, entry|
      entry.paths.each do |path|
        selected_paths.push(path)
      end
    end
    selected_choices = InstanceMethodEntry.choices(selected_entries)
    case selected_paths.size
    when 1
      full_name = selected_entries.keys.first
      path = selected_choices.values.first
      puts "Found one instance method name starting with '#{name}'\n  #{full_name}"
      if name != full_name
        uri = URI.parse(path)
        message = "Open page #{uri.path} at method #{full_name}?"
        return unless get_boolean_answer(message)
      end
      path
    when 0
      puts "Found no instance method name starting with '#{name}'."
      message = "Show names of all #{all_choices.size} instance methods?"
      return unless get_boolean_answer(message)
      choice = get_choice(all_choices.keys)
      return if choice.nil?
      path = all_choices[choice]
      full_name = InstanceMethodEntry.full_name_for_choice(choice)
    else
      puts "Found #{selected_paths.size} instance method names starting with '#{name}'."
      message = "Show #{selected_paths.size} names?'"
      return unless get_boolean_answer(message)
      choice = get_choice(selected_choices.keys)
      return if choice.nil?
      path = all_choices[choice]
      full_name = InstanceMethodEntry.full_name_for_choice(choice)
    end
    uri = Entry.uri(path)
    open_page(full_name, uri)
  end

  def show_help
    puts 'Showing help.'
    puts `ruby bin/webri --help`
  end

  def show_readme
    open_readme
  end

  # Present choices; return choice.
  def get_choice(choices)
    index = nil
    range = (0..choices.size - 1)
    until range.include?(index)
      choices.each_with_index do |choice, i|
        s = "%6d" % i
        puts "  #{s}:  #{choice}"
      end
      while true
        print "Type a number to choose, or Return to skip:  "
        $stdout.flush
        response = $stdin.gets
        case response
        when /(\d+)/
          return choices[$1.to_i]
        when "\n"
          return nil
        else

        end
      end
    end
  end

  # Present question; return answer.
  def get_boolean_answer(question)
    print "#{question} (y or n):  "
    $stdout.flush
    $stdin.gets.match(/y/i) ? true : false
  end

  def open_readme
    url = 'https://github.com/BurdetteLamar/webri/blob/main/README.md'
    uri = URI.parse(url)
    open_uri('README',uri)
  end

  # Open URL in browser.
  def open_page(name, target_uri)
    uri = URI.parse(File.join(DocSite, @doc_release, target_uri.to_s))
    open_uri(name, uri)
  end

  def os_type
    case RbConfig::CONFIG['host_os']
    when /linux|bsd|arch/
      :linux
    when /darwin/
      :macos
    when /mswin|windows|32/
      :windows
    else
      :unknown
    end
  end

  def opener_name
    case os_type
    when :linux
      'xdg-open'
    when :windows
      'start'
    when :macos
      'open'
    else
      message = "No opener name for #{os_type}"
      raise RuntimeError(message)
    end
  end

  def open_uri(name, target_uri)
    full_url = target_uri.to_s
    url, fragment = full_url.split('#')
    message = "Opening web page #{url}"
    if fragment
      message += " at method #{name}"
    end
    message += '.'
    puts message
    command = "#{opener_name} #{full_url}"
    if @noop
      puts "Command: '#{command}'"
    else
      system(command)
    end
  end

end
