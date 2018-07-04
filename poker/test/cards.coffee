events = require('events')
assert = require('assert')
sinon = require('sinon')


Cards = require('../cards').Cards
Rank = require('../cards').Rank


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


describe 'Rank', ->
  r = null
  beforeEach ->
    r = new Rank(['Qd'])

  describe 'default', ->
    it 'constructor', ->
      r = new Rank(['Qd', 'Kd', 'Ac'])
      assert.deepEqual([['A', 'c'], ['K', 'd'], ['Q', 'd']], r._hand)
      assert.equal(false, r._flush)

    it 'flush', ->
      r = new Rank(['Ac', 'Kc', 'Ah', '2c', '3c', 'Jc', 'Tc'])
      assert.deepEqual(['A', 'K', 'J', 'T', '3', '2'], r._flush)

    it '_straight', ->
      assert.deepEqual([0], Rank::_straight(['A', 'K', 'Q', 'J', 'T', '9', '8', '7']))

    it '_straight (middle)', ->
      assert.deepEqual([2], Rank::_straight(['A', 'Q', 'J', 'T', '9', '8', '7']))

    it '_straight (middle + duplicate)', ->
      assert.deepEqual([2], Rank::_straight(['A', 'Q', 'Q', 'J', 'T', '9', '8', '7']))

    it '_straight (ace)', ->
      assert.equal(false, Rank::_straight(['Q', 'J', 'T', '5', '4', '3', '2']))
      assert.deepEqual([9], Rank::_straight(['A', 'Q', 'J', '5', '4', '3', '2']))
      assert.equal(false, Rank::_straight(['K', 'Q', 'J', '5', '4', '3', '2']))

    it '_straight (fail)', ->
      assert.equal(false, Rank::_straight(['A', 'Q', 'J', '9', '8', '7']))

    it '_match', ->
      assert.deepEqual(['A', 'J'], Rank::_match(['A', 'K', 'K', 'J'], 'K', 2))

    it '_match (fail)', ->
      assert.equal(false, Rank::_match(['A', 'K', 'K', 'J'], 'K', 3))

    it '_kicker', ->
      assert.deepEqual([0, 1], Rank::_kicker(['A', 'K', 'J'], 2))
      assert.deepEqual([0], Rank::_kicker(['A', 'K', 'J'], 1))
      assert.deepEqual([3, 11], Rank::_kicker(['J', '3', '2'], 2))


  describe 'royal_flush', ->
    it 'success', ->
      r = new Rank(['Ac', 'Kc', 'Ah', 'Qc', 'Jc', 'Tc'])
      assert.equal(true, r.royal_flush())

    it 'failed', ->
      r = new Rank(['Ac', 'Kc', 'Ah', '9c', 'Jc', 'Tc'])
      assert.equal(false, r.royal_flush())

  describe 'straight_flush', ->
    it 'success', ->
      r._flush = [1, 2]
      r._straight = -> [1]
      sinon.spy(r, '_straight')
      assert.deepEqual([1], r.straight_flush())
      assert.equal(1, r._straight.callCount)
      assert.deepEqual([1, 2], r._straight.getCall(0).args[0])

    it 'no flush', ->
      r._flush = false
      r._straigh = -> [1]
      assert.equal(false, r.straight_flush())

    it 'no straight', ->
      r._flush = [1, 2]
      r._straight = -> false
      assert.equal(false, r.straight_flush())

  describe 'four_of_a_kind', ->
