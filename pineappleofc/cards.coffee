Cards = require('../poker/cards').Cards


module.exports.CardsId = class CardsId extends Cards
  shuffle: ->
    super ...arguments
    @_deck = @_deck.map (card, i)-> {i, card}
    @
