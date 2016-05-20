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

Forecast = require 'forecast.io-bluebird'

KV_KEY = 'forecast-alert-datapoint'
LAST_FORECAST = 'forecast-json'
LATITUDE = process.env.HUBOT_LATITUDE
LONGITUDE = process.env.HUBOT_LONGITUDE
PROBABILITY_THRESHOLD = process.env.HUBOT_FORECAST_PROBABILITY_THRESHOLD || 0.75
FORECASTKEY = process.env.HUBOT_FORECAST_KEY
UNITTYPE = process.env.HUBOT_FORECAST_UNITS || 'si'
if UNITTYPE == 'us'
  TEMP_UNIT = 'F'
else
  TEMP_UNIT = 'C'

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

class Weather
  constructor: (robot, forecast) ->
    @robot = robot
    @forecast = forecast
    @log 'info', 'Starting weather service...'

  log: (type, msg) ->
    @robot.logger[type] "[Forecast] #{msg}"

  lastForecast: ->
    try
      lastForecast = @robot.brain.get LAST_FORECAST
    catch
      @log 'warn', 'No last forecast cached'
      lastForecast = {}

    lastForecast

  lastForecastTime: ->
    lastForecast = @lastForecast()
    if lastForecast and lastForecast.currently
      lastForecast.currently.time
    else
      0

  lastForecastStale: ->
    now = new Date()

    # JS loves to do time math in milliseconds
    since = now - (@lastForecastTime() * 1000)

    # Only fetch a new forecast if the cached one is older than 5 minutes
    return true if since > (5 * 60 * 1000)

    false

  fetch: ->
    that = @

    if @lastForecastStale()
      that.log 'info', "Requesting forecast data"

      options =
        units: UNITTYPE

      @forecast.fetch(LATITUDE, LONGITUDE, options).then((result) ->
        that.robot.brain.set LAST_FORECAST, data
      ).catch (error) ->
        that.log 'error', error
    else
      that.log 'info', 'Last forecast data is still fresh, returning cached data'
      that.robot.brain.get LAST_FORECAST

  showLastForecast: (msg) ->
    that = @

    @fetch().then((result) ->
      forecast = that.robot.brain.get LAST_FORECAST

      response = "Currently: #{forecast.currently.summary} #{forecast.currently.temperature}°#{TEMP_UNIT}"
      response += "\nToday: #{forecast.hourly.summary}"
      response += "\nComing week: #{forecast.daily.summary}"

      if that.robot.adapterName == 'slack'
        that.robot.emit 'slack-attachment',
          channel: msg.envelope.room
          content:
            color: '#000000'
            title: 'Here is your weather report…'
            text: response
            fallback: response
          message: ''
      else
        msg.send response
    ).catch (error) ->
      that.log 'error', error

  handleNewWeather: (forecast, callback) ->
    dataPoint = forecast['minutely']['data'][0]

    response = 'WEATHER: The weather should be clear for at least an hour.'

    if that.robot.adapterName == 'slack'
      that.robot.emit 'slack-attachment',
        channel: msg.envelope.room
        content:
          color: '#000000'
          title: 'Here is your weather report…'
          text: response
          fallback: response
        message: ''
    else
      msg.send response

  handleContinuingWeather: (forecast, callback) ->
    # stuff

  newBadWeather: (forecast) ->
    alertDataPoint = that.robot.brain.get KV_KEY || {}
    alertIntensity = alertDataPoint['precipIntensity'] || 0

    # This seems backwards, until you realize that its only new weather if we
    # don’t have any previous data points stored in the brain
    return true if alertIntensity == 0

    false

  newGoodWeather: (forecast) ->
    alertDataPoint = that.robot.brain.get KV_KEY || {}
    alertIntensity = alertDataPoint['precipIntensity'] || 0

    return false if alertIntensity == 0

    true

  handleWeather: (forecast, callback) ->
    if @newBadWeather()
      @handleNewWeather forecast, callback
    else
      @handleContinuingWeather forecast, callback

  handleClear: (forecast, callback) ->
    if @newGoodWeather()
      # Forecast has cleared after a period of inclement weather; post a
      # notification (not checking time since last alert because this seems like
      # very important information, and should be posted regardless)
      @log 'info', 'Weather has cleared.'
      @handleNewWeather forecast, callback
    else
      # This is where we end up most of the time (clear forecast currently
      # following a clear forecast previously); no need to do anything
      @log 'info', 'Continued clear weather.'
      @handleContinuingWeather forecast, callback

  weatherIsBad: (forecast) ->
    # Figure out if the weather is bad by looping over each minute-by-minute
    # datapoint supplied by Forecast.io
    dataPoints = forecast['minutely']['data']
    totalIntensity = 0

    for dataPoint in dataPoints
      totalIntensity += dataPoint['precipIntensity']

    return true if totalIntensity > 0

    false

  checkForecast: (forecast, callback) ->
    if @weatherIsBad forecast
      @handleWeather forecast, callback
    else
      @handleClear forecast, callback

  weatherAlert: (msg) ->
    that = @
    now = new Date()

    # Only run during specified time windows
    active = true
      # now.toUTCString().substr(0,3).toLowerCase() in activeDays and
      # now.getUTCHours() in activeHours

    if active
      room = process.env.HUBOT_FORECAST_ROOM

      # Update the forecast cache if necessary
      @fetch().then((result) ->
        forecast = that.robot.brain.get LAST_FORECAST

        that.checkForecast forecast, (msg, msgColor, mostIntenseDataPoint) ->
          # Cache the data point related to this alert and send the message to the room
          mostIntenseDataPoint['__alertTime'] = now
          that.robot.brain.set KV_KEY, mostIntenseDataPoint

          if that.robot.adapterName == 'slack'
            that.robot.emit 'slack-attachment',
              channel: room
              content:
                color: msgColor
                title: 'Weather Update!'
                text: msg
                fallback: msg
              message: ''
          else
            that.robot.messageRoom room, msg
      ).catch (error) ->
        that.log 'error', error
    else
      # Remove the alert data cache between work days
      @log 'info', 'Sleeping'

      @robot.brain.remove KV_KEY

module.exports = (robot) ->
  unless FORECASTKEY? and LATITUDE? and LONGITUDE?
    return robot.logger.error 'hubot-forecast is not loaded due to missing configuration.
      HUBOT_FORECAST_KEY, HUBOT_LATITUDE, & HUBOT_LONGITUDE are required.'

  forecast = new Forecast
    key: FORECASTKEY,
    timeout: 2500

  robot.weather = new Weather robot, forecast

  setInterval robot.weather.weatherAlert, (5 * 60 * 1000)
  robot.weather.weatherAlert()

  robot.respond /forecast|weather/i, (msg) ->
    robot.weather.showLastForecast msg
