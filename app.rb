# coding: utf-8

require "sinatra/base"
require "sinatra/reloader"
require "slim"
require "sass"
require "logger"
require "simpleidn"
require "aws-sdk"

AWS.config(
  access_key_id: ENV["AWS_ACCESS_KEY_ID"],
  secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"],
)

class ShinuDotCom < Sinatra::Base
#  DomainName = SimpleIDN.to_ascii "死ぬ.com"
  DomainName = "localhost"

  log = Logger.new STDOUT
  STDOUT.sync = true

  configure :development do
    register Sinatra::Reloader
  end

  helpers do
    def current_subdomain
      request.host.match(/\A(.*)#{DomainName}\z/)[1].chop
    end
  end

  error do
    redirect SimpleIDN.to_ascii("エラーが発生したので.") + DomainName
  end

  get "/" do
    Subdomain.find current_subdomain
    # @subdomain = Subdomain.find_or_create request.host.match(/\A(.*)#{DomainName}\z/)[1].chop


#    slim :application
  end
end

class Subdomain
  attr_accessor :name, :view_count, :since
  HostedZoneId = ENV["HOSTED_ZONE_ID"]

  def initialize name, view_count = 0, since = DateTime.now
    self.name = name
    self.view_count = view_count
    self.since = since
  end

  def decoded_name
    SimpleIDN.to_unicode self.name
  end

  def self.find name
    "oh" if record_set(name).exists?
  end

  def self.create

  end

  def self.find_or_create
  end

  def self.record_set name
    AWS::Route53::HostedZone.new(HostedZoneId).rrsets[[name, ShinuDotCom::DomainName, ""].compact.join(?.), "TXT"]
  end
end

class Integer
  def with_delimiter
    self.to_s.reverse.gsub(/(\d{3})(?=\d)/, "\1,").reverse
  end
end
