_ranks = ['A', 'K', 'Q', 'J', 'T', '9', '8', '7', '6', '5', '4', '3', '2']
_suits = ['c', 's', 'h', 'd'] #Clubs (c) Spades (s) Hearts (h) Diamonds (d)


module.exports.Cards = class Cards
  _ranks: _ranks
  _suits: _suits
  _deck: _ranks.reduce (result, item)->
    result.concat _suits.map (s)-> "#{item}#{s}"
  , []

  # rank: (cards)->
  #
