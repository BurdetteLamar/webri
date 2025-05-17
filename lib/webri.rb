# frozen_string_literal: true
require 'rbconfig'
require 'open-uri'
require 'rexml'

# A class to display Ruby HTML documentation.
class WebRI

  # Where the official web pages are.
  DocSite = 'https://docs.ruby-lang.org/en/'

  attr_accessor :doc_release, :indexes

  # Get the info from the Ruby doc site's table of contents
  # and build our indexes.
  def initialize(options = {})
    # Construct the doc release; e.g., '3.4'.
    _ = RbConfig.ruby.split('Ruby').last[0..1]
    self.doc_release = _[0] + '.' + _[1]
    # Get the doc table of contents as a temp file.
    toc_url = DocSite + self.doc_release + '/table_of_contents.html'
    toc_file = URI.open(toc_url)
    # Index for each type of entry.
    # Each index has a hash; key is name, value is array of hrefs.
    self.indexes = {
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
      # We have a triplet of lines such as:
      #     <li class="file">
      #       <a href="COPYING.html">COPYING</a>
      #     </li>
      class_attr_val = $1
      href_line = lines[i] # Second line of triplet.
      # Consume href_line and third (unused) line.
      i += 2
      # We capture variables thus:
      # - +type+ is the value of attribute 'class'.
      # - +href+ is the value of attribute 'href'.
      # - +name+ is the HTML text.
      type = case class_attr_val
             when 'class', 'module'
               :class
             when 'file'
               :file
             when 'method'
               case href_line
               when /method-c-/
                 :singleton_method
               when /method-i-/
                 :instance_method
               else
                 fail href_line
               end
             else
               fail class_attr_val
             end
      _, href, rest = href_line.split('"')
      name = rest.split(/<|>/)[1]
      # Add to our index.
      index = self.indexes[type]
      index[name] = [] unless index.include?(name)
      index[name].push(href)
    end
    # indexes.each_pair do |type, index|
    #   puts type
    #   index.each_pair do |name, hrefs|
    #     puts '  ' + name
    #     hrefs.each do |href|
    #       puts '    ' + href
    #     end
    #   end
    # end
    # exit
  end

  # Show a page of Ruby documentation.
  def show(name)
    # Figure out what's asked for.
    case
    when name.match(/^[A-Z]/)
      show_class(name, indexes[:class])
    when name.start_with?('ruby:')
      show_file(name, indexes[:file])
    when name.start_with?('::')
      show_singleton_method(name, indexes[:singleton_method])
    when name.start_with?('#')
      show_instance_method(name, indexes[:instance_method])
    when name.start_with?('.')
      show_method(name, indexes[:singleton_method], indexes[:instance_method])
    when name.match(/^[a-z]/)
      show_method(name, indexes[:singleton_method], indexes[:instance_method])
    else
      fail name
    end
  end

  # Show class for name.
  def show_class(name, class_index)
    # Find class names that start with name.
    hrefs = class_index.select do |class_name|
      class_name.start_with?(name)
    end
    case hrefs.size
    when 0
      puts "Found no class or module name starting with '#{name}'."
      hrefs = indexes[:class]
      names = hrefs.map {|href| href[0] }
      message = "Show names of all #{names.size} classes and modules?"
      return unless get_boolean_answer(message)
      choice_index = get_choice_index(names)
      return if choice_index.nil?
      href = names[choice_index] + '.html'
    when 1
      href = hrefs.first.last.first
      puts "Found one class or module name starting with '#{name}': #{href.sub('.html', '')}."
    else
      names = hrefs.map {|href| href[0].start_with?(name) ? href[0] : nil }
      puts "Found #{names.size} class and module names starting with '#{name}'."
      message = "Show names?'"
      return unless get_boolean_answer(message)
      choice_index = get_choice_index(names)
      return if choice_index.nil?
      href = names[choice_index] + '.html'
    end
    open_url(href.gsub('::', '/'))
  end

  def show_file(name, file_index)
    # Target page is a free-standing page such as 'ruby:CONTRIBUTING'.
    hrefs = indexes[:file].sort
    _, name = name.split(':', 2)
    # Find the pages that start with the name.
    hrefs = hrefs.select do |key, value|
      key.start_with?(name)
    end
    # Respond.
    case hrefs.size
    when 0
      puts "No Ruby page name begins with '#{name}'."
      puts "Getting names of all pages...."
      hrefs = indexes[:ruby].sort
      names = hrefs.map {|href| href[0] }
      choice_index = get_choice_index(names)
      href = hrefs[choice_index].first
      open_url(href)
    when 1
      href = hrefs.first.last.first
      open_url(href)
    else
      names = []
      hrefs.map do |href|
        _name, _hrefs = *href
        _hrefs.each do |_href|
          # Build the real dir.
          dirs = _href.split('/')
          dirs.pop             # Removes trailing page name (*.html).
          dirs.push(nil)       # Forces a slash at the end.
          dirs.unshift('.')    # Forces a dot at the beginning.
          dir = dirs.join('/')
          s = "#{_name} (#{dir})"
          names.push(s)
        end
      end
      choice_index = get_choice_index(names)
      href = hrefs[choice_index].last.first
      open_url(href)
    end
  end

  def show_singleton_method(name singleton_method_index)
    hrefs = singleton_method_index.select do |method_name|
      method_name.start_with?(name)
    end
    case hrefs.size
    when 0
      puts "Nothing known about #{name}."
    when 1
      href = hrefs.first.last
      open_url(href)
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

  def show_instance_method(name, instance_method_index)
    hrefs = instance_method_index.select do |method_name|
      method_name.start_with?(name)
    end
    case hrefs.size
    when 0
      puts "Nothing known about #{name}."
    when 1
      href = hrefs.first.last
      open_url(href)
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

  def show_method(name, singleton_method_index, instance_method_index)
    singleton_name = name.sub('.', '::')
    instance_name = name.sub('.', '#')
    hrefs = indexes[:method].select do |method_name|
      method_name.start_with?(singleton_name) ||
        method_name.start_with?(instance_name)
    end
    case hrefs.size
    when 0
      puts "Nothing known about #{name}."
    when 1
      href = hrefs.first.last
      open_url(href)
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

  def get_choice_index(choices)
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
    index
  end

  def get_boolean_answer(question)
    print "#{question} (y or n):  "
    $stdout.flush
    gets.match(/y/i) ? true : false
  end

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
    puts "Opening #{url}."
    command = "#{executable_name} #{url}"
    system(command)
  end

end
