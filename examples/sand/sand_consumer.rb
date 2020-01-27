#!/usr/bin/env ruby

# Add lib path to LOAD_PATH
$LOAD_PATH.unshift File.expand_path('../../../lib', __FILE__)

require 'optparse'
require 'ostruct'
require 'sand'
require 'rdkafka'

class FromBeginningRebalancer
  def on_partitions_assigned(consumer, list)
    list.each do |topic, partitions|
      partitions.each do |partition|
        partition.offset = Rdkafka::Bindings::RD_KAFKA_OFFSET_BEGINNING
      end
    end
    consumer.assign(list)
  end

  def on_partitions_revoked(consumer, list)
    consumer.assign(nil)
  end
end

def shutdown(c, timeout_s)
  Timeout::timeout(timeout_s) do
    c.close
  end
  exit 0
end

params = {}
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: sand_consumer.rb [options]"
  opts.on("-bSERVER", "--bootstrap-server=SERVER", "Bootstrap server. Defaults to localhost:9092")
  opts.on("-sSAND_YAML", "--sand=SAND_YAML", "[Optional] Name of sand.yml. Required for OAUTHBEARER")
  opts.on("-gID", "--group=ID", "[Required] Consumer group ID")
  opts.on("-tTOPIC_NAME", "--topic=TOPIC_NAME", "[Required] Name of Topic to subscribe to")
  opts.on("--from-beginning", "[Optional] If set, it will consume from the beginning")
  opts.on("--debug=DEBUG", "[Optional] Debugging options for librdkafka")
  opts.on("-h", "--help") do
    puts opts
    exit
  end
end
optparse.parse!(into: params)

params[:"bootstrap-server"] ||= "localhost:9092"
if !params.has_key?(:group) || !params.has_key?(:topic)
  puts optparse.help
  exit 1
end

Rdkafka::Config.attach_rdkafka_log_cb = false
Rdkafka::Config.attach_rdkafka_stats_cb = false

cfg = Rdkafka::Config.new(
  "bootstrap.servers": params[:"bootstrap-server"],
  "group.id": params[:group],
  "sasl.mechanism": "OAUTHBEARER",
  "security.protocol": "SASL_SSL",
  "ssl.ca.location": "devkfk1066.ca",
)
cfg["debug"] = params[:debug] if params[:debug]
if params[:"from-beginning"]
  cfg.consumer_rebalance_listener = FromBeginningRebalancer.new
end
if params[:sand]
  puts "Using sand credentials from #{params[:sand]}"
  opts = YAML.load(File.read(params[:sand]))
  sand = Sand::Client.new(opts)

  cfg.oauthbearer_token_refresh_callback = ->(client, oauthbearer_config) do
    begin
      token = sand.oauth_token(scopes: opts[:access_scopes], num_retry: 2)

      # expires_in is in seconds
      expiration_ms = (Time.now.to_i + token[:expires_in]) * 1000

      err = client.oauthbearer_set_token(token[:access_token], expiration_ms, opts[:client_id], [])
      if err.nil?
        puts "oauthbearer_set_token succeeded"
      else
        puts "oauthbearer_set_token failed: #{err}"
        exit 1
      end
    rescue => e
      puts "oauthbearer_set_token_failure: #{e}"
      client.oauthbearer_set_token_failure("#{e}")
    end
  end
end

c = cfg.consumer

trap("QUIT") { c.close }
trap("INT") { c.close }
trap("TERM") { c.close }

c.subscribe(params[:topic])
puts "Subscribed to #{params[:topic]}"

c.each do |message|
  puts "Got #{message.topic}/#{message.partition}@#{message.offset} #{message.payload}"
end

puts "Done"
