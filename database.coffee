neo4j = require('neo4j')
db = new neo4j.GraphDatabase 'http://neo4j:c25a2017@localhost:7474' # FIXME read-only access

Promise = require('bluebird')
db = Promise.promisifyAll db

breakdown = require('./breakdown.js')

module.exports =
  update_subgraph: (graph, callback) ->
    # PREPROCESSING
    
    # normalize input
    if not graph.nodes?
      graph.nodes = []

    if not graph.links?
      graph.links = []

    if not graph.annotations?
      graph.annotations = []

    # parse all strings in all nodes to find BreakDown annotations
    # WARNING this assumes a flat graph (i.e., strings within nested
    #   objects or arrays are not parsed)
    graph.nodes.forEach (node) ->
      Object.keys(node).forEach (k) ->
        d = node[k]
        return if typeof d isnt 'string'

        parsed = breakdown.parse d
        d[k+'_plaintext'] = parsed.plain_text

        parsed.spans.forEach (span) ->
          graph.annotations.push {
            target: node.id
            body: span.body
          }
    
    # create all annotation nodes and links
    graph.annotations.forEach (d, i) ->
      d.id = "__annotation__#{i}" # automatic IDs
      d.annotation = true
      graph.nodes.push d

      graph.links.push {
        source: d.id
        target: d.target
        type: 'target'
      }
      delete d.target

      graph.links.push {
        source: d.id
        target: d.body
        type: 'body'
      }
      delete d.body

    # prefix all nodes with the source ID
    graph.nodes.forEach (d) ->
      d.id = graph.id + '|' + d.id

    # tell apart internal from external links
    internal_links = []
    external_links = []
    graph.links.forEach (d) ->
      if d.source.includes('|') or d.target.includes('|')
        external_links.push d
      else
        internal_links.push d

    # prefix all internal ends with the source ID
    graph.links.forEach (d) ->
      d.source = if d.source.includes('|') then d.source else graph.id + '|' + d.source
      d.target = if d.target.includes('|') then d.target else graph.id + '|' + d.target

    # TRANSACTION
    tx = Promise.promisifyAll db.beginTransaction()
    # delete old subgraph
    tx.cypherAsync
      query: 'MATCH (:META:Source {id: {id}})-[:CREATED]->(n) DETACH DELETE n'
      params:
        id: graph.id
    .then () ->
      # delete all previous links from Source to Frontiers
      tx.cypherAsync
        query: "MATCH (:META:Source {id: {id}})-[r:DEFINED]->(n:META:Frontier) DELETE r"
        params:
          id: graph.id
    .then () ->
      # delete frontier nodes that are disconnected from Sources
      tx.cypherAsync
        query: "MATCH (f:META:Frontier) WHERE NOT (f)<-[:DEFINED]-(:META:Source) DETACH DELETE f"
    .then () ->
      # create the source if new
      tx.cypherAsync
        query: "MERGE (:META:Source {id: {id}})"
        params:
          id: graph.id
    .then () ->
      # create new nodes
      tx.cypherAsync
        query: "WITH {nodes} AS nodes MATCH (s:META:Source {id: {id}}) UNWIND nodes AS n CREATE (s)-[:CREATED]->(x) SET x += n"
        params:
          nodes: graph.nodes
          id: graph.id
    .then () ->
      # label Info nodes
      tx.cypherAsync
        query: "MATCH (:META:Source {id: {id}})-[:CREATED]->(n) WHERE EXISTS(n.template) SET n:Info"
        params:
          id: graph.id
    .then () ->
      # label Space nodes
      tx.cypherAsync
        query: "MATCH (:META:Source {id: {id}})-[:CREATED]->(n) WHERE EXISTS(n.view) SET n:Space"
        params:
          id: graph.id
    .then () ->
      # label Annotation nodes
      tx.cypherAsync
        query: "MATCH (:META:Source {id: {id}})-[:CREATED]->(n) WHERE EXISTS(n.annotation) SET n:Annotation REMOVE n.annotation"
        params:
          id: graph.id
    .then () ->
      # create new internal relationships
      tx.cypherAsync
        query: "WITH {links} AS links UNWIND links AS l MATCH (s {id: l.source}), (t {id: l.target}) CREATE (s)-[r:INTERNAL]->(t) SET r += l REMOVE r.source REMOVE r.target"
        params:
          links: internal_links
    .then () ->
      # create new frontier nodes for external links
      tx.cypherAsync
        query: "WITH {links} AS links UNWIND links AS l MERGE (f:META:Frontier {source: l.source, target: l.target, type: l.type}) SET f += l"
        params:
          links: external_links
    .then () ->
      # link Source node to frontiers
      tx.cypherAsync
        query: "WITH {links} AS links UNWIND links AS l MATCH (s:META:Source {id: {id}}), (f:META:Frontier {source: l.source, target: l.target, type: l.type}) MERGE (s)-[:DEFINED]->(f)"
        params:
          id: graph.id
          links: external_links
    .then () ->
      # link sources to frontier nodes
      tx.cypherAsync
        query: "MATCH (n), (f:META:Frontier {source: n.id}) MERGE (f)-[:SOURCE]->(n)"
    .then () ->
      # link targets to frontier nodes
      tx.cypherAsync
        query: "MATCH (n), (f:META:Frontier {target: n.id}) MERGE (f)-[:TARGET]->(n)"
    .then () ->
      # ensure the existence of a skip link for each frontier node
      tx.cypherAsync
        query: "MATCH (n)<-[:SOURCE]-(f:META:Frontier)-[:TARGET]->(m) MERGE (n)-[r:EXTERNAL {type: f.type}]->(m) SET r += f REMOVE r.source REMOVE r.target"
    .then () ->
      tx.commitAsync()
    .then () ->
      callback()
