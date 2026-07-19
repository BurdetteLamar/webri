require 'net/http'
require 'uri'
require 'rexml'
require 'json'
require 'json/add/core'


require_relative 'webri'

# Class to scrape Ruby info from the documentation site and store it as JSON.

class Scraper

  # The official documentation site for English.
  #
  BASE_URL = 'https://docs.ruby-lang.org/en'

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

  attr_accessor :hrefs_for_name, :git_root, :classes_for_method

  def initialize
    self.hrefs_for_name = {}
    self.classes_for_method = {}
  end

  def scrape(release)
    self.git_root = WebRI.git_root
    # Get the main page for the release.
    url = File.join(BASE_URL, release, '') # Must end with '/', else HTTP code 301.
    uri = URI(url)
    response = Net::HTTP.get_response(uri)
    unless response.code == '200'
      message = "Page #{url} for release #{release} not found."
      raise RuntimeError.new(message)
    end
    case release
    when '4.0'
      scrape_40(response)
    else
      message = "Release #{release} is not supported."
      raise RuntimeError.new(message)
    end
  end

  def scrape_40(response)
    # Find the links for each free-standing page, and for each module or class.
    response.body.lines.each do |line|
      next unless line.match(%r[<a href="])
      line.chomp!
      line += '</a>' unless line.match(%r[</a>]) # Add end-tag if needed.
      # Parse the line as XML.
      doc = REXML::Document.new(line)
      root = doc.root
      case root.name
      when 'a'  # Each page URL is the href attribute in an anchor element.
        add_page(root)
      when 'ul' # All class/module URLs are in a single ul element.
        add_classes(root, '4.0')
        break # We don't need anything farther downpage.
      else
        # Ignore.
      end
    end
    # This JSON is bulky, but readable by humans.
    data = {
      :hrefs_for_name => hrefs_for_name.sort.to_h,
      :classes_for_method => classes_for_method.sort.to_h,
    }
    json = JSON.generate(
      data.sort.to_h,
      indent: "  ",   # 4 spaces per level
      space: " ",       # space after :
      array_nl: "\n",   # newline after each array element
      object_nl: "\n"   # newline after each object member
    )
    Dir.chdir(git_root) do
      filepath = "data/4.0.json"
      File.write(filepath, json)
    end
  end

  def add_page(element)
    page_href = element.attributes['href']
    page_href.sub!(%r[^./], '')
    page_name = 'ruby:' + page_href.sub(/\.html$/, '')
    puts "Adding page #{page_name}"
    hrefs_for_name[page_name] = [page_href]
  end

  def add_classes(element, release)
    REXML::XPath.each(element, "//*[@href]") do |element|
      class_href = element.attributes['href'].sub(%r[^./], '')
      class_name = class_href.gsub('/', '::').sub(%r[\.html$], '')
      puts "Adding class #{class_name}"
      hrefs_for_name[class_name] = [class_href]
      url = File.join(BASE_URL, release, class_href)
      uri = URI(url)
      response = Net::HTTP.get_response(uri)
      raise response.code unless response.code == '200'
      response.body.lines.each do |line|
        next unless line.match(%r[<li ><a href="#method-])
        line.chomp!
        doc = REXML::Document.new(line)
        REXML::XPath.each(doc.root, "//*[@href]") do |element|
          method_href = element.attributes['href']
          # Adjust method_name.
          method_name = method_href.dup
          # Translate hex characters.
          hex_chars = method_name.scan(/-[0-9A-F]{2}/)
          hex_chars.each do |hex_char|
            char = HEX_CHARS[hex_char]
            raise hex_char unless char
            method_name.sub!(hex_char, char)
          end
          method_name = case
                        when method_href == '#method-i-2D'
                          '#-'
                        when method_href == '#method-i-2D-40'
                          '#-@'
                        when method_href.match('-i-')
                          '#' + method_name.sub(/#method-i[-]?/, '')
                        when method_href.match('-c-')
                          '::' + method_name.sub(/#method-c[-]?/, '')
                        end
          # puts "Adding method #{method_name}"
          hrefs_for_name[method_name] = "#{method_href}"
          classes_for_method[method_name] ||= []
          classes_for_method[method_name] << "#{class_name}"
        end
      end
    end

  end
end