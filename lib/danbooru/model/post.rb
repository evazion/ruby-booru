require "danbooru/model"

class Danbooru::Model::Post < Danbooru::Model
  def absolute_preview_file_url
    booru.url + preview_file_url
  end

  def absolute_large_file_url
    booru.url + large_file_url
  end

  def absolute_file_url
    booru.url + file_url
  end

  def fav_ids
    fav_string.split.grep(/([0-9]+)/) { $1.to_i }
  end

  def pool_ids
    pool_string.split.grep(/([0-9]+)/) { $1.to_i }
  end

  def source_url
    Addressable::URI.heuristic_parse(source) rescue nil
  end

  def tags
    tag_string.split
  end
end
