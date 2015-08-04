![](https://github.com/jeffbyrnes/hubot-forecast/blob/master/hubot-forecast.png)

# hubot-forecast

[![npm version](http://img.shields.io/npm/v/hubot-forecast.svg)](https://www.npmjs.org/package/hubot-forecast)
[![Build Status](http://img.shields.io/travis/jeffbyrnes/hubot-forecast.svg)](https://travis-ci.org/jeffbyrnes/hubot-forecast)

A hubot script to alert for inclement weather.

All credit to @farski for the [original version](https://gist.github.com/farski/7d4049ac401c16c3adc6).

See [`src/forecast.coffee`](src/forecast.coffee) for full documentation.

Important notice for Slack users: you will need hubot-slack >= 3.3.0 due to the usage of Slack attachments.

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
