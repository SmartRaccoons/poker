assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')


class CardParam
  constructor: (card)->
    @card = card
    @ob = 'cp'

Cards = proxyquire('../cards', {
  './card': {CardParam}
}).CardsParams


describe 'Cards', ->
  o = null
  spy = null
  beforeEach ->
    o = new Cards()
    spy = sinon.spy()

  it 'constructor', ->
    class Cards2 extends Cards
      shuffle: -> spy()
    new Cards2()
    assert.equal 1, spy.callCount

  it 'shuffle', ->
    o.shuffle()
    assert.equal 'cp', o._deck[0].ob

  it 'next', ->
    o._deck[0] = 's'
    assert.equal 's', o.next()

  it 'deal', ->
    o.on 'deal', spy
    assert.equal true, !!o.deal()
    assert.equal 1, spy.callCount
