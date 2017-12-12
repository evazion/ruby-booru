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
    unless Danbooru::Resource.const_defined?(name.camelize)
      Danbooru::Resource.const_set(name.camelize, Class.new(Danbooru::Resource))
    end

    define_method(name) do
      instance_variable_set("@#{name}", build_resource(name)) unless instance_variable_defined?("@#{name}")
      instance_variable_get("@#{name}")
    end
  end

  attr_reader :http, :url, :user, :api_key, :factory, :log

  def initialize(url: ENV["BOORU_URL"], user: ENV["BOORU_USER"], api_key: ENV["BOORU_API_KEY"], factory: {}, log: Logger.new(nil))
    url ||= "https://danbooru.donmai.us"

    @url, @user, @api_key, @log = Addressable::URI.parse(url), user, api_key, log
    @http = Danbooru::HTTP.new(url, user: user, pass: api_key, log: log)
    @factory = factory
  end

  def ping(params = {})
    posts.ping(params)
  end

  def logged_in?
    return false unless user.present? && api_key.present?
    users.index(name: user).succeeded?
  end

  private
  def build_resource(name)
    resource_class = Danbooru::Resource.const_get(name.camelize)
    resource_class.new(name, self)
  end
end
