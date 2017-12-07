require "active_support"
require "active_support/core_ext/string/inflections"
require "addressable/uri"

Dir[__dir__ + "/danbooru/**/*.rb"].each { |file| require file }

class Danbooru
  RESOURCES = %w[
    artist_commentaries artist_commentary_versions artists artist_versions bans
    bulk_update_requests comments comment_votes counts delayed_jobs dmails
    dtext_previews favorite_groups favorites forum_posts forum_topics ip_bans
    iqdb_queries mod_actions notes note_previews note_versions pools
    pool_versions posts post_appeals post_flags post_replacements post_versions
    post_votes related_tags saved_searches source tag_aliases tag_implications
    tags uploads users user_feedbacks wiki_pages wiki_page_versions
  ]

  RESOURCES.each do |name|
    define_method(name) do
      instance_variable_set("@#{name}", build_resource(name)) unless instance_variable_defined?("@#{name}")
      instance_variable_get("@#{name}")
    end
  end

  attr_reader :http, :host, :user, :api_key, :factory

  def initialize(host: nil, user: nil, api_key: nil, factory: {}, logger: nil)
    host ||= ENV["BOORU_HOST"] || "https://danbooru.donmai.us"
    user ||= ENV["BOORU_USER"]
    api_key ||= ENV["BOORU_API_KEY"]

    @host, @user, @api_key = Addressable::URI.parse(host), user, api_key
    @http = Danbooru::HTTP.new(host, user: user, pass: api_key)
    @factory = factory
  end

  def ping
    posts.ping
  end

  def logged_in?
    users.index(name: user).succeeded?
  end

  private
  def build_resource(name)
    resource_class = "Danbooru::Resource::#{name.camelize}".safe_constantize || Danbooru::Resource
    resource_class.new(name, self)
  end
end
