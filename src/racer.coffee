Model = require './Model'
Store = require './Store'
socketio = require 'socket.io'
ioClient = require 'socket.io-client'
browserify = require 'browserify'
uglify = require 'uglify-js'

Racer = (options) ->
  # TODO: Provide full configuration for socket.io
  # TODO: Add configuration for Redis

  storeOptions = {}
  storeOptions = redis: options.redis if options.redis
  @store = store = new Store options.storeAdapter, storeOptions

  ## Setup socket.io ##
  listen = options.listen || 8080
  ioUri = options.ioUri ||
    if typeof listen is 'number' then ':' + options.ioPort else ''
  if options.ioSockets
    store._setSockets @sockets = options.ioSockets
  else
    io = socketio.listen(listen)
    io.configure ->
      io.set 'browser client', false
    store._setSockets @sockets = io.sockets
  
  # Adds server functions to Model's prototype
  require('./Model.server')(store, ioUri)
  return

Racer:: =
  use: -> throw 'Unimplemented'

  js: (options, callback) ->
    [callback, options] = [options, {}] if typeof options is 'function'
    require = ['racer']
    options.require = if options.require
        require.concat options.require
      else require
    if (minify = options.minify) is undefined then minify = true
    options.filter = uglify if minify
    
    ioClient.builder ['websocket', 'xhr-polling'], {minify}, (err, value) ->
      throw err if err
      callback value + ';' + browserify.bundle options

  ## Connect Middleware ##
  # The racer module returns connect middleware for
  # easy integration into connect/express
  # 1. Assigns clientId's if not yet assigned
  # 2. Instantiates a new Model and attaches it to the incoming request,
  #    for access from route handlers later
  middleware: ->
    store = @store
    return (req, res, next) ->
      if !req.session
        # TODO Do this check only the first time the middleware is invoked
        throw 'Missing session middleware'
      finish = (clientId) ->
        req.model = new Model clientId
        next()
      # TODO Security checks via session
      if clientId = req.params.clientId || req.body.clientId
        finish clientId
      else
        store._nextClientId finish

exports.Racer = Racer
