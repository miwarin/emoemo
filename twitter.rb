#
# analyze emotion based tweet
#

require 'twitter'
require 'net/https'
require 'uri'
require 'json'
require "sqlite3"
require 'time'
require 'pp'

MACERELIO_APIKEY = 'xxx'

TEXTANALYZER_APIKEY = 'xxx'

TWITTER_COMSUMER_KEY = 'xxx'
TWITTER_COMSUMER_SECRET = 'xxx'
TWITTER_ACCESS_TOKEN_SECRET = 'xxx'
TWITTER_ACCESS_TOKEN = 'xxx'

# PROXY_HOST = 'proxy2.example.co.jp'
# PROXY_PORT = 8080
# PROXY_USERNAME = 'xxx'
# PROXY_PASSWORD = 'xxx'


module Emoemo
  class ECache
    def initialize(cache_path)
      @db = SQLite3::Database.new(cache_path)
      begin
        rows = @db.execute <<-SQL
          create table tweet (
            id text,
            created_at text,
            text text,
            score text
          );
        SQL
      rescue => e
        puts e
      end
    end

    def find_new_tweets(now_tweets)
      new_tweets ||= []
      now_tweets.each {|n|
        if @db.execute( "select * from tweet where id == #{n['id']}" ).length == 0
          puts "new tweet: #{n}"
          @db.execute "insert into tweet values ( ?, ?, ?, ? )", n["id"], n["created_at"], n["text"], "0.0"
          new_tweets << n
        end
      }
      return new_tweets
    end

    def update_tweet(id, created_at, text, score)
      @db.execute("update tweet set created_at='#{created_at}', score=#{score} where id=#{id}")
    end

    def dump(order: 'score')
      # レコードを取得する
      @db.execute( "select * from tweet order by #{order} desc") do |row|
        p row
      end
    end
    
  end # class ECache
  
  class Mackerelio
    def initialize(cache)
      @cache = cache
      @uri = URI('https://api.mackerelio.com/api/v0/services/emotion/tsdb')
    end

    def post(tweets, scores)
      request = Net::HTTP::Post.new(@uri)
      request['Content-Type'] = "application/json"
      request['X-Api-Key'] = MACERELIO_APIKEY

      documents ||= []
      tweets.each_with_index {|tweet, index|
        epoch_time = Time.parse(tweet["created_at"]).strftime('%s').to_i
        documents << {
            'name' => 'emotion',
            'time' => epoch_time,
            'value' => scores[index]
        }
        @cache.update_tweet(tweet["id"], Time.at(epoch_time), tweet["text"], scores[index].to_s)
      }

      request.body = documents.to_json
      response = Net::HTTP.start(@uri.host, @uri.port, :use_ssl => @uri.scheme == 'https') do |http|
          http.request (request)
      end
    end
  end # Mackerelio

  class TextAnalyzer
    def initialize()
      @accessKey = TEXTANALYZER_APIKEY
      uri = 'https://japaneast.api.cognitive.microsoft.com'
      path = '/text/analytics/v2.0/sentiment'
      @uri = URI(uri + path)
    end

    def analyze(tweets)
      docs ||= []
      id = 1
      tweets.each {|t|
        docs << { 'id' => id.to_s, 'language' => 'ja', 'text' => t["text"] }
        id = id + 1
      }

      documents = { 'documents': docs }
      
      request = Net::HTTP::Post.new(@uri)
      request['Content-Type'] = "application/json"
      request['Ocp-Apim-Subscription-Key'] = @accessKey
      request.body = documents.to_json
      
      response = Net::HTTP.start(@uri.host, @uri.port, :use_ssl => @uri.scheme == 'https') do |http|
          http.request (request)
      end
      
      scores ||= []
      json = JSON.parse(response.body)
      json["documents"].each {|doc|
        scores << doc["score"]
      }
      return scores
    end
  end # class TextAnalyzer

  class EmoTwitter
    def initialize(cache)
      @cache = cache

      # proxy = {
      #   host: PROXY_HOST,
      #   port: PROXY_PORT,
      #   username: PROXY_USERNAME,
      #   password: PROXY_PASSWORD
      # }

      # ログイン
      @client = Twitter::REST::Client.new do |config|
        config.consumer_key = TWITTER_COMSUMER_KEY
        config.consumer_secret = TWITTER_COMSUMER_SECRET
        config.access_token_secret = TWITTER_ACCESS_TOKEN_SECRET
        config.access_token = TWITTER_ACCESS_TOKEN
        # config.proxy = proxy
      end 
    end

    def show_my_profile
      puts @client.user.screen_name   # アカウントID
      puts @client.user.name          # アカウント名
      puts @client.user.description   # プロフィール
      puts @client.user.tweets_count  # ツイート数
    end

    def get_tweet(username)
      t ||= []
      options = {count: 200}
      @client.user_timeline(username, options).each {|tweet|
        next if tweet.text =~ /\ART/
        t << {"id" => tweet.id, "created_at" => tweet.created_at.to_s, "text" => tweet.text}
      }
      return t
    end

    def get_new_tweets(username)
      now_tweets = get_tweet(username)
      new_tweets = @cache.find_new_tweets(now_tweets)
      return new_tweets
    end

  end # class EmoTwitter

  class Emoemo
    def initialize()
      @cache = ECache.new("./cache.db")
      @twitter = EmoTwitter.new(@cache)
      @analyzer = TextAnalyzer.new()
      @mackerel = Mackerelio.new(@cache)
    end

    def analyze()
      tweets = @twitter.get_new_tweets("miwarin")
      if tweets.length == 0
        puts "not new tweet"
        return
      end
      scores = @analyzer.analyze(tweets)
      @mackerel.post(tweets, scores)
    end

    def show_score()
      @cache.dump()
    end

    def show_timeline()
      @cache.dump(order: 'created_at')
    end

  end # class Emoemo
end # module Emoemo

def main(argv)
  emo = Emoemo::Emoemo.new()
  if argv.length == 0
    emo.analyze()
  else
    if argv[0] =~ /^[sS]/
      emo.show_score()
    else
      emo.show_timeline()
    end
  end
end

main(ARGV)
