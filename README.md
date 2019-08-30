# Rdkafka

[![Build Status](https://travis-ci.org/coupa/rdkafka-ruby.svg?branch=master)](https://travis-ci.org/coupa/rdkafka-ruby)

The `rdkafka` gem is a modern Kafka client library for Ruby based on
[librdkafka](https://github.com/edenhill/librdkafka/).
It wraps the production-ready C client using the [ffi](https://github.com/ffi/ffi)
gem and targets Kafka 1.0+ and Ruby 2.3+.

`rdkafka` was written because we needed a reliable Ruby client for
Kafka that supports modern Kafka at [AppSignal](https://appsignal.com).
We run it in production on very high traffic systems.

This gem only provides a high-level Kafka consumer. If you are running
an older version of Kafka and/or need the legacy simple consumer we
suggest using the [Hermann](https://github.com/reiseburo/hermann) gem.

The most important pieces of a Kafka client are implemented. We're
working towards feature completeness, you can track that here:
https://github.com/appsignal/rdkafka-ruby/milestone/1

## Installation

This gem downloads and compiles librdkafka when it is installed. If you
have any problems installing the gem please open an issue.

## Usage

See the [documentation](https://www.rubydoc.info/github/appsignal/rdkafka-ruby) for full details on how to use this gem. Two quick examples:

### Consuming messages

Subscribe to a topic and get messages. Kafka will automatically spread
the available partitions over consumers with the same group id.

```ruby
config = {
  :"bootstrap.servers" => "localhost:9092",
  :"group.id" => "ruby-test"
}
consumer = Rdkafka::Config.new(config).consumer
consumer.subscribe("ruby-test-topic")

consumer.each do |message|
  puts "Message received: #{message}"
end
```

### Producing messages

Produce a number of messages, put the delivery handles in an array and
wait for them before exiting. This way the messages will be batched and
sent to Kafka in an efficient way.

```ruby
config = {:"bootstrap.servers" => "localhost:9092"}
producer = Rdkafka::Config.new(config).producer
delivery_handles = []

100.times do |i|
  puts "Producing message #{i}"
  delivery_handles << producer.produce(
      topic:   "ruby-test-topic",
      payload: "Payload #{i}",
      key:     "Key #{i}"
  )
end

delivery_handles.each(&:wait)
```

## Known issues

When using forked process such as when using Unicorn you currently need
to make sure that you create rdkafka instances after forking. Otherwise
they will not work and crash your Ruby process when they are garbage
collected. See https://github.com/appsignal/rdkafka-ruby/issues/19

## Development

A Docker Compose file is included to run Kafka and Zookeeper. To run
that:

```
docker-compose up
```

Run `bundle` and `cd ext && bundle exec rake && cd ..` to download and
compile `librdkafka`.

You can then run `bundle exec rspec` to run the tests. To see rdkafka
debug output:

```
DEBUG_PRODUCER=true bundle exec rspec
DEBUG_CONSUMER=true bundle exec rspec
```

After running the tests you can bring the cluster down to start with a
clean slate:

```
docker-compose down
```

## Example

To see everything working run these in separate tabs:

```
bundle exec rake consume_messages
bundle exec rake produce_messages
```
