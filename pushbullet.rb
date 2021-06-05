# https://docs.pushbullet.com/#create-push
require 'faraday'
require 'json'

class PushBullet
  URL = "https://api.pushbullet.com/v2/pushes"

  def initialize(token)
    @token = token
  end

  def broadcast(title, message)
    params = {
      type: 'note',
      title: title,
      body: message
    }

    Faraday.post(URL) do |req|
      req.body = params.to_json
      req.headers['Access-Token'] = @token
      req.headers['Content-Type'] = 'application/json'
    end
  end
end
