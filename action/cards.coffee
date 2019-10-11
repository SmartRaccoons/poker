Cards = require('../poker/cards').Cards
CardParam = require('./card').CardParam



module.exports.CardsParams = class CardsParams extends Cards
  constructor: ->
    super ...arguments
    @shuffle()

  shuffle: ->
    super()
    @_deck = @_deck.map (card)-> new CardParam(card)

  next: -> @_deck[0]

  deal: ->
    cards = super ...arguments
    @emit 'deal'
    return cards
