Rank = require('../poker/rank').PokerRank


module.exports.PokerActionRank = class PokerActionRank extends Rank
  constructor: (hand)->
    super(
      hand.filter (card)-> !card.check('p')
      .map (card)-> card.card
    )
