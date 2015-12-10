# Description
#   A hubot script to alert for inclement weather
#
# Configuration:
#   HUBOT_FORECAST_DAYS - When do you need weather? Default: mon,tue,wed,thu,fri
#   HUBOT_FORECAST_KEY - forecast.io API key
#   HUBOT_FORECAST_ROOM - Room bulletins should be posted in (if slack, just use channel, no #)
#   HUBOT_FORECAST_TIME - On/off times in hours. Default 11-23
#   HUBOT_LATITUDE - Latitude in decimal degrees
#   HUBOT_LONGITUDE - Longitude in decimal degrees
#   HUBOT_SLACK_BOTNAME - (Optional) Botname in slack
#   HUBOT_FORECAST_UNITS - (Optional) Units to use. Use either 'us' or 'si'. Defaults to 'si'.
#   HUBOT_FORECAST_PROBABILITY_THRESHOLD - (Optional) Probability to exceed, in decimal, before posting
#
# Commands:
#   hubot weather - shows brief weather forecast from last cached data
#   hubot forecast - same as hubot weather
#
# Notes:
#   This script sets up automated alerts, and rquires only that the
#   necessary EnvVars be set. See the README for details.
#   All dates/times UTC
#
# Author:
#   farski
#   jeffbyrnes
#   oehokie

KV_KEY = 'forecast-alert-datapoint'
LOCATION = process.env.HUBOT_LATITUDE + ',' + process.env.HUBOT_LONGITUDE
PROBABILITY_THRESHOLD = process.env.HUBOT_FORECAST_PROBABILITY_THRESHOLD || 0.75
FORECASTKEY = process.env.HUBOT_FORECAST_KEY
UNITTYPE = (process.env.HUBOT_FORECAST_UNITS || 'si').toLowerCase()
EXCLUDE = 'flags'

activeDays = (process.env.HUBOT_FORECAST_DAYS ? 'mon,tue,wed,thu,fri')
  .toLowerCase()
  .split ','
activeHours = (process.env.HUBOT_FORECAST_TIME ? '07-20')
  .split(',')
  .reduce(((hours, range) ->
    [start, stop] = range.split '-'
    hours.concat([start...stop])
  ), [])
  .map (i) -> parseInt(i, 10)

last_json = {}

module.exports = (robot) ->
  unless FORECASTKEY? and LOCATION?
    return robot.logger.error 'hubot-forecast is not loaded due to missing configuration.
      HUBOT_FORECAST_KEY, HUBOT_LATITUDE, & HUBOT_LONGITUDE are required.'

  postWeatherAlert = (json, callback) ->
    postMessage = callback
    now = new Date()

    # This function posts an alert about the current forecast data always. It
    # doesn't determine if the alert should be posted.

    dataPoints = json['minutely']['data']

    dataPointsWithPrecipitation = []
    mostIntenseDataPoint = {}
    mostProbableDataPoint = {}

    for dataPoint in dataPoints
      intensity = dataPoint['precipIntensity'] || 0
      probability = dataPoint['precipProbability'] || 0

      if intensity > 0
        dataPointsWithPrecipitation.push(dataPoint)

        hightIntensity = mostIntenseDataPoint['precipIntensity'] || 0
        if intensity > hightIntensity
          mostIntenseDataPoint = dataPoint

        hightProbability = mostProbableDataPoint['precipProbability'] || 0
        if probability > hightProbability
          mostProbableDataPoint = dataPoint

    _minutes = dataPointsWithPrecipitation.length

    probability = mostProbableDataPoint['precipProbability']
    _percent = Math.round(probability * 100)

    intensity = mostIntenseDataPoint['precipIntensity']
    if intensity >= 0.4
      _intensity = 'heavy'
    else if intensity >= 0.1
      _intensity = 'moderate'
    else if intensity >= 0.02
      _intensity = 'light'
    else
      _intensity = 'very light'

    timestamp = mostIntenseDataPoint['time']
    date = new Date(timestamp * 1000)
    delta = (date - now)

    _delay = "#{Math.max(0, Math.round(delta / 60 / 1000))}"

    _now = new Date().getTime()
    _link = "http://forecast.io/#/f/#{LOCATION}/#{Math.round(_now / 1000)}"

    msg = "WEATHER: #{_percent}% chance of inclement weather in the next hour for at least #{_minutes} minutes. It will be worst in #{_delay} minutes (#{_intensity} precipitation). #{_link}"

    postMessage(msg, 'danger', mostIntenseDataPoint)

  handleClear = (json, callback) ->
    postMessage = callback

    alertDataPoint = robot.brain.get(KV_KEY) || {}
    alertIntensity = alertDataPoint['precipIntensity'] || 0

    if alertIntensity == 0
      # This is where we end up most of the time (clear forecast currently
      # following a clear forecast previously); no need to do anything
      console.log '[Forecast] Continued clear weather.'

      return

    else
      # Forecast has cleared after a period of inclement weather; post a
      # notification (not checking time since last alert because this seems like
      # very important information, and should be posted regardless)
      console.log '[Forecast] Weather has cleared.'

      dataPoints = json['minutely']['data']
      dataPoint = dataPoints[0]

      msg = 'WEATHER: The weather should be clear for at least an hour.'

      postMessage(msg, 'good', dataPoint)

  handleNewWeather = (json, callback) ->
    isAnomaly = false

    # This is a new inclement weather forecast. As long as it doesn't seem to be
    # bogus data there should be an alert for it

    dataPointsWithPrecipitation = []
    mostIntenseDataPoint = {}
    totalIntensity = 0

    dataPoints = json['minutely']['data']

    for dataPoint in dataPoints
      intensity = dataPoint['precipIntensity'] || 0

      totalIntensity += intensity

      if intensity > 0
        dataPointsWithPrecipitation.push(dataPoint)

        hightIntensity = mostIntenseDataPoint['precipIntensity'] || 0
        mostIntenseDataPoint = dataPoint if intensity > hightIntensity

    isAnomaly = true if dataPointsWithPrecipitation.length < 5
    isAnomaly = true if mostIntenseDataPoint['precipProbability'] < PROBABILITY_THRESHOLD
    isAnomaly = true if totalIntensity < (3 * mostIntenseDataPoint['precipIntensity'])

    if !isAnomaly
      console.log '[Forecast] Posting alert for new inclement weather'

      postWeatherAlert(json, callback)

  handleContinuingWeather = (json, callback) ->
    now = new Date()
    postMessage = callback

    alertDataPoint = robot.brain.get(KV_KEY) || {}
    alertIntensity = alertDataPoint['precipIntensity'] || 0
    alertTime = alertDataPoint['__alertTime']

    since = (now - alertTime)

    if since > (3 * 60 * 60 * 1000)
      # Three hours is long enough to post a new alert regardless of severity.
      # Not checking for anomalies because 3+ hours of bad weather is very
      # unlikely to be bad data
      console.log '[Forecast] Posting reminder alert'

      postWeatherAlert(json, callback)
    else
      # If it's been less than three hours only post an alert if the weather is
      # getting significantly worse or there's enough data to predict a break
      # in the weather
      mostIntenseDataPoint = {}
      totalIntensity = 0

      dataPoints = json['minutely']['data']
      dataPointsWithPrecipitation = []

      for dataPoint in dataPoints
        intensity = dataPoint['precipIntensity'] || 0

        totalIntensity += intensity

        if intensity > 0
          dataPointsWithPrecipitation.push(dataPoint)

          hightIntensity = mostIntenseDataPoint['precipIntensity'] || 0
          mostIntenseDataPoint = dataPoint if intensity > hightIntensity

      hightIntensity = mostIntenseDataPoint['precipIntensity']

      if hightIntensity > (2 * alertIntensity) && hightIntensity > 0.072
        # There's weather in the forecast that is at least twice as bad as the
        # weather was at the last alert so it's worth posting another alert
        console.log '[Forecast] Posting intensifying alert'

        postWeatherAlert(json, callback)

        return

      trailingClearDataPoints = []

      dataPoints.reverse()

      for dataPoint in dataPoints
        intensity = dataPoint['precipIntensity'] || 0

        break if intensity > 0

        trailingClearDataPoints.push(dataPoint)

      dataPoints.reverse()

      if trailingClearDataPoints.length > 30
        # If at least the last 30 minutes of the current forecast is clear post
        # an alert about the break in the weather. The currently cached data
        # point is getting rolled over with this notification so that the cache
        # still represents bad weather
        console.log '[Forecast] Posting weather break alert'

        msg = 'WEATHER: There should be a break in the weather for at least 30 minutes within the hour.'

        postMessage(msg, 'warning', alertDataPoint)

  handleWeather = (json, callback) ->
    alertDataPoint = robot.brain.get(KV_KEY) || {}
    alertIntensity = alertDataPoint['precipIntensity'] || 0

    if alertIntensity == 0
      handleNewWeather(json, callback)
    else
      handleContinuingWeather(json, callback)

  handleJSON = (json, callback) ->
    last_json = json

    if json['minutely']
      dataPoints = json['minutely']['data'] || []

      if dataPoints.length > 0
        totalIntensity = 0
        for dataPoint in dataPoints
          totalIntensity += (dataPoint['precipIntensity'] || 0)

        if totalIntensity == 0
          handleClear(json, callback)
        else
          handleWeather(json, callback)

  fetchForecast = (callback) ->
    base_url = "https://api.forecast.io/forecast/#{FORECASTKEY}/#{LOCATION}"
    url = "#{base_url}?units=#{UNITTYPE}&exclude=#{EXCLUDE}"

    console.log "[Forecast] Requesting forecast data: #{url}"

    robot.http(url).get() (err, res, body) ->

      if !err
        json = JSON.parse(body)
        handleJSON(json, callback)

  forecast = ->
    now = new Date()

    active =
      now.toUTCString().substr(0,3).toLowerCase() in activeDays and
      now.getUTCHours() in activeHours

    if active
      # Only run during specified time windows
      room = process.env.HUBOT_FORECAST_ROOM
      fetchForecast (msg, msgColor, dataPoint) ->

        # Cache the data point related to this alert and send the message to
        # the room
        dataPoint['__alertTime'] = now
        robot.brain.set(KV_KEY, dataPoint)

        if robot.adapterName == 'slack'
          robot.emit 'slack-attachment',
            channel: room
            content:
              color: msgColor
              title: 'Weather Update!'
              text: msg
              fallback: msg
            message: ''
        else
          robot.messageRoom room, msg
    else
      # Remove the alert data cache between work days
      console.log '[Forecast] Sleeping'

      robot.brain.remove(KV_KEY)

  console.log '[Forecast] Starting weather service...'

  setInterval forecast, (5 * 60 * 1000)
  forecast()

  processLast = (msg, last_json) ->
    temperatureUnit = "C"
    if UNITTYPE == "us"
      temperatureUnit = "F"
    response = "Currently: #{last_json.currently.summary} #{last_json.currently.temperature}°#{temperatureUnit}"
    response += "\nToday: #{last_json.hourly.summary}"
    response += "\nComing week: #{last_json.daily.summary}"
    if robot.adapterName == 'slack'
      robot.emit 'slack-attachment',
        channel: msg.envelope.room
        content:
          color: '#000000'
          title: 'Here is your weather report…'
          text: response
          fallback: response
        message: ''
    else
      msg.send response

  robot.respond /forecast|weather/i, (msg) ->
    if Object.keys(last_json).length == 0
      fetchForecast (json) ->
        last_json = json
        processLast msg, last_json
    else
      processLast msg, last_json
