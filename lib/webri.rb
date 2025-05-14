# frozen_string_literal: true
require 'rbconfig'
require 'open-uri'
require 'rexml'

# A class to display Ruby HTML documentation.
class WebRI

  # Where the official web pages are.
  DocSite = 'https://docs.ruby-lang.org/en/'

  attr_accessor :doc_release, :indexes

  # Get the info from the Ruby doc site's table of contents.
  def initialize(options = {})
    # Construct the doc release; e.g., '3.4'.
    _ = RbConfig.ruby.split('Ruby').last[0..1]
    self.doc_release = _[0] + '.' + _[1]
    # Get the doc table of contents as a temp file.
    toc_url = DocSite + self.doc_release + '/table_of_contents.html'
    toc_file = URI.open(toc_url)
    # Following RI usage, we classify thus:
    self.indexes = {
      class: {},
      ruby: {},
      method: {}
    }
    # In the TOC, we will find these four values for attribute 'class'; map them to the three values.
    types = {
      'class' => :class,
      'module' => :class,
      'file' => :ruby,
      'method' => :method,
    }
    # Iterate over the lines of the TOC page.
    lines = toc_file.readlines
    i = 0
    while i < lines.count
      line = lines[i]
      i += 1
      # We're looking for each triplet of lines such as:
      #     <li class="file">
      #       <a href="COPYING.html">COPYING</a>
      #     </li>
      next unless line.match('<li class="(\w+)"')
      # We capture variables thus:
      # - +type+ is the value of attribute 'class'.
      # - +href+ is the value of attribute 'href'.
      # - +name+ is the HTML text.
      type = types[$1]
      # Link is on the next line.
      link_text = lines[i]
      _, href, rest = link_text.split('"')
      name = rest.split(/<|>/)[1]
      # Add to our index.
      index = self.indexes[type]
      index[name] = [] unless index.include?(name)
      index[name].push(href)
      # Dismiss the rest of the triplet of lines.
      i += 2
    end
  end

  def show(name)
    case
    when name.start_with?('ruby:')
      hrefs = indexes[:ruby].sort
      _, name = name.split(':', 2)
      hrefs = hrefs.select do |key, value|
        key.start_with?(name)
      end
      case hrefs.size
      when 0
        puts "Nothing known about ruby:#{name}."
      when 1
        href = hrefs.first.last
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
        href = hrefs[choice_index].last
        open_url(href)
      end
    when name.match(/^[A-Z]/)
      hrefs = indexes[:class].select do |class_name|
        class_name.start_with?(name)
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
        href = hrefs[names[choice_index]]
        open_url(href)
      end
    when name.start_with?('::')
      hrefs = indexes[:method].select do |method_name|
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
    when name.start_with?('#')
      hrefs = indexes[:method].select do |method_name|
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
    when name.start_with?('.')
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
    else
      puts 'http://yahoo.com'
    end
  end

  def get_choice_index(choices)
    puts "Found #{choices.size} possibilities:"
    if choices.size > 10
      puts "Show all? (y or n):?"
      $stdout.flush
      response = gets
      exit unless response =~ /y/i
    end
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
      exit if index == -1
    end
    index
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
    command = "#{executable_name} #{url}"
    system(command)
  end

end
