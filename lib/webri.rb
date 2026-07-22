# frozen_string_literal: true

require 'rbconfig'
require 'reline'
require 'json'
require 'json/add/core'
require 'uri'
require 'open3'

require_relative 'scraper'

# TODO: Choose dynamically the test names (rather than fixed)?
# TODO: Test on Linux.
# TODO: Test all releases(?).
# TODO: Test all web pages(?).

# TODO: Make it work for:
# - Array.new
# - Array::new
# - Array.sort
# - Array#sort
# - .new
# - ::new
# - .sort
# - #sort

# TODO: Support pager.

# TODO: Support .webrirc.
# TODO: Make it save options to .webrirc.
# TODO: Make it show .webrirc.
# TODO: Support ENV.

# TODO: Support favorites.
# TODO: Support recents.
# TODO: Support direct in REPL; e.g., Array.sort.
# TODO: Support direct from command-line.
# TODO: Support partial on command-line, into REPL.
#
# TODO: Support alternate character for '\#' on command-line. ('3'?)
#
# TODO: Token begins with character, period, colon, or hashmark;
#       anything else could signal a special op.
#
# A class to display Ruby online HTML documentation.
class WebRI

  # Site of the official documentation.
  DOC_SITE = 'https://docs.ruby-lang.org/en/'

  attr_accessor :release_name,
                :href_for_class_name,
                :href_for_file_name,
                :href_for_singleton_method_name,
                :href_for_instance_method_name

  def initialize(release_name = nil, options = {})
    self.release_name = set_doc_release(release_name)
    capture_options(options)
    data_file_path = File.join('data', self.release_name + '.json')
    json = open(data_file_path).read
    @data = JSON.parse(json, create_additions: true)
    make_groups
    print_info if @info
    if os_type == :linux && !@noreline
      repl_reline
    else
      repl_plain
    end
  end

  def make_groups
    self.href_for_class_name = {}
    self.href_for_file_name = {}
    self.href_for_singleton_method_name = {}
    self.href_for_instance_method_name = {}
    @data['hrefs_for_name'].group_by do |name, hrefs|
      case
      when name.start_with?('ruby:')
        self.href_for_file_name[name] = hrefs.first
      when name.start_with?('#')
        self.href_for_instance_method_name[name] = hrefs
      when name.start_with?('::')
        self.href_for_singleton_method_name[name] = hrefs
      else
        self.href_for_class_name[name] = hrefs.first
      end
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
      completion_words= @data['hrefs_for_name'].keys.sort
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

  def set_doc_release(release_name)
    # If doc release not specified, get it from the local Ruby version.
    unless release_name
      s = RUBY_VERSION.split('.')
      release_name ||= s[0..1].join('.')
      puts "Documentation release defaulting to #{release_name} (the Ruby version you're running)."
      release_name
    end
    # If the doc release is not available, let them choose.
    release_names = Scraper.release_names
    unless release_names.include?(release_name)
      puts "Found no documentation release #{release_name}."
      puts "Releases:"
      release_name = get_choice_(release_names, required: true)
    end
    release_name
  end

  def print_info
    puts "Ruby documentation release:   #{release_name}"
    puts "Ruby documentation site:      #{DOC_SITE}"
    puts "Doc snapshot taken at:        #{@data['timestamp']}"
    puts "Executable to open web page:  #{opener_name}"
    puts "Names:"
    puts format("  %5d %s", href_for_file_name.size, 'Files')
    puts format("  %5d %s", href_for_class_name.size, 'Classes and modules')
    count = 0
    href_for_singleton_method_name.each_pair do |name, href_for_name|
      count += href_for_name.size
    end
    puts format("  %5d %s", count, 'Singleton methods')
    count = 0
    href_for_instance_method_name.each_pair do |name, href_for_name|
      count += href_for_name.size
    end
    puts format("  %5d %s", count, 'Instance methods')
    exit
  end

  def capture_options(options)
    @noop = options[:noop]
    @info = options[:info]
    @noreline = options[:noreline]
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
      show_class(name)
    when %w[fatal fata fat fa f].include?(name)
      show_class(name)
    when name.start_with?('ruby:')
      show_file(name)
    when name.start_with?('::')
      show_singleton_method(name)
    when name.start_with?('#')
      show_instance_method(name)
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

  def get_choice(situation, choices, type)
    puts situation
    count = choices.size
    if count > 20
      message = "Show #{count} #{type} names?"
      return nil unless get_boolean_answer(message)
    end
    get_choice_(choices)
  end

  # Show web page for selected file or class name.
  def show_web_page_for_file_or_class(partial_name, href_for_name, type)
    # Find names that start with partial name (which may in fact be the full name).
    selected_names = href_for_name.keys.select do |name|
      name.start_with?(partial_name)
    end
    count = selected_names.size
    selected_name =
      case count
      when 0
        situation = "Found no #{type} name starting with '#{partial_name}'."
        selected_name = get_choice(situation, href_for_name.keys, type)
        return if selected_name.nil?
        selected_name
      when 1
        full_name = selected_names.first
        puts "Found one #{type} name starting with '#{partial_name}': #{full_name}"
        if partial_name != full_name
          message = "Open web page #{full_name}?"
          return unless get_boolean_answer(message)
        end
        full_name
      else
        situation =  "Found #{count} #{type} names starting with '#{partial_name}'."
        selected_name = get_choice(situation, selected_names, type)
        return if selected_name.nil?
        selected_name
      end
    href = href_for_name[selected_name]
    show_web_page(selected_name, href)
  end

  # Show web page for selected class.
  def show_class(partial_name)
    show_web_page_for_file_or_class(partial_name, href_for_class_name, 'class/module')
  end

  # Show web page for selected file.
  def show_file(partial_name)
    show_web_page_for_file_or_class(partial_name, href_for_file_name, 'file')
  end

  # Show web page for selected method name.
  def show_web_page_for_method(partial_name, href_for_name, type)
    # Find names that start with partial name (which may in fact be the full name).
    selected_names = href_for_name.keys.select do |name|
      name.start_with?(partial_name)
    end
    count = selected_names.size
    selected_name =
      case count
      when 0
        situation = "Found no #{type} name starting with '#{partial_name}'."
        selected_name = get_choice(situation, href_for_name, type)
        return if selected_name.nil?
        selected_name
      when 1
        full_name = selected_names.first
        puts "Found one #{type} name starting with '#{partial_name}': #{full_name}"
        if partial_name != full_name
          message = "Open web page #{full_name}?"
          return unless get_boolean_answer(message)
        end
        full_name
      else
        situation = "Found #{count} #{type} names starting with '#{partial_name}'."
        selected_name = get_choice(situation, selected_names, type)
        return if selected_name.nil?
        selected_name
      end
    qualified_names = []
    @data['classes_for_method'][selected_name].each do |class_name|
      qualified_names << "#{class_name}#{selected_name}"
    end
    count = qualified_names.size
    if count == 1
      puts "Found 1 class that has method '#{selected_name}'."
      qualified_name = qualified_names.first
    else
      situation = "Found #{count} classes that have method '#{selected_name}'."
      qualified_name = get_choice(situation, qualified_names, type)
      return if qualified_name.nil?
    end
    method_href = href_for_name[selected_name]
    class_name = qualified_name.sub(selected_name, '')
    href = "#{class_name}.html#{method_href}"
    show_web_page(selected_name, href)
  end

  # Show web page for singleton method.
  def show_singleton_method(partial_name)
    show_web_page_for_method(partial_name, href_for_singleton_method_name, 'singleton method')
  end

  # Show web page for instance method.
  def show_instance_method(partial_name)
    show_web_page_for_method(partial_name, href_for_instance_method_name, 'instance method')
  end

  def show_help
    puts 'Showing help.'
    puts `ruby exe/webri --help`
  end

  def show_readme
    open_readme
  end

  # Present choices; return choice.
  def get_choice_(choices, required: false)
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
  def show_web_page(name, href)
    href.gsub!('::', '/')
    uri = URI.parse(File.join(DOC_SITE, release_name, href))
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
      # system(command)
      Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
      end
    end
  end

  def self.get_webri_root_dir
    webri_root_dir = `git rev-parse --show-toplevel`.chomp
    if $?.success? && File.basename(webri_root_dir) == 'webri'
      return webri_root_dir
    end
    message = "Current working directory must be in a webri project, not #{Dir.pwd}."
    puts message
    exit
  end

  def self.check_release_name(release_name)
    release_names = Scraper.release_names
    unless release_names.include?(release_name)
      message = "Release must be one of #{release_names.inspect}, not #{release_name.inspect}."
      puts message
      exit 1
    end
  end

end
