require "danbooru/resource"

class Danbooru::Resource::Counts < Danbooru::Resource
  def initialize(name, options = {})
    super
    @url = booru.host.to_s + "/counts/posts"
  end

  def default_params
    {}
  end
end
