neo4j = require('neo4j')
db = new neo4j.GraphDatabase 'http://neo4j:c25a2017@localhost:7474' # FIXME read-only access

Promise = require('bluebird')
db = Promise.promisifyAll db

module.exports =
  update_subgraph: (graph, callback) ->
    tx = Promise.promisifyAll db.beginTransaction()
    # delete old graph
    tx.cypherAsync
      query: 'MATCH (:META:Source {id: {id}})-[r:CREATED]->(n:Info) OPTIONAL MATCH (n)-[r2]-(:Info) DELETE r,r2,n'
      params:
        id: graph.id
    .then () ->
      # create the source if new
      tx.cypherAsync
        query: "MERGE (:META:Source {id: {id}})"
        params:
          id: graph.id
    .then () ->
      # prefix all nodes with the source ID
      graph.nodes.forEach (d) ->
        d.id = graph.id + '|' + d.id

      # create new nodes
      tx.cypherAsync
        query: "WITH {nodes} AS nodes MATCH (s:META:Source {id: {id}}) UNWIND nodes AS n CREATE (s)-[r:CREATED]->(x:Info) SET x += n"
        params:
          nodes: graph.nodes
          id: graph.id
    .then () ->
      # prefix all link ends with the source ID
      graph.links.forEach (d) ->
        d.source = graph.id + '|' + d.source
        d.target = graph.id + '|' + d.target

      # create new internal relationships
      tx.cypherAsync
        query: "WITH {links} AS links UNWIND links AS l MATCH (:META:Source {id: {id}})-[:CREATED]->(s:Info {id: l.source}), (:META:Source {id: {id}})-[:CREATED]->(t:Info {id: l.target}) CREATE (s)-[r:INTERNAL]->(t) SET r += l REMOVE r.source REMOVE r.target"
        params:
          links: graph.links
          id: graph.id
    .then () ->
      tx.commitAsync()
    .then () ->
      callback()
