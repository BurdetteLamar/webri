# frozen_string_literal: true

require 'rbconfig'
require 'reline'
require 'json'
require 'json/add/core'
require 'uri'

# TODO: Make it work on Aliki.
# TODO: Use reline.
#
# TODO: Subroutinize.
# TODO: Make initialization faster.

# TODO: Choose dynamically the test names (rather than fixed)?
# TODO: Test on Linux.
# TODO: Test all releases(?).0
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

  def initialize(options = {})
    capture_options(options)
    set_doc_release
    data_file_path = File.join('data', @doc_release + '.json')
    json = open(data_file_path).read
    @data = JSON.parse(json, create_additions: true)
    print_info if @info
    build_indexes
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
      @data.each_pair do |type, value|
        case
        when type == 'pages'
          completion_words += value.keys
        when type == 'classes'
          value.each_pair do |class_name, _value|
            completion_words << class_name
            _value['methods'].keys.each do |method_name|
              completion_words << method_name
            end
          end
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
    # If doc release not specified, get it from the local Ruby version.
    unless @doc_release
      a = RUBY_VERSION.split('.')
      @doc_release ||= a[0..1].join('.')
      puts "Documentation release defaulting to #{@doc_release} (the Ruby version you're running)."
      @doc_release
    end
    # If the doc release is not available, let them choose.
    releases = Dir.new('data').children.map {|dir| dir.sub('.json', '') }
    unless releases.include?(@doc_release)
      puts "Found no documentation release #{@doc_release}."
      puts "Index of releases:"
      @doc_release = get_choice(releases, required: true)
    end
  end

  def print_info
    puts "Ruby documentation release:  #{@doc_release}"
    puts "Ruby documentation site:     #{DocSite}"
    puts "Executable to open page:     #{opener_name}"
    puts "Names:"
    method_count = 0
    @data['classes'].each_pair do |_, value|
      method_count += value['methods'].size
    end
    {
      pages: @data['pages'].size,
      classes: @data['classes'].size,
      methods: method_count
    }.each_pair do |type, count|
      puts format("  %5d %s", count, type)
    end
    exit
  end

  def build_indexes
    # Index for each type of entry.
    # Each index has a hash; key is name, value is array of URIs.
    @index_for_type = {
      classes: {}, # Has both classes and modules.
      methods: {},
      pages: {},
    }
    @data['pages'].each_pair do |page_name, page_href|
      @index_for_type[:pages][page_name] = [page_href]
    end
    @data['classes'].each_pair do |class_name, hash|
      @index_for_type[:classes][class_name] = []
      @index_for_type[:classes][class_name] << hash['href']
      hash['methods'].each_pair do |method_name, method_href|
        @index_for_type[:methods][method_name] ||= []
        @index_for_type[:methods][method_name] << "#{class_name}#{method_href}"
      end
    end
  end

  def capture_options(options)
    @noop = options[:noop]
    @info = options[:info]
    @noreline = options[:noreline]
    @doc_release = options[:release]
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
      show_class(name, @index_for_type[:classes])
    when %w[fatal fata fat fa f].include?(name)
      show_class(name, @index_for_type[:classess])
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
  def show_class(name, classes)
    # Find classes whose names that start name.
    selected_classes = classes.select do |class_name, value|
      class_name.start_with?(name)
    end
    case selected_classes.size
    when 1
      full_name = selected_classes.keys.first
      href = selected_classes.values.first
      puts "Found one class/module name starting with '#{name}'\n  #{full_name}"
      if name != full_name
        message = "Open page #{name}?"
        return unless get_boolean_answer(message)
      end
      href
    when 0
      puts "Found no class/module name starting with '#{name}'."
      message = "Show #{classes.size} class/module names?"
      return unless get_boolean_answer(message)
      choice_index = get_choice(classes.keys)
      return if choice_index.nil?
      hrefs = classes[choice_index]
      hrefs.first
    else
      puts "Found #{selected_classes.size} class/module names starting with '#{name}'."
      message = "Show #{selected_classes.size} class/module names?'"
      return unless get_boolean_answer(message)
      choice_index = get_choice(selected_classes.keys)
      return if choice_index.nil?
      hrefs = classes[choice_index]
      p hrefs.first
    end
    open_page(name, href)
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
    puts `ruby exe/webri --help`
  end

  def show_readme
    open_readme
  end

  # Present choices; return choice.
  def get_choice(choices, required: false)
    index = nil
    range = (0..choices.size - 1)
    until range.include?(index)
      choices.each_with_index do |choice, i|
        s = "%6d" % i
        puts "  #{s}:  #{choice}"
      end
      while true
        message = if required
                    'Type a number to choose:  '
                  else
                    'Type a number to choose, or Return to skip:  '
                  end
        print message
        $stdout.flush
        response = $stdin.gets
        case response
        when /(\d+)/
          index = $1.to_i
          return choices[index] if index < choices.size
        when "\n"
          return nil unless required
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
  def open_page(name, href)
    uri = URI.parse(File.join(DocSite, @doc_release, href))
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
