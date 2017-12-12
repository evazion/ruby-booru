require "active_support"
require "active_support/core_ext/string/inflections"
require "addressable/uri"

Dir[__dir__ + "/danbooru/**/*.rb"].each { |file| require file }

class Danbooru
  RESOURCES = {
    "ArtistCommentaries" => {},
    "ArtistCommentaryVersions" => {},
    "Artists" => {},
    "ArtistVersions" => {},
    "Bans" => {},
    "BulkUpdateRequests" => {},
    "Comments" => { default_params: { group_by: "comment" } },
    "CommentVotes" => {},
    "Counts" => { url: "counts/posts", default_params: { limit: nil } },
    "DelayedJobs" => {},
    "Dmails" => {},
    "DtextPreviews" => {},
    "FavoriteGroups" => {},
    "Favorites" => {},
    "ForumPosts" => {},
    "ForumTopics" => {},
    "IpBans" => {},
    "IqdbQueries" => {},
    "ModActions" => {},
    "Notes" => {},
    "NotePreviews" => {},
    "NoteVersions" => {},
    "Pools" => {},
    "PoolVersions" => {},
    "Posts" => { default_params: { limit: 200 } },
    "PostAppeals" => {},
    "PostFlags" => {},
    "PostReplacements" => {},
    "PostVersions" => {},
    "PostVotes" => {},
    "RelatedTags" => {},
    "SavedSearches" => {},
    "Source" => {},
    "TagAliases" => {},
    "TagImplications" => {},
    "Tags" => { default_params: { "search[hide_empty]": "no" } },
    "Uploads" => {},
    "Users" => {},
    "UserFeedbacks" => {},
    "WikiPages" => {},
    "WikiPageVersions" => {},
  }
end

class Danbooru
  attr_reader :url, :user, :api_key, :log, :http, :resources, :factory

  def initialize(url: ENV["BOORU_URL"], user: ENV["BOORU_USER"], api_key: ENV["BOORU_API_KEY"], factory: {}, log: Logger.new(nil))
    url ||= "https://danbooru.donmai.us"

    @url, @user, @api_key, @log = Addressable::URI.parse(url), user, api_key, log
    @http = Danbooru::HTTP.new(url, user: user, pass: api_key, log: log)
    @factory, @resources = factory, {}
  end

  def ping(params = {})
    posts.ping(params)
  end

  def logged_in?
    return false unless user.present? && api_key.present?
    users.index(name: user).succeeded?
  end

  def [](name)
    name = name.to_s.camelize

    raise ArgumentError, "invalid resource name '#{name}'" unless RESOURCES.has_key?(name)
    resources[name] ||= Resource.const_get(name).new(name.underscore, self, **RESOURCES[name])
  end

  RESOURCES.keys.each do |name|
    Resource.const_set(name, Class.new(Resource)) unless Resource.const_defined?(name)

    define_method(name.underscore) do
      self[name]
    end
  end
end
