require 'ostruct'
require 'yaml'
require 'logger'
require 'docker'
require 'discordrb/webhooks'

# Container for webhook clients
Webhooks = [].freeze

LOGGER = Logger.new(STDOUT)

# Load webhook targets from YAML file
yaml = OpenStruct.new(YAML.load_file('webhooks.yml'))

yaml.webhooks.each do |url|
  Webhooks << Discordrb::Webhooks::Client.new(url: url)
end

LOGGER.info "Loaded with #{Webhooks.size} webhook targets"

# Set timeout to something realistic
Docker.options[:read_timeout] = 999_999_999

# WHALE
WHALE = 'https://s3-us-west-2.amazonaws.com/www.breadware.com/integrations/docker.png'.freeze

# PANINI
PANINI = 'http://www.subway.com/ns/images/menu/CAN/ENG/menu-category-sandwich-chipotlesteak-cheesepanini-CA-234x140_PT.jpg'.freeze

# Formats an event into a Discord-ready embed
def format(event)
  builder = Discordrb::Webhooks::Builder.new(
    username: 'Docker',
    avatar_url: WHALE,
    content: "**[#{event.type}] #{event.action}**"
  )

  builder.add_embed do |embed|
    embed.color = 0x73abff
    embed.timestamp = Time.at(event.time_nano / 1_000_000_000)

    attributes = event.actor.attributes

    unless attributes.empty?
      embed.add_field(
        name: 'Details',
        value: attributes.map { |name, value| "**#{name}:** `#{value}`" }.join("\n")
      )
    end
  end

  builder
end

# Listen to events and dispatch them to our configured webhooks
begin
  Docker::Event.stream do |event|
    LOGGER.info "Dispatching event: #{event}"
    Webhooks.each { |webhook| webhook.execute format(event) }
  end
rescue => ex
  Webhooks.each do |webhook|
    webhook.execute do |builder|
      builder.username = 'Panini'
      builder.avatar_url = 'http://www.subway.com/ns/images/menu/CAN/ENG/menu-category-sandwich-chipotlesteak-cheesepanini-CA-234x140_PT.jpg'
      builder.content = "**An exception occured within `panini`:** `#{ex.message}`"
      builder.add_embed do |embed|
        embed.color = 0xff0000
        embed.description = "```#{ex.backtrace}```"
      end
    end
  end
end
