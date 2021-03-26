assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')
EventEmitter = require('events').EventEmitter


Cards_shuffle = ->
class Cards
  shuffle: ->
    @_deck = [10, 11]
    Cards_shuffle.apply(@, arguments)


CardsId =  proxyquire('../cards', {
  '../poker/cards':
    Cards: Cards
}).CardsId


describe 'CardsId', ->
  o = null
  beforeEach ->
    o = new CardsId
    Cards_shuffle = sinon.spy()

  it 'shuffle', ->
    o.shuffle()
    assert.equal 1, Cards_shuffle.callCount
    assert.deepEqual [{i: 0, card: 10}, {i: 1, card: 11}], o._deck
