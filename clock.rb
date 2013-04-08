#!ruby
# -*- encoding: UTF-8 -*-

require './bot'
require 'clockwork'

include Clockwork

Clockwork.configure do |config|
  config[:tz] = 'Asia/Tokyo'
end

bot = Bot.new

handler do |job|
  $stderr.puts(job)
  case job
  when 'hourly'
    bot.periodic()
  when 'daily'
    bot.daily()
  end
end

every(1.hour, 'hourly', at: '**:27')
every(1.day, 'daily', at: '00:04')
