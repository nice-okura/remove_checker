#!/usr/bin/ruby
# encoding: UTF-8
#
# Author:: herpes
# Date:: 2012/04/23
#
# Usage::
#

require "~/.mylib/ruby/herpeslib"
require "time"
require "pp"
require "kconv"
require "optparse"
require "rubygems"
require "twitter"
require "ruby-growl"
require "yaml"

#
#== Macro
#

# ユーザー名(未使用)
USER = "hoge"
FILE_DIR = File.dirname(__FILE__)
LATEST_IDS_FILE = File.expand_path("#{FILE_DIR}/follower_logs/latest_follower_ids.txt")
REMOVE_LOG_FILE = File.expand_path("#{FILE_DIR}/follower_logs/remover_")
CONFIG_FILE = File.expand_path("#{FILE_DIR}/config.yml")

#
#=
#
def get_follower_ids
  next_cursor = -1
  follower_ids = []

  while next_cursor != 0
    fls = Twitter.follower_ids({:cursor => next_cursor})
    follower_ids += fls.ids
    
    next_cursor = fls.next_cursor
  end

  return follower_ids
end

#
# latest_follower_idsがない場合に初期化する
#
def save_init_follower
  begin
    File.open(LATEST_IDS_FILE, "w"){|fp|
      begin
        flist = get_follower_ids
        puts "フォロワー数:#{flist.size}"
        flist.each{ |id|
          fp.puts id
        }
     rescue => e
      end
    }
  rescue 
    $stderr.puts "#{LATEST_IDS_FILE}を開けませんでした．"
    exit
  end
end

def save_new_ids(ids)
  begin
    File.open(LATEST_IDS_FILE, "w"){|fp|
      begin
        ids.each{ |id|
          fp.puts id
        }
      rescue => e
        $stderr.puts e
      end
    }
  rescue 
    $stderr.puts "#{LATEST_IDS_FILE}を開けませんでした．"
    exit
  end
end

def get_follower_fromfile(filename=LATEST_IDS_FILE)
  list = []
  begin
    File.open(filename, "r"){|fp|
      while l = fp.gets
        list << l.chomp!.to_i
      end
    }
  rescue 
    $stderr.puts "#{LATEST_IDS_FILE}がありません．"
  end
  return list
end

#
# リムったやつがいるかチェックして，最新のフォロワーIDの配列を返す
#
def check_remove
  latest_follower_ids = get_follower_fromfile(LATEST_IDS_FILE)

  follower_ids = get_follower_ids
  puts "前回のフォロワー数:#{latest_follower_ids.size}"
  puts "今回のフォロワー数:#{follower_ids.size}"
  

  remove_mans = latest_follower_ids - follower_ids
  mes = "前回のフォロワー数:#{latest_follower_ids.size}\n今回のフォロワー数:#{follower_ids.size}"
  #
  # Growl設定
  #
  g = Growl.new "localhost", "remove_checker", ["RemoverNotification"]
  

  if remove_mans.size == 0
    puts "リムったやつはいない"
    mes += "\n\nリムったやつはいない" 
  else
    File.open("#{REMOVE_LOG_FILE}_#{Time.now.to_i}.txt", "w"){ |fp|

      remove_mans.each{|id|
        begin
          u = Twitter.user(id)

          fp.puts "ID:#{id}"
          fp.puts "screen_name:@#{u.screen_name}"
          fp.puts "friends:#{u.friends_count}"
          fp.puts "follwers:#{u.followers_count}"
          fp.puts "statuses:#{u.statuses_count}"
          fp.puts "bio:#{u.description}"
          fp.puts "--------------------------------------"
          
          puts u.name
          mes += "\n@#{u.screen_name}(#{u.name})"
          Twitter.update("@#{u.screen_name} ...") if $postflg
        rescue => e
          puts $stderr.puts e
          puts "ID:#{id}でエラー"
          mes += "\n#{e}"
          mes += "\nID:#{id}でエラー"
        end
      }
    }
  end
  
  g.notify "RemoverNotification", "リムったやつお知らせ", mes
  
  return follower_ids
end


##################################
#
#== main
#
##################################

#
# オプション
#
OPTS = {}
opt = OptionParser.new

#
# -i オプションは現在のフォロワーを保存する
# -p オプションはリムったやつにリプライ飛ばす気持ち悪い機能ON
#
$iflg = false
$postflg = false
opt.on('-i') { |v| $iflg = true }
opt.on('-p') { |v| $postflg = true}
opt.parse!(ARGV)


yml = YAML.load_file(CONFIG_FILE)
ck = yml['consumer_key']
cs = yml['consumer_secret']
ot = yml['oauth_token']
os = yml['oauth_token_secret']

#
# ログイン
#
Twitter.configure do |config|
  config.consumer_key = ck
  config.consumer_secret = cs
  config.oauth_token = ot
  config.oauth_token_secret = os
end


puts "#{Twitter.user.name}でログイン"
puts "API:#{Twitter.rate_limit_status.remaining_hits}"


if $iflg 
  save_init_follower
else
  new_follower_ids = check_remove
  save_new_ids(new_follower_ids)
end
