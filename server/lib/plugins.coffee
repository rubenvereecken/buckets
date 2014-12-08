fs = require 'fs'

glob = require 'glob'
mongoose = require 'mongoose'
_ = require 'underscore'
hbs = require 'hbs'
winston = require 'winston'

db = require './database'
config = require './config'

cwd = config.get('pluginsPath')

loadServerPlugin = (plugin, setup) ->
  # Pass some powerful stuff to the plugin
  # Could also be possible to get plugin specific config through plugin.slug
  config =
    _ = require 'underscore'
  serverConf = setup(config)


  if serverConf.middleware and serverConf.middleware.fieldType
    Entry = require '../models/entry' # This one holds the interface for adding middleware

    for fieldType, fieldTypeConf of serverConf.middleware.fieldType
      {preOrPost, action, callback} = fieldTypeConf
      winston.error "Server config for fieldType #{fieldType} incomplete" unless preOrPost and action and callback
      Entry.addFieldTypeMiddleware fieldType, preOrPost, action, callback
      console.log "Added field type middleware for #{fieldType}" #todo remove

# todo: Re-write this to be non-blocking
module.exports =
  load: ->
    return [] unless cwd

    fieldtypes = {}
    dirs = glob.sync "#{cwd}buckets-*/", cwd: cwd

    _.map dirs, (dir) ->

      plugin = slug: dir.match(/\/buckets\-(.*)\//)?[1]

      try
        Plugin = require dir
      catch e
        console.log e

      if _.isFunction Plugin

        # Pass rando powerful stuff to the plugin constructor
        plugin.server = new Plugin
          hbs: hbs
          db: db
          mongoose: mongoose

        # Find the schema if there is one
        if plugin.server.schema instanceof mongoose.Schema
          dbModel = db.model plugin.slug, mongoose.schema
        else if _.isObject plugin.server.schema
          try
            schema = new mongoose.Schema plugin.server.schema
            model = db.model plugin.slug, schema
            plugin.model = model
          catch e
            console.log 'Error', e

      # Check for client & style
      if glob.sync('client.{coffee,js}', cwd: dir)?.length
        plugin.client = true

      if glob.sync('index.styl', cwd: dir)?.length
        plugin.clientStyle = true

      serverFiles = glob.sync('server.{coffee,js}', cwd: dir)
      for serverFile in serverFiles
        plugin.server = true
        loadServerPlugin plugin, require dir + serverFile

      plugin
