IsDevEnv = (ENV['HOME'] == '/Users/shubhamgupta')

require 'date'
require 'json'
require 'faraday'
require './pushbullet.rb'

if IsDevEnv
  require 'byebug'
end

TIME = Time.now
TIME += (330 * 60) unless IsDevEnv # UTC to IST

LOGDIR = "./logs/#{TIME.year}/#{TIME.month}/#{TIME.day}"
`mkdir -p #{LOGDIR}`
LOGPATH = LOGDIR + '/' + TIME.strftime("%H%M%S")

begin

  URL = "https://cdn-api.co-vin.in/api/v2/appointment/sessions/public/calendarByPin"
  params = {
    pincode: "245101",
    date: TIME.strftime("%d-%m-%Y")
  }
  AGE = ENV['AGE']&.to_i || 27

  if IsDevEnv
    Pb = PushBullet.new ENV['PUSHBULLET_TOKEN']
  else
    Pb = PushBullet.new(File.read("./pbtoken"))
  end

  AvailableCapacity = -> (session) do
    session['available_capacity'] ||
      session['available_capacity_dose1']
  end

  FilterSessions = -> (center) do
    center['sessions'].select do |session|
      session['min_age_limit'] < AGE &&
      AvailableCapacity.call(session) > 0
    end
  end

  FilterCenters = -> (centers) do
    centers.select do |center|
      ( FilterSessions.call(center).size > 0 ) &&
        !center['address'].include?('xclusive')
    end
  end

  FriendlySessions = -> (center) do
    sessions = FilterSessions.call(center)
    doses = sessions.map do |s|
      count = AvailableCapacity.call(s)
      date = Date.parse(s['date']).strftime("%d-%b-%Y")
      "#{count} #{s['vaccine']} #{date} @ #{center['name']}, #{center['address']}"
    end
  end

  def get_friendly_message(friendly_sessions)
    message = friendly_sessions.sort_by{|s| s.split(' ').first }.reverse.join("\n")

    logfile = File.open(LOGPATH+'.match', 'a')
    logfile.write(message)
    logfile.close

    message
  end

  response = Faraday.get(URL, params)
  data = JSON.parse(response.body)

  logfile = File.open(LOGPATH, 'a')
  logfile.write(JSON.pretty_generate(JSON.parse(response.body)))
  logfile.close

  filtered_data = FilterCenters.call(data['centers'])
  friendly_sessions = filtered_data.map(&FriendlySessions).flatten

  if friendly_sessions.size > 0
    title = "Vaccines Available"
    message = get_friendly_message(friendly_sessions)

    if IsDevEnv
      puts title
      puts message
    else
      Pb.broadcast(title, message)
    end
  end
rescue => e
  logfile = File.open(LOGPATH+'.err', 'a')
  logfile.write("#{e.class.name}\n#{e.message}\n\n#{e.backtrace.join("\n")}")
  logfile.close
end
