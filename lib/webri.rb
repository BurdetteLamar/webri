# frozen_string_literal: true
require 'rbconfig'
require 'open-uri'
require 'rexml'

# A class to display Ruby HTML documentation.
class WebRI

  # Where the official web pages are.
  DocSite = 'https://docs.ruby-lang.org/en/'

  attr_accessor :doc_release

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
    # - +href+ is the value of attribute 'href'
    # Following RI usage, we classify thus:
    indexes = {
      class: [],
      ruby: [],
      method: []
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
      _, href, _ = link_text.split('"')
      indexes[type].push(href)
      i += 2
    end
    indexes.each_pair do |type, hrefs|
      hrefs.uniq!
      hrefs.sort!
    end
  end

  def show(target_name)
    links = links_for_name[target_name]
    case links.size
    when 0
      puts "No documentation found for #{target_name}."
    when 1
      url = links.first
      open_url(url)
    else
      key = get_choice(links)
      url = links[key]
      open_url(url)
    end
  end

  def get_choice(choices)
    choices[get_choice_index(choices)]
  end

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
