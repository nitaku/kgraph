redis = require('redis').createClient()
db = require('./database')

CHANNEL = 'kgraph'

redis.on 'message', (channel, message) ->
  if channel is CHANNEL
    graph = JSON.parse message

    console.log ''
    console.log "Processing source #{graph.id}..."

    # TODO use promises and handle errors
    db.update_subgraph graph, () ->
      console.log '...done.'

redis.subscribe CHANNEL
console.log "Subscribed to redis channel #{CHANNEL}."
console.log "Waiting for update requests..."
