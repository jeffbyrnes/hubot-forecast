![](https://github.com/jeffbyrnes/hubot-forecast/blob/master/hubot-forecast.png)

# hubot-forecast

[![npm version](http://img.shields.io/npm/v/hubot-forecast.svg)](https://www.npmjs.org/package/hubot-forecast)
[![Build Status](http://img.shields.io/travis/jeffbyrnes/hubot-forecast.svg)](https://travis-ci.org/jeffbyrnes/hubot-forecast)

A hubot script to alert for inclement weather.

All credit to @farski for the [original version](https://gist.github.com/farski/7d4049ac401c16c3adc6).

See [`src/forecast.coffee`](src/forecast.coffee) for full documentation.

Important notice for Slack users: you will need hubot-slack >= 3.3.0 due to the usage of Slack attachments.

## Spec

* Provides on-demand retrieval of the weather
* Offers both imperial & metric units
* Provides regular checking of forecast
    - Limits itself
        + days of operation (`HUBOT_FORECAST_DAYS`)
        + hours of operation (`HUBOT_FORECAST_TIME`)
* Alerts on changes to the forecast
    - Postive to negative (“about to rain”)
    - Negative to postive (“rain clearing up”)
* Retrieves forecast data from Forecast.io
    - Caches this data in Hubot brain
    - Iterate over the `minutely` portion to determine if weather is changing
        + `minutely.data` is an array of objects representing every minute of the next hour
        + utilizes `HUBOT_FORECAST_PROBABILITY_THRESHOLD` to avoid alerting on any potential rain
            * This corresponds to `minutely.data[x].precipProbability` in the API response
* Retrieval steps:
    1. Fetch the forecast data (need to rely on promises? b/c async)
        * If we have a cache and, if’s fresh (< 5min old) use the cached data, rejecting any `minutely.data` that is older that the current timestamp
        * If cache is stale/empty, fetch new data & freshen the cache
    2. Analyze the weather:
        1. Figure out if the weather is bad by looping over each minute-by-minute datapoint (`minutely.data`) supplied by Forecast.io
            * Bad:
                - If this is newly bad, send a chat message
                - If it’s staying bad, do nothing (maybe log?)
            * Good:
                - If this is newly good, send a chat message
                - If it’s been good, do nothing (log?)

## Installation

In hubot project repo, run:

```bash
$ npm install hubot-forecast --save
```

Then add **hubot-forecast** to your `external-scripts.json`:

```json
["hubot-forecast"]
```

Finally, set the necessary EnvVars:

```bash
$ heroku config:set \
    HUBOT_FORECAST_KEY=... \
    HUBOT_FORECAST_ROOM='some_room@conf.hipchat.com' \
    HUBOT_LATITUDE=12.345 \
    HUBOT_LONGITUDE=67.890
```

You can find your Forecast.io API key on their [developers’ page](http://developer.forecast.io), and you can use [this tool](http://www.latlong.net) to determine your latitude & longitude from an address.

As for the `HUBOT_FORECAST_ROOM`, that depends on your adapter; the example above is for HipChat, for Slack, it would be something like `general`.

If you live in the US, and wish to use Fahrenheit, you’ll want to:

```bash
$ heroku config:set HUBOT_FORECAST_UNITS=us
```

Otherwise your bot will report in Celsius, which is the default.

If you’d like to only report based on a particular probability, you can set that like so (i.e., a 75% chance being the default):

```bash
HUBOT_FORECAST_PROBABILITY_THRESHOLD=0.75
```

Some additional EnvVars exist if you want to customize the “working time” for the forecast reporting (default values shown below):

```bash
HUBOT_FORECAST_DAYS=mon,tue,wed,thu,fri
HUBOT_FORECAST_TIME=11-23
```
