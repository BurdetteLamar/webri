require 'net/http'
require 'uri'
require 'rexml'
require 'json'
require 'json/add/core'

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

  # Hash containing the scraped data.
  attr_accessor :data, :git_root

  def initialize
    self.data = {
      pages: {}, # Names and relative URLs of the free-standing Ruby doc pages.
      classes: {},    # Each key is the relative URL of the class/module doc page;
                      # the value is a set of relative URLs of its methods.
    }
  end

  def scrape(release)
    self.git_root = `git rev-parse --show-toplevel`.chomp
    unless $?.success?
      puts "FATAL: Current working directory #{Dir.pwd} is not in a git project."
      exit 1
    end
    # Get the main page for the release.
    url = File.join(BASE_URL, release, '') # Must end with '/', else HTTP code 301.
    uri = URI(url)
    response = Net::HTTP.get_response(uri)
    unless response.code == '200'
      puts "FATAL: Page #{url} for release #{release} not found."
      exit 1
    end
    case release
    when '4.0'
      scrape_40(response)
    else
      puts "FATAL: Release #{release} is not supported."
      exit 1
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
    json = JSON.generate(
      data,
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
    data[:pages][page_name] = page_href
  end

  def add_classes(element, release)
    REXML::XPath.each(element, "//*[@href]") do |element|
      class_href = element.attributes['href'].sub(%r[^./], '')
      class_name = class_href.gsub('/', '::').sub(%r[\.html$], '')
      puts "Adding class #{class_name}"
      data[:classes][class_name] ||= {
        href: class_href,
        methods: {},
      }
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

          data[:classes][class_name][:methods][method_name] = method_href
        end
      end
    end

  end
end