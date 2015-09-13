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

ForecastIo = require 'forecastio'

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

class Weather
  constructor: (robot, forecastIo) ->
    @robot = robot
    @forecastIo = forecastIo
    @log 'info', '[Forecast] Starting weather service...'

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
      @log 'info', "Requesting forecast data"

      options =
        units: UNITTYPE

      @forecastIo.forecast LATITUDE, LONGITUDE, (err, data) ->
        that.log 'error', err if err

        that.robot.brain.set LAST_FORECAST, data
    else
      @log 'info', 'Last forecast data is still fresh, returning cached data'

  showLastForecast: (msg) ->
    @fetch()
    forecast = @robot.brain.get LAST_FORECAST

    response = "Currently: #{forecast.currently.summary} #{forecast.currently.temperature}°#{TEMP_UNIT}"
    response += "\nToday: #{forecast.hourly.summary}"
    response += "\nComing week: #{forecast.daily.summary}"

    if @robot.adapterName == 'slack'
      @robot.emit 'slack-attachment',
        channel: msg.envelope.room
        content:
          color: '#000000'
          title: 'Here is your weather report…'
          text: response
          fallback: response
        message: ''
    else
      msg.send response


module.exports = (robot) ->
  unless FORECASTKEY? and LATITUDE? and LONGITUDE?
    return robot.logger.error 'hubot-forecast is not loaded due to missing configuration.
      HUBOT_FORECAST_KEY, HUBOT_LATITUDE, & HUBOT_LONGITUDE are required.'

  forecastIo = new ForecastIo FORECASTKEY

  robot.weather = new Weather robot, forecastIo

  # setInterval robot.weather.forecast, (5 * 60 * 1000)
  # robot.weather.forecast()

  robot.respond /forecast|weather/i, (msg) ->
    robot.weather.showLastForecast(msg)
