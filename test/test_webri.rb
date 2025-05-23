# frozen_string_literal: true

require 'test_helper'
require 'open-uri'

class TestWebRI < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil WebRI::VERSION
  end

  def test_web
    web_ri = WebRI.new
  end

  def zzz_test_web_pages_available
    web_ri = WebRI.new
    found_page_name = ''
    html = nil
    pages_not_found = {}
    fragments_not_found = []
    web_ri.names.each_pair do |ri_filepath, name|
      page_name, fragment = name.split('#')
      url = File.join(WebRI::DocSite, page_name)
      unless page_name == found_page_name
        found_page_name = page_name
        begin
          html = URI.open(url).read
        rescue => x
          pages_not_found[url] = x.message
          html = nil
          p [url, x.message]
        end
      end
      if html && fragment
        if fragment.end_with?('--')
          fragment = fragment.sub('--', '-2D')
        else
          fragment = fragment.sub('-i--', '-i-')
          fragment = fragment.sub('-c--', '-c-')
        end
        href = 'href="' + '#' + CGI.escape(fragment) + '"'
        unless html.match(href)
          fragments_not_found.push(page_name + '#' + fragment)
          p [page_name, fragment, href]
        end
      end
    end
    pages_not_found.each_pair do |k, v|
      p [k, v]
    end
    fragments_not_found.each do |fragment|
      p fragment
    end
  end

end
