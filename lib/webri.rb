# frozen_string_literal: true
require 'rbconfig'
require 'find'
require 'cgi'

# A class to display Ruby HTML documentation.
class WebRI

  RiDirpath = `ri --list-doc-dirs`.split.first
  DocRelease = RiDirpath.split('/')[-2][0..2]
  DocSite = 'https://docs.ruby-lang.org/en'

  attr_accessor :target_urls, :ri_filepaths

  def initialize(target_name, options)
    set_ri_filepaths
    set_target_urls
    selected_urls = {}
    target_urls.select do |name, value|
      if name.match(Regexp.new(target_name))
        selected_urls[name] = value
      end
    end
    case selected_urls.size
    when 0
      puts "No documentation found for #{target_name}."
    when 1
      url = selected_urls.first[1]
      open_url(url)
    else
      key = get_choice(selected_urls.keys)
      url = selected_urls[key]
      open_url(url)
    end
  end

  def set_ri_filepaths
    self.ri_filepaths = []
    Find.find(RiDirpath).each do |path|
      next unless path.end_with?('.ri')
      path.sub!(RiDirpath + '/', '')
      ri_filepaths.push(path)
    end
  end

  def set_target_urls
    self.target_urls = {}
    ri_filepaths.each do |ri_filepath|
      next if ri_filepath == 'cache.ri'
      filepath = ri_filepath.sub('.ri', '.html')
      name, target_url = case
                         when filepath.match(/-c\.html/) # Class method.
                           dirname = File.dirname(filepath)
                           method_name = CGI.unescape(File.basename(filepath).sub('-c.html', ''))
                           target_url = dirname + '.html#method-c-' + escape_fragment(method_name)
                           name = dirname.gsub('/', '::') + '::' + method_name
                           target_urls[name] = target_url
                         when filepath.match(/-i\.html/) # Instance method.
                           dirname = File.dirname(filepath)
                           method_name = CGI.unescape(File.basename(filepath).sub('-i.html', ''))
                           target_url = dirname + '.html#method-i-' + escape_fragment(method_name)
                           name = dirname.gsub('/', '::') + '#' + method_name
                           target_urls[name] = target_url
                         when filepath.match(/\/cdesc-/) # Class.
                           target_url = File.dirname(filepath) + '.html'
                           name = target_url.gsub('/', '::').sub('.html', '')
                           target_urls[name] = target_url
                         when File.basename(filepath).match(/^page-/)
                           target_url = filepath.sub('page-', '') # File.
                           name = target_url.sub('.html', '').sub(/_rdoc$/, '.rdoc').sub(/_md$/, '.md')
                           target_urls[name] = target_url
                         else
                           raise filepath
                         end
    end
  end

  def get_choice(choices)
    choices[get_choice_index(choices)]
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
      index = response.match(/\d+/) ? response.to_i : -1
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
    url = File.join(DocSite, DocRelease, target_url)
    command = "#{executable_name} #{url}"
    system(command)
  end

  def escape_fragment(fragment)
    CGI.escape(fragment).gsub('%', '-')
  end
end
