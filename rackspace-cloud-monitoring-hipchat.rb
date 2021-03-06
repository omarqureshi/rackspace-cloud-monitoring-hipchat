require 'sinatra/base'
require 'yaml'
require 'json'

class Object
  def blank?
    respond_to?(:empty?) ? empty? : !self
  end

  def present?
    !blank?
  end
end

$config = YAML::load_file(File.join(File.dirname(File.expand_path(__FILE__)), 'config.yml'))
if $config[:path_to_hipchat_credentials].present?
  external_credentials = YAML::load_file($config[:path_to_hipchat_credentials])
  $config[:hipchat_api] = external_credentials[:hipchat_api]
  $config[:hipchat_room] = external_credentials[:hipchat_room]
end

if $config[:hipchat_api].present? && $config[:hipchat_room].present?
  $room = HipChat::Client.new($config[:hipchat_api])[$config[:hipchat_room]]
else
  raise "No Hipchat credentials are present"
end

class RackspaceCloudMonitoringHipchat < Sinatra::Base
  configure :production, :development do
    enable :logging
  end

  post '/alarm' do
    params = JSON.parse(request.env["rack.input"].read)
    name = params["entity"]["label"]
    status = params["details"]["status"]
    color = case params["details"]["state"]
            when 'OK'
              'green'
            when 'WARNING'
              'yellow'
            when 'CRITICAL'
              'red'
            end
    $room.send("CloudMonitor", "#{name} - #{status}", :color => color)
  end
end
