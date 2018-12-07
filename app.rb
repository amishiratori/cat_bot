require 'bundler/setup'
Bundler.require
require 'sinatra/reloader' if development?
require 'dotenv'
require 'google/cloud/language'
require 'net/http'
require 'uri'
require 'erb'
require 'line/bot'

include ERB::Util

Dotenv.load

before do
  def client
    @client ||= Line::Bot::Client.new { |config|
        config.channel_secret = ENV['LINE_CHANNEL_SECRET']
        config.channel_token = ENV['LINE_CHANNEL_TOKEN']
    }
  end
end

post '/message' do
  body = request.body.read
  signature = request.env['HTTP_X_LINE_SIGNATURE']
  unless client.validate_signature(body, signature)
    error 400 do 'Bad Request' end
  end
  events = client.parse_events_from(body)
  events.each do |event|
      case event
          when Line::Bot::Event::Message
              case event.type
                  when Line::Bot::Event::MessageType::Text
                    content = event.message['text']
                    language = Google::Cloud::Language.new
                    response = language.analyze_sentiment content: content, type: :PLAIN_TEXT
                    sentiment = response.document_sentiment
                    score = sentiment.score
                  
                    if score < 0.1
                      base_url = 'https://www.googleapis.com/customsearch/v1?key='
                      base_url << ENV['API_KEY']
                      base_url << '&cx='
                      base_url << ENV['SEARCH_ENGINE_ID']
                      base_url << '&searchType=image&q='
                      base_url << url_encode('ねこ 癒し')
                      uri = URI.parse(base_url)
                      result = Net::HTTP.get_response(uri)
                      res = JSON.parse(result.body)
                      items = res['items']
                      images = Array.new
                      items.each do |item|
                        images << item['link']
                      end
                      selected_image = images[rand(images.length)]
                      message = {
                        type: 'image',
                        originalContentUrl: selected_image,
                        previewImageUrl: selected_image
                      }
                      client.reply_message(event['replyToken'], message)
                    else
                      response_message = '今日も1日がんばろうね！'
                      message = {
                        type: 'text',
                        text: response_message
                      }
                      client.reply_message(event['replyToken'], message)
                      break
                    end
                  else
                    response_message = 'ぼくになにか話しかけてみてね！'
                    message = {
                        type: 'text',
                        text: response_message
                      }
                      client.reply_message(event['replyToken'], message)
                    break
              end
      end
  end
end
