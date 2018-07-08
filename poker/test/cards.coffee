assert = require('assert')
sinon = require('sinon')


Cards = require('../cards').Cards


describe 'Cards', ->
  cards = null
  beforeEach ->
    cards = new Cards()

  describe 'default', ->

    it 'shuffle', ->
      cards.shuffle()
      assert.equal 52, cards._deck.length
      assert.equal 0, cards._deck.filter( (item, pos)-> cards._deck.indexOf(item) isnt pos ).length
      assert.equal 1, cards._deck.filter( (item)-> item is 'Ac' ).length

    it 'pop', ->
      cards.shuffle()
      assert.equal(2, cards.pop().length)
      assert.equal 51, cards._deck.length
