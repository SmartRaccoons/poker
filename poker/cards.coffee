Rank = require('./rank')


_ranks = Rank.PokerRank::_deck_ranks
_suits = Rank.PokerRank::_deck_suits


shuffle = (array) ->
  for i in [0...array.length]
    j = Math.floor(Math.random() * (i + 1))
    [array[i], array[j]] = [array[j], array[i]]
  array

_deck = _ranks.reduce (result, item)->
  result.concat _suits.map (s)-> "#{item}#{s}"
, []


module.exports.Cards = class Cards
  shuffle: ->
    @_deck = shuffle _deck.slice()

  pop: -> @_deck.pop()
