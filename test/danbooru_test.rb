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

      should "create classes and getters for every resource" do
        assert_equal(true, @booru.respond_to?(:favorites))
        assert_kind_of(Danbooru::Resource::Favorites, @booru.send(:favorites))
      end
    end

    context "Danbooru#ping" do
      should "return true if the request succeeds" do
        assert(@booru.ping)
      end

      should "return false if the request fails" do
        assert_equal(false, @booru.ping(limit: -100))
      end
    end

    context "Danbooru#logged_in?" do
      should "return true when logged in" do
        assert_equal(true, @booru.logged_in?)
      end

      should "return false when logged in incorrectly" do
        @booru = Danbooru.new(api_key: "wrong")
        assert_equal(false, @booru.logged_in?)
      end

      should "return false when not logged in" do
        @booru = Danbooru.new(api_key: nil)
        assert_equal(false, @booru.logged_in?)
      end
    end
  end

  context "Danbooru::HTTP" do
    should "work without authentication" do
      response = Danbooru::HTTP.new(@booru.host).get("/post_versions")

      assert_equal(403, response.code)
      assert_nothing_raised { JSON.parse(response.body) }
    end

    should "work with authentication" do
      response = Danbooru::HTTP.new(@booru.host, user: @booru.user, pass: @booru.api_key).get("/post_versions")

      assert_equal(200, response.code)
      assert_nothing_raised { JSON.parse(response.body) }
    end

    should "maintain a persistent connection" do
      http = Danbooru::HTTP.new(@booru.host)
      response1 = http.get("/")
      response2 = http.get("/")

      assert_equal(response1.connection.object_id, response2.connection.object_id)
    end

    should "log debug info" do
      @io = StringIO.new
      @logger = Logger.new(@io, level: :debug)

      response = Danbooru::HTTP.new(@booru.host, log: @logger).get("/")
      assert_match(%r!code=200 method=GET!, @io.string)
    end
  end

  context "Danbooru::Resource:" do
    context "the #request method" do
      setup do
        # XXX resource = Danbooru.new["posts"]
        @booru = Danbooru.new
        @resource = Danbooru::Resource.new("posts", @booru)
      end

      should "work" do
        response = @resource.request(:get, "/")
        assert_equal(true, response.succeeded?)
      end

      should "retry on failure until success" do
        mock_resp = mock
        mock_resp.stubs(:code).returns(429, 429, 200, 200)
        mock_resp.stubs(:body).returns("[]", "[]")

        @booru.http.expects(:request).times(2).returns(mock_resp)
        Retriable.expects(:sleep).times(1)

        response = @resource.request(:get, "/", {}, tries: 2)
        assert_equal(true, response.succeeded?)
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

    context "the #update method" do
      should "work" do
        post = @booru.posts.update(1, post: { rating: "e" })
        assert_equal("e", post.rating)

        post = @booru.posts.update(1, post: { rating: "s" })
        assert_equal("s", post.rating)
      end
    end
  end

  context "Danbooru::Model:" do
    context "the #update method" do
      should "work" do
        post = @booru.posts.show(1)

        post.update(rating: "e")
        assert_equal("e", post.rating)

        post.update(rating: "s")
        assert_equal("s", post.rating)
      end
    end

    should "have an #url" do
      assert_match(%r!/posts/1$!, @booru.posts.show(1).url)
    end

    should "have a #shortlink" do
      assert_equal("post #1", @booru.posts.show(1).shortlink)
    end

    should "be converted by #to_json" do
      post = @booru.posts.show(1)
      json = JSON.parse(post.to_json)

      assert_equal(1, json["id"])
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
