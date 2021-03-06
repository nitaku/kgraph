// Generated by CoffeeScript 1.9.3
(function() {
  var UPDATE_CHANNEL, graph, redis;

  redis = require('redis').createClient();

  UPDATE_CHANNEL = 'kgraph_update_requests';

  graph = {
    source: 'test',
    nodes: [
      {
        id: 1,
        label: 'pippo'
      }, {
        id: 2,
        label: 'pluto'
      }
    ],
    links: [
      {
        source: 1,
        target: 2,
        type: 'KNOWS',
        weight: 5
      }
    ]
  };

  redis.publish(UPDATE_CHANNEL, JSON.stringify(graph));

  redis.on('ready', function() {
    return process.exit(0);
  });

}).call(this);
