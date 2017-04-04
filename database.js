// Generated by CoffeeScript 1.12.4
(function() {
  var Promise, db, neo4j;

  neo4j = require('neo4j');

  db = new neo4j.GraphDatabase('http://neo4j:c25a2017@localhost:7474');

  Promise = require('bluebird');

  db = Promise.promisifyAll(db);

  module.exports = {
    update_subgraph: function(graph, callback) {
      var external_links, internal_links, tx;
      graph.nodes.forEach(function(d) {
        return d.id = graph.id + '|' + d.id;
      });
      internal_links = [];
      external_links = [];
      graph.links.forEach(function(d) {
        if (d.source.includes('|') || d.target.includes('|')) {
          return external_links.push(d);
        } else {
          return internal_links.push(d);
        }
      });
      graph.links.forEach(function(d) {
        d.source = d.source.includes('|') ? d.source : graph.id + '|' + d.source;
        return d.target = d.target.includes('|') ? d.target : graph.id + '|' + d.target;
      });
      tx = Promise.promisifyAll(db.beginTransaction());
      return tx.cypherAsync({
        query: 'MATCH (:META:Source {id: {id}})-[:CREATED]->(n) DETACH DELETE n',
        params: {
          id: graph.id
        }
      }).then(function() {
        return tx.cypherAsync({
          query: "MERGE (:META:Source {id: {id}})",
          params: {
            id: graph.id
          }
        });
      }).then(function() {
        return tx.cypherAsync({
          query: "WITH {nodes} AS nodes MATCH (s:META:Source {id: {id}}) UNWIND nodes AS n CREATE (s)-[:CREATED]->(x) SET x += n",
          params: {
            nodes: graph.nodes,
            id: graph.id
          }
        });
      }).then(function() {
        return tx.cypherAsync({
          query: "MATCH (:META:Source {id: {id}})-[:CREATED]->(n) WHERE EXISTS(n.template) SET n:Info",
          params: {
            id: graph.id
          }
        });
      }).then(function() {
        return tx.cypherAsync({
          query: "MATCH (:META:Source {id: {id}})-[:CREATED]->(n) WHERE EXISTS(n.view) SET n:Space",
          params: {
            id: graph.id
          }
        });
      }).then(function() {
        return tx.cypherAsync({
          query: "WITH {links} AS links UNWIND links AS l MATCH (s {id: l.source}), (t {id: l.target}) CREATE (s)-[r:INTERNAL]->(t) SET r += l REMOVE r.source REMOVE r.target",
          params: {
            links: internal_links
          }
        });
      }).then(function() {
        return tx.cypherAsync({
          query: "WITH {links} AS links UNWIND links AS l MERGE (f:META:Frontier {source: l.source, target: l.target, type: l.type}) SET f += l",
          params: {
            links: external_links
          }
        });
      }).then(function() {
        return tx.cypherAsync({
          query: "MATCH (n), (f:META:Frontier {source: n.id}) MERGE (f)-[:SOURCE]->(n)"
        });
      }).then(function() {
        return tx.cypherAsync({
          query: "MATCH (n), (f:META:Frontier {target: n.id}) MERGE (f)-[:TARGET]->(n)"
        });
      }).then(function() {
        return tx.cypherAsync({
          query: "MATCH (n)<-[:SOURCE]-(f:META:Frontier)-[:TARGET]->(m) MERGE (n)-[r:EXTERNAL {type: f.type}]->(m) SET r += f REMOVE r.source REMOVE r.target"
        });
      }).then(function() {
        return tx.cypherAsync({
          query: "MATCH (f:META:Frontier) WHERE NOT (f)--() DELETE f"
        });
      }).then(function() {
        return tx.commitAsync();
      }).then(function() {
        return callback();
      });
    }
  };

}).call(this);
