# frozen_string_literal: true
require 'rbconfig'
require 'open-uri'
require 'rexml'

# A class to display Ruby HTML documentation.
class WebRI

  # Where the official web pages are.
  DocSite = 'https://docs.ruby-lang.org/en/'

  attr_accessor :doc_release, :indexes

  def initialize(options = {})
    # Construct the doc release; e.g., '3.4'.
    _ = RbConfig.ruby.split('Ruby').last[0..1]
    self.doc_release = _[0] + '.' + _[1]
    # Get its table of contents as a temp file.
    toc_url = DocSite + self.doc_release + '/table_of_contents.html'
    toc_file = URI.open(toc_url)
    # Construct indexes for the types.
    # Each index is the line number (0-based)
    # of the first line of a triplet such as:
    #     <li class="file">
    #       <a href="COPYING.html">COPYING</a>
    #     </li>
    # We capture variables thus:
    # - +type+ is the value of attribute 'class'.
    # - +href+ is the value of attribute 'href'.
    # - +name+ is the HTML text.
    # Following RI usage, we classify thus:
    self.indexes = {
      class: {},
      ruby: {},
      method: {}
    }
    # In the TOC, we find these four; change them.
    types = {
      'class' => :class,
      'file' => :ruby,
      'method' => :method,
      'module' => :class
    }
    lines = toc_file.readlines
    i = 0
    while i < lines.count
      line = lines[i]
      i += 1
      next unless line.match('<li class="(\w+)"')
      type = types[$1]
      link_text = lines[i]
      _, href, rest = link_text.split('"')
      name = rest.split(/<|>/)[1]
      index = self.indexes[type]
      if type == :method
        index[name] = [] unless index.include?(name)
        index[name].push(href)
      else
        index[name] = href
      end
      i += 2
    end
    # self.indexes.each_pair do |type, names|
    #   puts type
    #   names.each_pair do |name, hrefs|
    #     puts '  ' + name
    #     hrefs.each do |href|
    #       puts '    ' + href
    #     end
    #   end
    # end
  end

  def show(name)
    case
    when name.match(/^[A-Z]/)
      hrefs = indexes[:class].select do |class_name|
        class_name.start_with?(name)
      end
      case hrefs.size
      when 0
        puts "Nothing known about #{name}"
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
        puts "Nothing known about #{name}"
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
        puts "Nothing known about #{name}"
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
    when name.match(/^./)
      puts 'instance and singleton methods'
    else
      puts 'http://yahoo.com'
    end
  end

  # def get_choice(choices)
  #   choices[get_choice_index(choices)]
  # end

  def get_choice_index(choices)
    if choices.size > 10
      puts "  #{choices.size} choices: Show (y or n)?"
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
