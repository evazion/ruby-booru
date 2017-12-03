require 'test_helper'
require 'danbooru'

class DanbooruTest < ActiveSupport::TestCase
  context "Danbooru:" do
    context "Danbooru#initialize" do
      setup do
        @booru = Danbooru.new
      end

      should "take default params from the environment" do
        assert_equal(ENV["BOORU_HOST"], @booru.host.to_s)
        assert_equal(ENV["BOORU_USER"], @booru.user)
        assert_equal(ENV["BOORU_API_KEY"], @booru.api_key)
      end

      should "initialize the site" do
        assert_equal(@booru.host.to_s, @booru.site.url)
        assert_equal(@booru.user, @booru.site.options[:user])
        assert_equal(@booru.api_key, @booru.site.options[:password])
      end
    end
  end

  context "Danbooru#posts:" do
    setup do
      @booru = Danbooru.new
    end

    should "work" do
      assert_kind_of(Danbooru::Resource::Posts, @booru.posts)
      assert_equal(Danbooru::Model::Post, @booru.posts.factory)
      assert_equal(@booru, @booru.posts.booru)
    end

    context "the #index method" do
      should "work" do
        post = @booru.posts.index(tags: "id:1").first
        assert_equal("d34e4cf0a437a5d65f8e82b7bcd02606", post.md5)
      end
    end

    context "the #show method" do
      should "work" do
        post = @booru.posts.show(1)

        assert_kind_of(Danbooru::Model::Post, post)
        assert_equal("d34e4cf0a437a5d65f8e82b7bcd02606", post.md5)
      end
    end
  end
end
