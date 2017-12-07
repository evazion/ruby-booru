require 'test_helper'
require 'danbooru'

class DanbooruTest < ActiveSupport::TestCase
  setup do
    @booru = Danbooru.new
  end

  context "Danbooru:" do
    context "Danbooru#initialize" do
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

  context "Danbooru#source:" do
    context "the #index method" do
      should "return an error for unsupported sites" do
        source = @booru.source.index(url: "http://www.example.com")

        assert_kind_of(Danbooru::Response, source)
        assert_equal(true, source.failed?)
        assert_equal("400 Bad Request: Unsupported site", source.error)
      end
    end
  end

  context "Danbooru#posts:" do
    should "work" do
      assert_kind_of(Danbooru::Resource::Posts, @booru.posts)
      assert_equal(Danbooru::Model::Post, @booru.posts.factory)
      assert_equal(@booru, @booru.posts.booru)
    end

    context "the #all method" do
      should "work with a block" do
        @booru.posts.all(tags: "id:1,2", limit: 1) do |post|
          assert_equal(true, post.id <= 2)
        end
      end

      should "work without a block" do
        posts = @booru.posts.all(tags: "id:1,2", limit: 1).to_a
        assert_equal([2, 1], posts.map(&:id))
      end
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

        assert_kind_of(Danbooru::Response, post)
        assert_kind_of(Danbooru::Model::Post, post.model)
        assert_equal(false, post.failed?)
        assert_equal("d34e4cf0a437a5d65f8e82b7bcd02606", post.md5)
      end
    end
  end

  context "The Enumerable#to_dtext method" do
    should "work" do
      data = [
        { foo: 1, bar: 2 },
        { foo: 3, bar: 4 },
      ]

      dtext = <<~DTEXT
        [table]
          [thead]
            [tr]
              [th] Foo [/th]
              [th] Bar [/th]
            [/tr]
          [/thead]
          [tbody]
            [tr]
              [td] 1 [/td]
              [td] 2 [/td]
            [/tr]
            [tr]
              [td] 3 [/td]
              [td] 4 [/td]
            [/tr]
          [/tbody]
        [/table]
      DTEXT

      assert_equal(dtext, data.to_dtext)
    end
  end
end
