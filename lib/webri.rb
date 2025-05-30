# frozen_string_literal: true
require 'rbconfig'
require 'open-uri'

# TODO: Update help text.
# TODO: Add --release option.
# TODO: Test all releases.
# TODO: Test options.
# TODO: Test all pages(?).
# TODO: Show all release numbers; allow choice.
# TODO: Test whether there are multi-path entries in files, methods.
# TODO: Support interactive mode (remain in app).
# TODO: Support pager.
# TODO: Update README.md.
# TODO: Support .webrirc.
# TODO: Review RI docs, options, and help.
# TODO: Review RDoc docs, options, and help.

# A class to display Ruby HTML documentation.
class WebRI

  # Where the official web pages are.
  DocSite = 'https://docs.ruby-lang.org/en/'

  attr_accessor :doc_release, :index_for_type, :noop

  # Get the info from the Ruby doc site's table of contents
  # and build our index_for_type.
  def initialize(options = {})
    self.noop = options[:noop]
    # Construct the doc release; e.g., '3.4'.
    a = RUBY_VERSION.split('.')
    self.doc_release = a[0..1].join('.')
    # Get the doc table of contents as a temp file.
    toc_url = DocSite + self.doc_release + '/table_of_contents.html'
    begin
      toc_file = URI.open(toc_url)
    rescue Socket::ResolutionError => x
      message = "#{x.class}: #{x.message}\nPossibly not connected to internet."
      $stderr.puts(message)
      exit
    end

    # Index for each type of entry.
    # Each index has a hash; key is name, value is array of URIs.
    self.index_for_type = {
      class: {}, # Has both classes and modules.
      file: {},
      singleton_method: {},
      instance_method: {},
    }
    # Iterate over the lines of the TOC page.
    lines = toc_file.readlines
    i = 0
    while i < lines.count
      item_line = lines[i]
      i += 1
      next unless item_line.match('<li class="(\w+)"')
      class_attr_value = $1 # Save for later.
      # We have a triplet of lines such as:
      #     <li class="file">
      #       <a href="COPYING.html">COPYING</a>
      #     </li>
      anchor_line = lines[i] # Second line of triplet.
      # Consume anchor_line and third (unused) line.
      i += 2
      # We capture variables thus:
      # - +type+ is the value of attribute 'class'.
      # - +path+ is the value of attribute 'href'.
      # - +full_name+ is the HTML text.
      type = class_attr_value
      _, path, rest = anchor_line.split('"')
      full_name = rest.split(/<|>/)[1]
      case type
      when 'class', 'module'
        index = self.index_for_type[:class]
        entry = ClassEntry.new(full_name, path)
        index[full_name] = entry
      when 'file'
        index = self.index_for_type[:file]
        if index.include?(full_name)
          entry = index[full_name]
        else
          entry = FileEntry.new(full_name)
          index[full_name] = entry
        end
        entry.paths.push(path)
      when 'method'
        case anchor_line
        when /method-c-/
          index = self.index_for_type[:singleton_method]
          if index.include?(full_name)
            entry = index[full_name]
          else
            entry = MethodEntry.new(full_name)
            index[full_name] = entry
          end
          entry.paths.push(path)
        when /method-i-/
          index = self.index_for_type[:instance_method]
          if index.include?(full_name)
            entry = index[full_name]
          else
            entry = MethodEntry.new(full_name)
            index[full_name] = entry
          end
          entry.paths.push(path)
        else
          fail anchor_line
        end
      else
        fail class_attr_val
      end
    end
  end

  class Entry

    attr_accessor :full_name

    def initialize(full_name)
      self.full_name = full_name
    end

    def self.uri(path)
      URI.parse(path)
    end

  end

  class ClassEntry < Entry

    attr_accessor :path

    def initialize(full_name, path)
      super(full_name)
      self.path = path
    end

    # Return hash of name/path pairs for entries.
    def self.choices(entries)
      choices = {}
      entries.each_pair do |name, entry|
        path = entry.path
        choices[name] = path
      end
      choices
    end

  end

  class MultiplePathEntry < Entry

    attr_accessor :paths

    def initialize(full_name)
      super(full_name)
      self.paths = []
    end

    # Return array of choice strings for entries.
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

  end

  class FileEntry < MultiplePathEntry

    # Return a choice for a path.
    def self.choice(name, path)
      a = path.split('/')
      a.pop.sub('_md', '').sub('_rdoc', '').sub('.html', '') + ' ' + path
      "#{name}: (#{path})"
    end

    # Return the full name from a choice string.
    def self.full_name_for_choice(choice)
      choice.split(':').first
    end

  end

  class MethodEntry < MultiplePathEntry

    # Return array of choice strings for entries.
    def self.choices(entries)
      choices = {}
      entries.each_pair do |name, entry|
        entry.paths.each do |path|
          choice = self.choice(path)
          choices[choice] = path
        end
      end
      Hash[choices.sort]
    end

    # Return a choice string for a path.
    def self.choice(path)
      class_name, method_name = path.split('.html#method-c-')
      class_name.gsub!('/', '::')
      "::#{method_name} (in #{class_name})"
    end

  end

  # Show a page of Ruby documentation.
  def show(name)
    # Figure out what's asked for.
    case
    when name.match(/^[A-Z]/)
      show_class(name, index_for_type[:class])
    when name.start_with?('ruby:')
      show_file(name, index_for_type[:file])
    when name.start_with?('::')
      show_singleton_method(name, index_for_type[:singleton_method])
    when name.start_with?('#')
      show_instance_method(name, index_for_type[:instance_method])
    when name.start_with?('.')
      show_method(name, index_for_type[:singleton_method], index_for_type[:instance_method])
    when name.match(/^[a-z]/)
      show_method(name, index_for_type[:singleton_method], index_for_type[:instance_method])
    else
      fail name
    end
  end

  # Show class.
  def show_class(name, class_index)
    # Target is a class or module.
    # Find class and module names that start with name.
    all_entries = index_for_type[:class]
    choices = ClassEntry.choices(all_entries)
    # Find entries whose names that start with name.
    candidate_entries = all_entries.select do |key, value|
      key.start_with?(name)
    end
    case candidate_entries.size
    when 1
      selected_choices = ClassEntry.choices(candidate_entries)
      choice = selected_choices.keys.first
      path = selected_choices.values.first
      puts "Found one class or module name starting with '#{name}':\n  #{choice}"
      full_name = FileEntry.full_name_for_choice(choice)
      if name != full_name
        message = "Open page #{path}?"
        return unless get_boolean_answer(message)
      end
      path
    when 0
      puts "Found no class or module name starting with '#{name}'."
      message = "Show names of all #{choices.size} classes and modules?"
      return unless get_boolean_answer(message)
      key = get_choice(choices.keys)
      return if key.nil?
      path = choices[key]
    else
      selected_choices = ClassEntry.choices(candidate_entries)
      puts "Found #{selected_choices.size} class and module names starting with '#{name}'."
      message = "Show names?'"
      return unless get_boolean_answer(message)
      key = get_choice(selected_choices.keys)
      return if key.nil?
      path = selected_choices[key]
    end
    uri = Entry.uri(path)
    open_url(name, uri.path.gsub('::', '/'))
  end

  # Show file.
  def show_file(name, file_index)
    # Target page is a free-standing page such as 'COPYING'.
    name = name.sub(/^ruby:/, '') # Discard leading 'ruby:'
    all_entries = index_for_type[:file]
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
      puts "Found one file name starting with '#{name}'\n  #{choice}"
      full_name = FileEntry.full_name_for_choice(choice)
      if name != full_name
        message = "Open page #{path}?"
        return unless get_boolean_answer(message)
      end
      path
    when 0
      puts "Found no file name starting with '#{name}'."
      message = "Show names of all #{all_choices.size} files?"
      return unless get_boolean_answer(message)
      key = get_choice(all_choices.keys)
      return if key.nil?
      path = all_choices[key]
    else
      selected_choices = FileEntry.choices(selected_entries)
      puts "Found #{selected_choices.size} file names starting with '#{name}'."
      message = "Show names?'"
      return unless get_boolean_answer(message)
      key = get_choice(selected_choices.keys)
      return if key.nil?
      path = selected_choices[key]
    end
    uri = Entry.uri(path)
    open_url(name, uri)
  end

  # Show singleton method.
  def show_singleton_method(name, singleton_method_index)
    # Target page is a singleton method such as ::new.
    all_entries = index_for_type[:singleton_method]
    all_choices = MethodEntry.choices(all_entries)
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
      selected_choices = MethodEntry.choices(selected_entries)
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
      path = all_choices[choice]
    else
      puts "Found #{selected_paths.size} singleton method names starting with '#{name}'."
      message = "Show names?'"
      return unless get_boolean_answer(message)
      choices =
      names = hrefs.map {|href| href[0] }
      choices = []
      hrefs.each do |href|
        next
        class_name = href[1].split('.', 2).first
        choices.push(class_name + name)
      end
      puts choices
      choice_index = get_choice_index(choices)
      method_name = names[choice_index]
      hrefs = hrefs[method_name].sort
      methods = hrefs.map do|href|
        href.split('.html').first + method_name
      end
      if methods.size == 1
        href = hrefs.first
      else
        method_index = get_choice_index(methods)
        href = hrefs[method_index]
      end
    end
    uri = Entry.uri(path)
    open_url(name, uri)
  end

  # Show instance method.
  def show_instance_method(name, instance_method_index)
    hrefs = instance_method_index.select do |method_name|
      method_name.start_with?(name)
    end
    case hrefs.size
    when 1
      href = hrefs.first.last
      open_url(href)
    when 0
      puts "Nothing known about #{name}."
    else
      names = hrefs.map {|href| href[0] }
      choice_index = get_choice_index(names)
      method_name = names[choice_index]
      hrefs = hrefs[method_name].sort
      methods = hrefs.map do|href|
        href.split('.html').first + method_name
      end
      if methods.size == 1
        href = hrefs.first
        open_url(href)
      else
        method_index = get_choice_index(methods)
        href = hrefs[method_index]
        open_url(href)
      end
    end
  end

  # Show singleton or instance method.
  def show_method(name, singleton_method_index, instance_method_index)
    singleton_name = name.sub('.', '::')
    instance_name = name.sub('.', '#')
    hrefs = index_for_type[:method].select do |method_name|
      method_name.start_with?(singleton_name) ||
        method_name.start_with?(instance_name)
    end
    case hrefs.size
    when 1
      href = hrefs.first.last
      open_url(href)
    when 0
      puts "Nothing known about #{name}."
    else
      names = hrefs.map {|href| href[0] }
      choice_index = get_choice_index(names)
      method_name = names[choice_index]
      hrefs = hrefs[method_name].sort
      methods = hrefs.map do|href|
        href.split('.html').first + method_name
      end
      if methods.size == 1
        href = hrefs.first
        open_url(href)
      else
        method_index = get_choice_index(methods)
        href = hrefs[method_index]
        open_url(href)
      end
    end
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
      print "Choose (#{range}):  "
      $stdout.flush
      response = gets
      index = response.match(/^\d+$/) ? response.to_i : -1
      return if index == -1
    end
    choices[index]
  end

  # Present question; return answer.
  def get_boolean_answer(question)
    print "#{question} (y or n):  "
    $stdout.flush
    gets.match(/y/i) ? true : false
  end

  # Open URL in browser.
  def open_url(name, target_url)
    host_os = RbConfig::CONFIG['host_os']
    executable_name = case host_os
                      when /linux|bsd/
                        'xdg-open'
                      when /darwin/
                        'open'
                      when /32$/
                        'start'
                      else
                        message = "Unrecognized host OS: '#{host_os}'."
                        raise RuntimeError.new(message)
                      end
    uri = URI.parse(File.join(DocSite, doc_release, target_url))
    url = uri.to_s
    message = "Opening web page #{url}"
    fragment = uri.fragment
    message += " to method #{fragment}" if fragment
    puts message
    command = "#{executable_name} #{url}"
    if noop
      puts "Command: '#{command}'"
    else
      system(command)
    end
  end

end
