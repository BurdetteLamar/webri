# frozen_string_literal: true

require "test_helper"

class TestWebRI < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil WebRI::VERSION
  end

  def test_web_pages_available
    p WebRI::RiDirpath
  end

end
