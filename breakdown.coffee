peg = require('pegjs')
fs = require('fs')

grammar = fs.readFileSync('breakdown.peg.js').toString()
parser = peg.generate grammar

module.exports =
  parse: (bd) -> parser.parse bd