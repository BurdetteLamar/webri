# frozen_string_literal: true

require 'test_helper'
require 'open-uri'

class TestWebRI < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil WebRI::VERSION
  end

  def test_web_pages_available
    web_ri = WebRI.new
    found_page_name = ''
    html = nil
    web_ri.names.each_pair do |ri_filepath, name|
      page_name, fragment = name.split('#')
      url = File.join(WebRI::DocSite, page_name)
      unless page_name == found_page_name
        found_page_name = page_name
        begin
          html = URI.open(url).read
          p page_name
        rescue => x
          p url
          p x.message
          html = nil
        end
      end
      if fragment
        p '  ' + fragment
      end
    end
  end

end
