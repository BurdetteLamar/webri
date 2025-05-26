# frozen_string_literal: true
require 'rbconfig'
require 'open-uri'

# A class to display Ruby HTML documentation.
class WebRI

  # Where the official web pages are.
  DocSite = 'https://docs.ruby-lang.org/en/'

  attr_accessor :doc_release, :index_for_type

  # Get the info from the Ruby doc site's table of contents
  # and build our index_for_type.
  def initialize(options = {})
    # Construct the doc release; e.g., '3.4'.
    a = RUBY_VERSION.split('.')
    self.doc_release = a[0..1].join('.')
    # Get the doc table of contents as a temp file.
    toc_url = DocSite + self.doc_release + '/table_of_contents.html'
    toc_file = URI.open(toc_url)
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
        entry = ClassEntry.new(full_name, path)
        index = self.index_for_type[:class]
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

  end

  class MultiplePathEntry < Entry

    attr_accessor :paths

    def initialize(full_name)
      super(full_name)
      self.paths = []
    end

  end

  class FileEntry < MultiplePathEntry

    # Return array of choice strings for entries.
    def self.choices(entries)
      choices = {}
      entries.each_pair do |name, entry|
        entry.paths.each do |path|
          choice = self.choice(name, path)
          choices[choice] = path
        end
      end
      choices
      Hash[choices.sort]
    end

    # Return a choice for a path.
    def self.choice(name, path)
      a = path.split('/')
      a.pop.sub('_md', '').sub('_rdoc', '').sub('.html', '') + ' ' + path
      "#{name}: (#{path})"
    end

  end

  class MethodEntry < MultiplePathEntry

    # Return array of choice strings for entries.
    def self.choices(entries)
      choices = []
      entries.each_pair do |name, entry|
        entry.paths.each do |path|
          choice = self.choice(path)
          choices.push(choice)
        end
      end
      choices.sort
    end

    # Return a choice string for a path.
    def self.choice(path)
      class_name, method_name = path.split('.html#method-c-')
      class_name.gsub!('/', '::')
      "::#{method_name}: #{class_name}::#{method_name}"
    end

    # Return path string parsed out of choice string.
    def self.path(choice)
      path = choice.split(': ').last
      a = path.split('::')
      method_name = a.pop
      class_path = a.join('/')
      "#{class_path}.html#method-c-#{method_name}"
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
    found_entries = class_index.select do |full_name|
      full_name.start_with?(name)
    end
    case found_entries.size
    when 1
      full_name = found_entries.keys.first
      entry = found_entries[full_name]
      puts "Found one class or module name starting with '#{name}':\n  #{full_name}"
      if name != full_name
        message = "Open page #{full_name}"
        return unless get_boolean_answer(message)
      end
    when 0
      puts "Found no class/module name starting with '#{name}'."
      all_entries = index_for_type[:class]
      message = "Show names of all #{all_entries.size} classes/modules?"
      return unless get_boolean_answer(message)
      names = all_entries.keys
      choice_index = get_choice_index(names)
      return if choice_index.nil?
      name = names[choice_index]
      entry = all_entries[name]
    else
      puts "Found #{found_entries.size} class/module names starting with '#{name}'."
      message = "Show found names?'"
      return unless get_boolean_answer(message)
      names = found_entries.keys
      choice_index = get_choice_index(names)
      return if choice_index.nil?
      name = names[choice_index]
      entry = found_entries[name]
    end
    uri = Entry.uri(entry.path)
    open_url(uri.path.gsub('::', '/'))
  end

  # Show file.
  def show_file(name, file_index)
    # Target page is a free-standing page such as 'CONTRIBUTING'.
    name = name.sub(/^ruby:/, '') # Discard leading 'ruby:'
    all_entries = index_for_type[:file]
    all_choices = FileEntry.choices(all_entries)
    # Find file names that start with name.
    selected_entries = all_entries.select do |key, value|
      key.start_with?(name)
    end
    case selected_entries.size
    when 1
      choices = FileEntry.choices(selected_entries)
      choice = choices.keys.first
      path = choices.values.first
      puts "Found one file name starting with '#{name}'\n  #{choice}"
      full_name = choice.split(':').first
      if name != full_name
        message = "Open page #{path}"
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
      choices = FileEntry.choices(entries)
      puts "Found #{choices.size} file names starting with '#{name}'."
      message = "Show names?'"
      return unless get_boolean_answer(message)
      key = get_choice(choices.keys)
      return if key.nil?
      path = choices[key]
    end
    uri = Entry.uri(path)
    open_url(uri)
  end

  # Show singleton method.
  def show_singleton_method(name, singleton_method_index)
    # Target is a singleton method.
    # Find method names that start with name.
    entries = singleton_method_index.select do |method_name|
      method_name.start_with?(name)
    end
    case entries.size
    when 1
      # Found only one method name, but it can be in more than one class/module.
      full_name = entries.keys.first
      puts "Found one singleton method name starting with '#{name}':\n  #{full_name}"
      if name != full_name
        message = "Open page #{full_name}"
        return unless get_boolean_answer(message)
      end
      entry = entries.values.first
      path = entry.paths.first
    when 0
      puts "Found no singleton method name starting with '#{name}'."
      all_entries = index_for_type[:singleton_method]
      choices = MethodEntry.choices(all_entries)
      message = "Show names of all #{choices.size} singleton methods?"
      return unless get_boolean_answer(message)
      choice_index = get_choice_index(choices)
      return if choice_index.nil?
      choice = choices[choice_index]
      path = MethodEntry.path(choice)
    else
      puts "Found #{entries.size} singleton method names starting with '#{name}'."
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
    open_url(uri)
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
  def open_url(target_url)
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
    url = File.join(DocSite, doc_release, target_url)
    puts "Opening web page:\n  #{url}"
    command = "#{executable_name} #{url}"
    system(command)
  end

end
