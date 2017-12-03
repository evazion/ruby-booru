require 'test_helper'
require 'danbooru'

class DanbooruTest < ActiveSupport::TestCase
  context "initialization" do
    should "work" do
      assert_nothing_raised { Danbooru.new }
    end
  end
end
