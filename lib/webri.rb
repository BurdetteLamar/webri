# frozen_string_literal: true

require 'rbconfig'
require 'reline'
require 'json'
require 'json/add/core'
require 'uri'
require 'open3'

# TODO: Make it work on Aliki.
# TODO: Use reline.
#
# TODO: Subroutinize.
# TODO: Make initialization faster.

# TODO: Choose dynamically the test names (rather than fixed)?
# TODO: Test on Linux.
# TODO: Test all releases(?).0
# TODO: Test all web pages(?).

# TODO: Make it work for naked method ('parse') or dotted method ('.parse').

# TODO: Support pager.

# TODO: Support .webrirc.
# TODO: Make it save options to .webrirc.
# TODO: Make it show .webrirc.

# A class to display Ruby online HTML documentation.
class WebRI

  # Site of the official documentation.
  DOC_SITE = 'https://docs.ruby-lang.org/en/'
  
  attr_accessor :href_for_class_name,
                :href_for_file_name,
                :href_for_singleton_method_name,
                :href_for_instance_method_name

  def initialize(options = {})
    capture_options(options)
    set_doc_release
    data_file_path = File.join('data', @doc_release + '.json')
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
    puts "Ruby documentation site:     #{DOC_SITE}"
    puts "Executable to open web page: #{opener_name}"
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

  # Show web page for selected name.
  def show_web_page_for_file_or_class(partial_name, href_for_name, type)
    # Find names that start with partial name (which may in fact be the full name).
    selected_names = href_for_name.keys.select do |name|
      name.start_with?(partial_name)
    end
    count = selected_names.size
    selected_name =
      case count
      when 0
        puts "Found no #{type} name starting with '#{partial_name}'."
        message = "Show #{href_for_name.size} #{type} names?"
        return unless get_boolean_answer(message)
        selected_name = get_choice(href_for_name.keys)
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
        puts "Found #{count} #{type} names starting with '#{partial_name}'."
        message = "Show #{selected_names.size} #{type} names?'"
        return unless get_boolean_answer(message)
        selected_name = get_choice(selected_names)
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

  # Show singleton method.
  def show_singleton_method(partial_name)
    show_web_page_for_method(partial_name, href_for_singleton_method_name, 'singleton method')
  end

  # Show instance method.
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
  def show_web_page(name, href)
    uri = URI.parse(File.join(DOC_SITE, @doc_release, href))
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

end
