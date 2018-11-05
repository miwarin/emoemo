#
# analyze emotion based tweet
#

require 'twitter'
require 'natto'
require 'net/https'
require 'uri'
require 'json'
require "sqlite3"
require 'pp'

module Emoemo
  class Service
    def initialize()
      @uri = URI('https://api.mackerelio.com/api/v0/services/emotion/tsdb')
    end

    def post(tweets, scores)
      request = Net::HTTP::Post.new(@uri)
      request['Content-Type'] = "application/json"
      request['X-Api-Key'] = 'xxxx'

      tweets.each_with_index {|tweet, index|
        documents = [{
            'name' => 'emotion',
            'time' => DateTime.parse(tweet["created_at"]).strftime('%s').to_i,
            'value' => scores[index]
        }]
        request.body = documents.to_json
  
        response = Net::HTTP.start(@uri.host, @uri.port, :use_ssl => @uri.scheme == 'https') do |http|
            http.request (request)
        end
      }
    end
  end

  class TextAnalyzer
    def initialize()
      @accessKey = 'xxxx'
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
      pp scores
      return scores
    end
  end

  class EmoTwitter
    def initialize()
      @cache_path = "./cache.db"

      proxy = {
        host: "proxy2.example.co.jp",
        port: 8080,
        username: "xxxx",
        password: "xxxx"
      }

      # ログイン
      @client = Twitter::REST::Client.new do |config|
        config.consumer_key = 'xxxx'
        config.consumer_secret = 'xxxx'
        config.access_token_secret = 'xxxx'
        config.access_token = 'xxxx'
        config.proxy = proxy
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
      @client.user_timeline(username).each {|tweet|
        puts tweet.created_at
        puts tweet.text
        puts tweet.user.screen_name
        puts tweet.id
        t << {"id" => tweet.id, "created_at" => tweet.created_at.to_s, "text" => tweet.text}
      }
      return t
    end

    def get_new_tweets(username)
      db = SQLite3::Database.new(@cache_path)
      begin
        rows = db.execute <<-SQL
          create table tweet (
            id text,
            created_at text,
            text text
          );
        SQL
      rescue => e
        puts e
      end

      now_tweets = get_tweet(username)
      puts "now_tweets:"
      pp now_tweets
      puts ""

      new_tweets ||= []

      now_tweets.each {|n|
        if db.execute( "select * from tweet where id == #{n['id']}" ).length == 0
          puts "new tweet: #{n}"
          db.execute "insert into tweet values ( ?, ?, ? )", n["id"], n["created_at"], n["text"]
          new_tweets << n
        end
      }
      puts "new_tweets:"
      pp new_tweets
      puts ""

      return new_tweets
    end

  end # class EmoTwitter

  class Emoemo
    def initialize()
      @twitter = EmoTwitter.new()
      @analyzer = TextAnalyzer.new()
      @service = Service.new()
    end

    def analyze()
      tweets = @twitter.get_new_tweets("miwarin")
      if tweets.length == 0
        puts "not new tweet"
        return
      end
      scores = @analyzer.analyze(tweets)
      @service.post(tweets, scores)
    end
  end # class Emoemo
end # module Emoemo

def main(argv)
  emo = Emoemo::Emoemo.new()
  emo.analyze()
end

main(ARGV)
