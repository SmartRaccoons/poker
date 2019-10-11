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

    it 'deal', ->
      cards.shuffle()
      dealt = cards.deal(3)
      assert.equal(3, dealt.length)
      assert.equal(2, dealt[0].length)
      assert.equal 49, cards._deck.length

    it 'deal (default)', ->
      cards.shuffle()
      dealt = cards.deal()
      assert.equal(1, dealt.length)
