redis = require('redis').createClient()

# name of the redis channels used for controlling the Knowledge Graph
UPDATE_CHANNEL = 'kgraph_update_requests'

# example graph to be updated
graph =
  source: 'test' # this is an ID for identifying where to mount the update
  nodes: [
    {id: 1, label: 'pippo'},
    {id: 2, label: 'pluto'}
  ]
  links: [
    {source: 1, target: 2, type: 'KNOWS', weight: 5}
  ]

redis.publish UPDATE_CHANNEL, JSON.stringify graph

redis.on 'ready', () ->
  process.exit 0
