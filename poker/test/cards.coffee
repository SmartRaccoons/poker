events = require('events')
assert = require('assert')
sinon = require('sinon')


Cards = require('../cards').Cards


describe 'Cards', ->
  cards = null
  beforeEach ->
    cards = new Cards()

  describe 'default', ->
    it 'deck', ->
      assert.equal 52, cards._deck.length
      assert.equal 'Ac', cards._deck[0]
      assert.equal 'As', cards._deck[1]
      assert.equal '2h', cards._deck[50]
      assert.equal '2d', cards._deck[51]
