#
# analyze emotion based tweet
#

require 'twitter'
require 'natto'
require 'pp'

module Emoemo

  class EmoTwitter
    def initialize()
      proxy = {
        host: "proxy.example.jp",
        port: 8080,
        username: "user",
        password: "password"
      }

      # ログイン
      @client = Twitter::REST::Client.new do |config|
        config.consumer_key = 'xxxx'
        config.consumer_secret = 'xxxx'
        config.access_token = 'xxxx'
        config.access_token_secret = 'xxxx'
        config.proxy = proxy
      end 
    end

    def show_my_profile
      puts @client.user.screen_name   # アカウントID
      puts @client.user.name          # アカウント名
      puts @client.user.description   # プロフィール
      puts @client.user.tweets_count  # ツイート数
    end

    # 1件だけ取得
    def get_tweet(username)
      @client.user_timeline(username, count:1).each {|tweet|
        puts tweet.text
        puts tweet.user.screen_name
        puts tweet.id
      }
    end
  end # class EmoTwitter

  class Emoemo
    def initialize()
      @twitter = EmoTwitter.new()
    end

    def analyze()
      @twitter.get_tweet("miwarin")
    end
  end # class Emoemo
end # module Emoemo

def main(argv)
  emo = Emoemo::Emoemo.new()
  emo.analyze()
end

main(ARGV)
