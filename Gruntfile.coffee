"use strict"

module.exports = (grunt) ->
  grunt.initConfig
    mochaTest:
      test:
        options:
          reporter: "spec"
          require: "coffee-script"

        src: ["test/**/*.coffee"]

    watch:
      files: [
        "Gruntfile.coffee"
        "test/**/*.coffee"
      ]
      tasks: ["test"]

  grunt.event.on "watch", (action, filepath, target) ->
    grunt.log.writeln "#{ target }: #{ filepath } has #{ action }"
    return


  # load all grunt tasks
  require("matchdep").filterDev("grunt-*").forEach grunt.loadNpmTasks
  grunt.registerTask "test", ["mochaTest"]
  grunt.registerTask "test:watch", ["watch"]
  grunt.registerTask "default", ["test"]
  return
