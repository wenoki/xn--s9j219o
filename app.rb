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
    redirect SimpleIDN.to_ascii("エラーが発生したので.") + DomainName
  end

  get "/" do
    @domain = Domain.find_or_create request.host
    @domain.view_count
    slim :application
    @domain.count_up
  end
end

class Domain
  attr_accessor :name, :view_count, :since
  HostedZoneId = ENV["HOSTED_ZONE_ID"]

  def initialize name, view_count = 1, since = DateTime.now
    self.name = name
    self.view_count = view_count
    self.since = since
  end

  def count_up
    self.view_count += 1
    self.save
  end

  def decoded_name
    SimpleIDN.to_unicode self.name
  end

  def self.find name
    self.new(
      name,
      rrset(name).resource_records[0][:value].to_i,
      DateTime.parse(rrset(name).resource_records[1][:value]),
    )
  end

  def self.create name
    self.new name
  end

  def self.find_or_create name
    if rrset(name).exists?
      find name
    else
      create name
    end
  end

  def self.rrset name
    AWS::Route53::HostedZone.new(HostedZoneId).rrsets[name + ?., "TXT"]
  end

  private
  def save
    rrset = self.class.rrset(self.name)
    rrset.resource_records[0][:value] = %("#{self.view_count}")
    rrset.resource_records[1][:value] = %("#{self.since.to_s}")
    rrset.update
  end
end

class Integer
  def with_delimiter
    self.to_s.reverse.gsub(/(\d{3})(?=\d)/, "\\1,").reverse
  end
end
