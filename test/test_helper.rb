$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'bundler'
Bundler.require(:default, :development)

require "dotenv"
require 'minitest/autorun'
require 'mocha/mini_test'

Dotenv.load(".env.test", ".env")
SimpleCov.start
