// Generated by CoffeeScript 1.9.3
(function() {
  var fs, grammar, parser, peg;

  peg = require('pegjs');

  fs = require('fs');

  grammar = fs.readFileSync('breakdown.peg.js').toString();

  parser = peg.generate(grammar);

  module.exports = {
    parse: function(bd) {
      return parser.parse(bd);
    }
  };

}).call(this);
