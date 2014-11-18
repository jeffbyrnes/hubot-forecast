# hubot-forecast

A hubot script to alert for inclement weather.

All credit to @farski for the [original version](https://gist.github.com/farski/7d4049ac401c16c3adc6).

See [`src/forecast.coffee`](src/forecast.coffee) for full documentation.

## Installation

In hubot project repo, run:

```bash
$ npm install hubot-forecast --save
```

Then add **hubot-forecast** to your `external-scripts.json`:

```json
["hubot-forecast"]
```

Finally, set the two necessary EnvVars:

```bash
$ heroku config:set \
    HUBOT_FORECAST_KEY=... \
    HUBOT_LAT_LNG=12.345,67.890 \
    HUBOT_FORECAST_ROOM='some_room@conf.hipchat.com'
```

You can find your Forecast.io API key on their [developers’ page](http://developer.forecast.io), and you can use [this tool](http://www.latlong.net) to determine your latitude & longitude from an address.

As for the `HUBOT_FORECAST_ROOM`, that depends on your adapter; the example above is for HipChat, for Slack, it would be something like `#general`.
