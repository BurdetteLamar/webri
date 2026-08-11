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

# TODO: Directives: name begins with capital letter, 'ruby:', period, colon, or hashmark;
#       directive would begin with something else.
# - @readme: Open README.
# - @classes: Open
# - ?help: Print help.
# - ?classes: Print help for classes/modules.
# - ?instance_methods: Print help for instance methods.
# - ?singleton_methods: Print help for singleton methods.
# - ?files: Print help for files.
# - !classes: Print all class/module names.
# - !instance_methods: Print all instance method names.
# - !singleton_methods: Print all singleton method names.
# - !files: Print all file names.
#
#
# TODO: Make it work for:
# - Array.new
# - Array::new
# - Array.sort
# - Array#sort
# - Array.[]
# - Array::[]
# - Arrya#[]
# - .new
# - ::new
# - .sort
# - #sort

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
# A class to display Ruby online HTML documentation.
class WebRI

  # Site of the official documentation.
  DOC_SITE = 'https://docs.ruby-lang.org/en/'

  def self.prompt
    "(Type #{WebRI.tokenq('?')} for help, #{WebRI.tokenq('exit')} to exit) #{self.webri}> "
  end

  CLASS = 'class/module'
  SINGLETON = 'singleton method'
  INSTANCE = 'instance method'
  FILE = 'file'

  attr_accessor :release_name,
                :href_for_class_name,
                :href_for_file_name,
                :href_for_singleton_method_name,
                :href_for_instance_method_name

  @@noansi = false

  def initialize(name = nil, options = {})
    capture_options(options)
    self.release_name = set_doc_release(@release_name)
    data_file_path = File.expand_path("../data/#{self.release_name}.json", __dir__)
    json = open(data_file_path).read
    @data = JSON.parse(json, create_additions: true)
    make_groups
    print_info if @info
    if name
      do_name(name)
    elsif os_type == :linux && !@noreline
      repl_reline
    else
      repl_plain
    end
  end

  def do_name(name)
    show(name)
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
      $stdout.write(WebRI.prompt)
      $stdout.flush
      response = $stdin.gets.chomp
      exit if response == 'exit'
      next if response.empty?
      if response.start_with?('?')
        help(response)
        next
      end
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
      while line = Reline.readline(WebRI.prompt, true)
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
    puts "Ruby documentation:"
    puts "  Release:   #{release_name}"
    puts "  Site:      #{DOC_SITE}"
    puts "  Snapshot:  #{@data['timestamp']}"
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
    @@noansi = options[:noansi]
    @release_name = options[:release_name]
  end

  # class Entry
  #
  #   attr_accessor :full_name, :paths
  #
  #   def initialize(full_name)
  #     self.full_name = full_name
  #     self.paths = []
  #   end
  #
  #   # Return hash of choice strings for entries.
  #   def self.choices(entries)
  #     choices = {}
  #     entries.each_pair do |name, entry|
  #       entry.paths.each do |path|
  #         choice = self.choice(name, path)
  #         choices[choice] = path
  #       end
  #     end
  #     Hash[choices.sort]
  #   end
  #
  #   def self.uri(path)
  #     URI.parse(path)
  #   end
  #
  #   # Return the full name from a choice string.
  #   def self.full_name_for_choice(choice)
  #     choice.split(' ').first.sub(/:$/, '')
  #   end
  #
  # end
  #
  # class ClassEntry < Entry
  #
  #   # Return a choice for a path.
  #   def self.choice(name, path)
  #     "#{name} (#{path})"
  #   end
  #
  # end
  #
  # class FileEntry < Entry
  #
  #   # Return a choice for a path.
  #   def self.choice(name, path)
  #     "#{name} (#{path})"
  #   end
  #
  # end
  #
  # class SingletonMethodEntry < Entry
  #
  #   # Return a choice string for a path.
  #   def self.choice(full_name, path)
  #     class_name, _ = path.split('.html#method-c-')
  #     class_name.gsub!('/', '::')
  #     "#{full_name} (in #{class_name})"
  #   end
  #
  # end
  #
  # class InstanceMethodEntry < Entry
  #
  #   # Return a choice string for a path.
  #   def self.choice(full_name, path)
  #     class_name, _ = path.split('.html#method-i-')
  #     class_name.gsub!('/', '::')
  #     "#{full_name} (in #{class_name})"
  #   end
  #
  # end

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

  # Show web page for selected class name.
  def show_class(partial_name)
    show_web_page_for_file_or_class(partial_name, href_for_class_name, CLASS)
  end

  # Show web page for selected file name.
  def show_file(partial_name)
    show_web_page_for_file_or_class(partial_name, href_for_file_name, FILE)
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
      puts "Found one #{CLASS} that has method '#{selected_name}'."
      qualified_name = qualified_names.first
    else
      situation = "Found #{count} #{type} names that have method '#{selected_name}'."
      qualified_name = get_choice(situation, qualified_names, type)
      return if qualified_name.nil?
    end
    method_href = href_for_name[selected_name]
    class_name = qualified_name.sub(selected_name, '')
    href = "#{class_name}.html#{method_href}"
    show_web_page(selected_name, href)
  end

  # Show web page for singleton method name.
  def show_singleton_method(partial_name)
    show_web_page_for_method(partial_name, href_for_singleton_method_name, SINGLETON)
  end

  # Show web page for instance method name.
  def show_instance_method(partial_name)
    show_web_page_for_method(partial_name, href_for_instance_method_name, INSTANCE)
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
    lines = []
    index = nil
    range = (0..choices.size - 1)
    until range.include?(index)
      choices.each_with_index do |choice, i|
        s = "%6d" % i
        token = WebRI.token(choice)
        lines << "  #{s}:  #{token}"
      end
      while true
        message = if required
                    'Type a number to choose:  '
                  else
                    'Type a number to choose, or Return to skip:  '
                  end
        lines << message
        s = lines.join("\n")
        require "mkmf"

        pager =
          ENV["PAGER"] ||
          if find_executable("less")
            'less -RFX'
          else
            'more'
          end
        begin
          IO.popen(pager, "w") do |io|
            io.puts s
          rescue Errno::EPIPE
            puts message
          end
        end
        response = $stdin.gets
        case response
        when /(\d+)/
          index = $1.to_i
          return choices[index] if index < choices.size
        when "\n"
          return nil unless required
        else
          # Continue
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
      # puts "Command: '#{command}'"
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

  def help(response)
    puts WebRI::HELP
  end

  ANSI_COLOR = {
    black: 30,
    red: 31,
    green: 32,
    yellow: 33,
    blue: 34,
    magenta: 35,
    cyan: 36,
    white: 37,
    bright_black: 90,
    bright_red: 91,
    bright_green: 92,
    bright_yellow: 93,
    bright_blue: 94,
    bright_magenta: 95,
    bright_cyan: 96,
    bright_white: 97,
  }

  def self.ansi_color(s, color)
    return s if @@noansi
    "\e[#{ANSI_COLOR[color]}m#{s}\e[0m"
  end

  def self.webri
    self.ansi_color('webri', :cyan)
  end

  def self.variable(s)
    self.ansi_color(s, :yellow)
  end

  def self.string(s)
    self.ansi_color("'#{s}'", :green)
  end

  def self.token(s)
    color = case s
            when /^[A-Z]/
              :bright_blue
            when /^::/
              :bright_yellow
            when /^#/
              :bright_green
            when /^ruby:/
              :bright_red
            else
              :bright_cyan
            end
    self.ansi_color("#{s}", color)
  end

  def WebRI.tokenq(s)
    "'" + WebRI.token("#{s}") + "'"
  end

  def self.file_name(s)
    self.ansi_color("#{s}", :red)
  end

  def self.singleton_method_name(s)
    self.ansi_color("#{s}", :magenta)
  end

  def self.instance_method_name(s)
    self.ansi_color("#{s}", :cyan)
  end

  def self.class_name(s)
    self.ansi_color("#{s}", :bright_blue)
  end

  def self.bold(s)
    "\033[1m#{s}\033[0m"
  end

  def self.bold_italic(s)
    "\033[1;3m#{s}\033[0m"
  end

  HELP = <<EOT

If argument #{WebRI.variable('name')} is given, #{WebRI.webri} operates in its immediate mode,
which means that it processes that one #{WebRI.variable('name')} (possibly with some minor interaction),
then exits.

If argument #{WebRI.variable('name')} is not given, #{WebRI.webri} operates in its interactive mode,
which means that enter a read-evaluate-print loop (REPL).

#{WebRI.bold_italic('Names')}

Argument #{WebRI.variable('name')} is one of four types, as determined by its prefix:

|------------------|----------------|--------------------|
|       Type       |     Prefix     |      Example       |
|------------------|----------------|--------------------|
| Class/module     | Capital letter | #{WebRI.tokenq('Array')}            |
| Singleton method | #{WebRI.tokenq('::')}           | #{WebRI.tokenq('::new')}            |
| Instance method  | #{WebRI.tokenq('#')}            | #{WebRI.tokenq('#inspect')}         |
| Ruby file        | #{WebRI.tokenq('ruby:')}        | #{WebRI.tokenq('ruby:syntax_rdoc')} |
|------------------|----------------|--------------------|

Note: On the command-line, your shell may require you to escape the instance method prefix:

    #{WebRI.string('\\#size')} (instead of just #{WebRI.string('#size')})

#{WebRI.bold_italic('Classes and Modules')}

To get the web page for a class or module,
type a #{WebRI.variable('name')} starting with a capital letter.

When the #{WebRI.variable('name')} is:

- The exact name of a class/module (but not the beginning of other such names):
  #{WebRI.webri} opens the page for that class/module.
  Examples: #{WebRI.tokenq('Array')}, #{WebRI.tokenq('Hash')}, #{WebRI.tokenq('Struct')}, #{WebRI.tokenq('Integer')}, #{WebRI.tokenq('Symbol')}.

- The abbreviated name of exactly one class/module:
  #{WebRI.webri} asks whether to open the page for that class/module.
  Examples:

  - #{WebRI.tokenq('Cov')}          (for #{WebRI.tokenq('Coverage')}).
  - #{WebRI.tokenq('Eng')}          (for #{WebRI.tokenq('English')}).
  - #{WebRI.tokenq('Ker')}          (for #{WebRI.tokenq('Kernel')}).
  - #{WebRI.tokenq('Net::HTTP::D')} (for #{WebRI.tokenq('Net::HTTP::Delete')}).}

- The abbreviated name of multiple classes/modules:
  #{WebRI.webri} asks whether to open the page for that class/module;
  if Yes, #{WebRI.webri} displays those names and lets you choose.
  Examples: #{WebRI.tokenq('String')}, #{WebRI.tokenq('Float')}, #{WebRI.tokenq('Regexp')}, #{WebRI.tokenq('Net::HTTP')}.

- Not the abbreviated name of any class/module:
  #{WebRI.webri} asks whether show all class/module names.
  Examples: #{WebRI.tokenq('Xyzzy')}, #{WebRI.tokenq('Nosuch')}.

#{WebRI.bold_italic('Files')}

To get the web page for a Ruby file,
type a #{WebRI.variable('name')} starting with #{WebRI.tokenq('ruby:')}.

When the #{WebRI.variable('name')} is:

- The exact name of a Ruby file (but not the beginning of other such names):
  #{WebRI.webri} opens the page for that file.
  Examples: #{WebRI.tokenq('ruby:README_md')}, #{WebRI.tokenq('ruby:LEGAL')}, #{WebRI.tokenq('ruby:NEWS_md')}, #{WebRI.tokenq('ruby:syntax_rdoc')}.

- The partial name of exactly one file:
  #{WebRI.webri} asks whether to open the page for that file.
  Examples: 
 
  - #{WebRI.tokenq('ruby:maint')}              (for #{WebRI.tokenq('ruby:maintainers_md')})
  - #{WebRI.tokenq('ruby:syntax/assign')}      (for #{WebRI.tokenq('ruby:syntax/assignment_rdoc')})
  - #{WebRI.tokenq('ruby:language/pack')}      (for #{WebRI.tokenq('ruby:language/packed_data_rdoc')})
  - #{WebRI.tokenq('ruby:contributing/build')} (for #{WebRI.tokenq('ruby:contributing/building_ruby_md')})
  - #{WebRI.tokenq('ruby:optparse/arg')}       (for #{WebRI.tokenq('ruby:optparse/argument_converters_rdoc')}).

- The partial name of multiple files:
  #{WebRI.webri} displays those names and lets you choose.
  Examples: #{WebRI.tokenq('ruby:syntax')}, #{WebRI.tokenq('ruby:contrib')}, #{WebRI.tokenq('ruby:lang')}, #{WebRI.tokenq('ruby:jit')}.

- Not the partial name of any file:
  #{WebRI.webri} asks whether show all file names.
  Examples: #{WebRI.tokenq('ruby:xyzzy')}, #{WebRI.tokenq('ruby:nosuch')}.

#{WebRI.bold_italic('Instance Methods')}

To get the web page for an instance method (and scroll to that method),
type a #{WebRI.variable('name')} starting with #{WebRI.tokenq('#')}.

When the #{WebRI.variable('name')} is:

- The exact name of an instance method (but not the beginning of other such names):

  - If that method appears in only one class/module,
    #{WebRI.webri} opens the page for that class-module and scrolls to the method.
    Examples: #{WebRI.tokenq('#abbreviate')}, #{WebRI.tokenq('#mountpoint?')}, #{WebRI.tokenq('#xmlschema')}.

  - If the method appears in multiple classes/modules,
    #{WebRI.webri} shows them and lets you choose; for your choice,
    #{WebRI.webri} opens the page for that class-module and scrolls to the method.
    Examples: #{WebRI.tokenq('#birthtime')}, #{WebRI.tokenq('#frozen?')}, #{WebRI.tokenq('#owner')}.
 
- The partial name of multiple instance methods:
  #{WebRI.webri} asks whether to show those names;
  if Yes, shows them and lets you choose; for your choice,
  #{WebRI.webri} opens the page for that class-module and scrolls to the method.
  Examples: #{WebRI.tokenq('#alias')}, #{WebRI.tokenq('#line')}, #{WebRI.tokenq('#rm')}.

- Not the partial name of any instance method:
  #{WebRI.webri} asks whether show all instance method names.
  Examples: #{WebRI.tokenq('#xyzzy')}, #{WebRI.tokenq('#nosuch')}.

EOT


end
