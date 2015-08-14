path = require 'path'
fs = require 'fs'
Robot = require 'hubot/src/robot'
TextMessage = require('hubot/src/message').TextMessage
chai = require 'chai'
sinon = require 'sinon'
chai.use require 'sinon-chai'
{ expect } = chai

loadFixture = (name)->
  JSON.parse fs.readFileSync "spec/fixtures/#{name}.json"

describe 'forecast', ->
  robot = undefined
  user = undefined
  adapter = undefined

  beforeEach ->
    # create new robot, without http, using the mock adapter
    robot = new Robot null, 'mock-adapter', yes, 'TestHubot'

  afterEach ->
    robot.server.close()
    robot.shutdown()

  describe 'when ENV is not set', ->
    it 'should throw error', (done)->
      sinon.spy robot.logger, 'error'
      robot.adapter.on 'connected', ->
        try
          delete process.env.HUBOT_LATITUDE
          delete process.env.HUBOT_LONGITUDE
          delete process.env.HUBOT_FORECAST_KEY

          robot.loadFile path.resolve('.', 'src'), 'forecast.coffee'

          expect(robot.logger.error).to.have.been.called
          expect(robot.forecast).not.to.be.defined

          do done
        catch e
          done e
      do robot.run

  describe 'when ENV is set', ->
    beforeEach (done)->
      process.env.HUBOT_FORECAST_KEY = '234f931fed3c5c7b54c846c9100f8b50'
      process.env.HUBOT_LATITUDE = '42.351170'
      process.env.HUBOT_LONGITUDE = '-71.049298'

      robot.adapter.on 'connected', ->
        robot.loadFile path.resolve('.', 'src'), 'forecast.coffee'
        user = robot.brain.userForId '1', {
          name: 'jeff'
          room: '#mocha'
        }
        adapter = robot.adapter

        waitForHelp = ->
          if robot.helpCommands().length > 0
            do done
          else
            setTimeout waitForHelp, 100
        do waitForHelp
      do robot.run

    describe 'help', ->
      it 'should have 2', (done)->
        expect(robot.helpCommands()).to.have.length 2
        do done

      it 'has help messages', ->
        expect(robot.helpCommands()).to.eql [
          'hubot forecast - same as hubot weather'
          'hubot weather - shows brief weather forecast from last cached data'
        ]
