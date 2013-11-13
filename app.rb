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
  DomainName = SimpleIDN.to_ascii "死ぬ.com"

  log = Logger.new STDOUT
  STDOUT.sync = true

  configure :development do
    register Sinatra::Reloader
  end

  error do
    redirect "http://#{SimpleIDN.to_ascii("エラーが発生したので.") + DomainName}/"
  end

  get "/" do
    @domain = Domain.new request.host
    slim :application
  end

  get "/:to" do
    redirect "http://#{SimpleIDN.to_ascii(params[:to]) + ?. + DomainName}"
  end
end

class Domain
  attr_accessor :name, :view_count, :since
  HostedZoneId = ENV["HOSTED_ZONE_ID"]

  def initialize name
    self.name = name

    if self.rrset.exists?
      self.view_count = self.rrset.resource_records[0][:value].delete(?").to_i + 1
      self.since = DateTime.parse self.rrset.resource_records[1][:value]
      self.rrset.delete
    else
      self.view_count = 1
      self.since = DateTime.now
    end

    self.create_rrset
  end

  def rrset
    Domain.rrsets[self.name + ?., "TXT"]
  end

  def create_rrset
    Domain.rrsets.create(
      self.name,
      "TXT",
      ttl: 300,
      resource_records: [
        {value: %("#{self.view_count}")},
        {value: %("#{self.since.to_s}")},
      ]
    )
  end

  def decoded_name
    SimpleIDN.to_unicode self.name
  end

  def info
    "Viewed #{self.view_count > 1 ? self.view_count.with_delimiter + " times" : "once"} since #{self.since.strftime "%B %d, %Y %I:%M %p"}."
  end

  def self.rrsets
    AWS::Route53::HostedZone.new(HostedZoneId).rrsets
  end
end

class Integer
  def with_delimiter
    self.to_s.reverse.gsub(/(\d{3})(?=\d)/, "\\1,").reverse
  end
end
