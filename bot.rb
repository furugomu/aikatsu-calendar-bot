#!/usr/bin/env ruby
# -*- encoding: UTF-8 -*-

# 下記環境変数を設定しておきなさい
# TWITTER_CONSUMER_KEY
# TWITTER_CONSUMER_SECRET
# TWITTER_OAUTH_TOKEN
# TWITTER_OAUTH_TOKEN_SECRET

require 'twitter'
require 'aikatsu_calendar'
require 'mongo'

include Mongo

class Bot
  def initialize
  end

  # 日が変わった時になんかする
  def daily
    refresh()
    if todays_schedules.count == 0
      tweet('今日は何もないよ')
      return
    end
    todays_schedules.each do |s|
      tweet_schedule(s)
    end
  end

  # 定期的になんかする
  def periodic
    tweet_next()
  end

  # アイカツカレンダーをもういちど見に行く
  def refresh
    xs = AikatsuCalendar::Scraper.scrape()
    return if xs.empty?
    schedules.drop()
    schedules.insert(xs)
    schedules.ensure_index(date_from: 1)
    schedules.ensure_index(date_until: 1)
  end

  def db
    return @db if @db
    client = MongoClient.new(ENV['MONGO_HOST'], ENV['MONGO_PORT'].to_i)
    @db = client.db("aikatsu-calendar")
    @db.authenticate(ENV['MONGO_USER'], ENV['MONGO_PASSWORD'])
    @db
  end

  def schedules
    db['schedules']
  end

  # 今やっているもの
  def current_schedules
    schedules.find(date_from: {'$lte'=> today}, date_until: {'$gte'=> today})
  end

  # 今日から or 今日まで
  def todays_schedules
    schedules.find(date_from: today, date_until: {'$gte'=> today})
  end

  # 次のをつぶやく
  def tweet_next
    # つぶやいた回数が少ない方から順に
    cursor = current_schedules.sort(tweet_count: 1)
    s = cursor.first or return
    s['tweet_count'] ||= 0
    s['tweet_count'] += 1
    schedules.save(s)
    tweet_schedule(s)
  end

  def tweet_schedule(s)
    tweet(format_tweet(s))
  end

  def tweet(text)
    $stderr.puts("tweet: "+text)
    Twitter.update(text)
  end
end

def today
  now = Time.now
  Time.local(now.year, now.month, now.day)
end

def schedule_type_ja(type)
  case type.to_s
  when 'other'
    'その他'
  when 'anime'
    'アニメ'
  when 'web'
    'web'
  when 'blog'
    'ブログ'
  when 'goods'
    'グッズ'
  when 'magazine'
    '雑誌'
  when 'event'
    'イベント'
  when 'game2'
    'ゲーム'
  when 'game'
    'マイキャラパーツ'
  else
    '不明'
  end
end

def format_tweet(schedule)
  type = schedule_type_ja(schedule['type'])
  greeting =
    case Time.now.hour
    when 5..10
      'おはよう！'
    when 11..16
      'こんにちは！'
    else
      'こんばんは！'
    end
  if schedule['date_from'] == today &&
    schedule['date_from'] == schedule['date_until']
    # 本日の
    "%s 今日のスケジュールは [%s] %s だよ %s" %
      [greeting, type, schedule['content'], schedule['link']]
  elsif schedule['date_from'] == today
    # 今日から
  elsif schedule['date_until'] == today
    # 今日まで
  else
    date = pretty_date(schedule['date_until'])
    '%sまで [%s] %s %s' % [date, type, schedule['content'], schedule['link']]
  end
end

def pretty_date(time)
  w = %w(日 月 火 水 木 金 土)[time.wday]
  m = Time.now.month == time.month ? '%d月' % time.month : ''
  '%s%d日(%s)' % [m, time.day, w]
end
