require 'net/http'
require 'uri'
require 'rexml'
require 'json'
require 'json/add/core'

# Class to scrape Ruby info from the documentation site and store it as JSON.

class Scraper

  # The official documentation site for English.
  BASE_URL = 'https://docs.ruby-lang.org/en'

  # Translations for hex characters.
  HEX_CHARS = {
    '-21' => '!',
    '-25' => '%',
    '-26' => '&',
    '-2A' => '*',
    '-2B' => '+',
    '-2D' => '-',
    '-2F' => '/',
    '-3C' => '<',
    '-40' => '@',
    '-3D' => '=',
    '-3E' => '>',
    '-3F' => '?',
    '-5B' => '[',
    '-5D' => ']',
    '-5E' => '^',
    '-60' => '`',
    '-7C' => '|',
  }

  # Hash: relative URL paths for a name.
  attr_accessor :hrefs_for_name

  # Hash: the names of the classes that have a method.
  attr_accessor :classes_for_method

  def initialize
    self.hrefs_for_name = {}
    self.classes_for_method = {}
  end

  def self.scrapers
    {
      '3.2' => Scraper34,
      '3.4' => Scraper32,
      '4.0' => Scraper40,
    }
  end

  def self.release_names
    self.scrapers.keys
  end

  def get_home_page(release_name, suffix)
    url = File.join(BASE_URL, release_name, suffix)
    uri = URI(url)
    response = Net::HTTP.get_response(uri)
    unless response.code == '200'
      message = "Page #{url} for release #{url} not found; code #{response.code}."
      raise RuntimeError.new(message)
    end
    response.body
  end

  # Argument is an REXML::Element representing a link to a file.
  # Returns the parsed name and href.
  def add_file(element)
    unless element.name == 'a'
      message = "Expecting 'a', not '#{element.name}'"
      raise ArgumentError.new(message)
    end
    file_href = element.attributes['href']
    file_href.sub!(%r[^./], '')
    file_name = 'ruby:' + file_href.sub(/\.html$/, '')
    puts "Adding file #{file_name}"
    hrefs_for_name[file_name] = [file_href]
    [file_name, file_href]
  end

  # Argument is an REXML::Element representing a link to a class.
  # Returns the parsed name and href.
  def add_class(element)
    unless element.name == 'a'
      message = "Expecting 'a', not '#{element.name}'"
      raise ArgumentError.new(message)
    end
    class_href = element.attributes['href'].sub(%r[^./], '')
    class_name = class_href.gsub('/', '::').sub(%r[\.html$], '')
    puts "Adding class #{class_name}"
    hrefs_for_name[class_name] = [class_href]
    [class_name, class_href]
  end

  # Arguments are an REXML::Element representing a link to a class, and the class name.
  # Returns the parsed name and href.
  def add_method(element, class_name)
    method_href = element.attributes['href']
    # Translate hex characters.
    method_name = method_href.dup
    hex_chars = method_name.scan(/-[0-9A-F]{2}/)
    hex_chars.each do |hex_char|
      char = HEX_CHARS[hex_char]
      raise hex_char unless char
      method_name.sub!(hex_char, char)
    end
    method_name = case
                  # when method_href == '#method-i-2D'
                  #   # Special case; not worth the trouble of handling below.
                  #   '#-'
                  when method_href.match(/[#]?method-i-2D/)
                    # Special case; not worth the trouble of handling below.
                    '#-'
                  # when method_href == '#method-i-2D-40'
                  #   # Special case; not worth the trouble of handling below.
                  #   '#-@'
                  when method_href.match(/[#]?method-i-2D-40/)
                    # Special case; not worth the trouble of handling below.
                    '#-@'
                  when method_href.match('-i-')
                    # Instance method.
                    '#' + method_name.sub(/[#]?method-i[-]?/, '')
                  when method_href.match('-c-')
                    # Singleton method.
                    '::' + method_name.sub(/[#]?method-c[-]?/, '')
                  end
    puts "  Adding method #{method_name}"
    hrefs_for_name[method_name] = "#{method_href}"
    classes_for_method[method_name] ||= []
    classes_for_method[method_name] << "#{class_name}"
    [method_name, method_href]
  end

  def write_json(release_name)
    # This JSON is bulky, but readable by humans.
    data = {
      :timestamp => Time.now,
      :hrefs_for_name => hrefs_for_name.sort.to_h,
      :classes_for_method => classes_for_method.sort.to_h,
    }
    json = JSON.generate(
      data.sort.to_h,
      indent: "  ",     # 4 spaces per level
      space: " ",       # space after :
      array_nl: "\n",   # newline after each array element
      object_nl: "\n"   # newline after each object member
    )
    filepath = "data/#{release_name}.json"
    File.write(filepath, json)
  end

end

class Scraper40 < Scraper

  RELEASE_NAME = '4.0'

  def scrape
    home_page = get_home_page(RELEASE_NAME, '')
    home_page.lines.each do |line|
      line.chomp!
      next unless line.match(%r[<a href="])
      line += '</a>' unless line.match(%r[</a>]) # Add end-tag if needed.
      # Parse the line as XML.
      doc = REXML::Document.new(line)
      root = doc.root
      case root.name
      when 'a'  # Each file URL is the href attribute in an anchor element.
        add_file(root)
      when 'ul' # All class/module URLs are in a single ul element.
        add_classes(root)
        break # We don't need anything farther down.
      else
        # Ignore.
      end
    end
    write_json(RELEASE_NAME)
  end

  def add_classes(element)
    REXML::XPath.each(element, "//*[@href]") do |element|
      class_name, class_href = add_class(element)
      url = File.join(BASE_URL, RELEASE_NAME, class_href)
      uri = URI(url)
      response = Net::HTTP.get_response(uri)
      raise response.code unless response.code == '200'
      response.body.lines.each do |line|
        next unless line.match(%r[<li ><a href="#method-])
        line.chomp!
        doc = REXML::Document.new(line)
        REXML::XPath.each(doc.root, "//*[@href]") do |element|
          add_method(element, class_name)
        end
      end
    end
  end
end

class Scraper34 < Scraper

  RELEASE_NAME = '3.4'

  def add_method(element)
    href = element.attributes['href']
    m = href.match(%r[(#)])
    class_name = m.pre_match.gsub('/', '::').sub(%r[\.html$], '')
    new_href = m.post_match
    element.attributes['href'] = new_href
    super(element, class_name)
  end

  def scrape
    home_page = get_home_page(RELEASE_NAME, 'table_of_contents.html')
    enum = home_page.lines.to_enum
    while true do
      begin
        line = enum.next
        next unless line.match(%r[<li class="(\w+)">])
        type = $1
        next_line = enum.peek
        element = REXML::Document.new(next_line).root
        case type
        when 'file'
          add_file(element)
        when 'class', 'module'
          add_class(element)
        when 'method'
          add_method(element)
        else
          raise type
        end
      rescue StopIteration
        break
      end
    end
    write_json(RELEASE_NAME)
  end

end

class Scraper32 < Scraper

  RELEASE_NAME = '3.2'

  def add_method(element)
    href = element.attributes['href']
    m = href.match(%r[(#)])
    class_name = m.pre_match.gsub('/', '::').sub(%r[\.html$], '')
    new_href = m.post_match
    element.attributes['href'] = new_href
    super(element, class_name)
  end

  def scrape
    home_page = get_home_page(RELEASE_NAME, 'table_of_contents.html')
    enum = home_page.lines.to_enum
    while true do
      begin
        line = enum.next
        next unless line.match(%r[<li class="(\w+)">])
        type = $1
        next_line = enum.peek
        element = REXML::Document.new(next_line).root
        case type
        when 'file'
          add_file(element)
        when 'class', 'module'
          add_class(element)
        when 'method'
          add_method(element)
        else
          raise type
        end
      rescue StopIteration
        break
      end
    end
    write_json(RELEASE_NAME)
  end

end

