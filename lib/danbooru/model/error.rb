require "danbooru/model"

class Danbooru::Model::Error < Danbooru::Model
  def error?
    true
  end
end
