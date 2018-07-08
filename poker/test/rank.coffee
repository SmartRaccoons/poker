assert = require('assert')
sinon = require('sinon')


Rank = require('../rank').Rank


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

    it 'ranks', ->
      r = new Rank(['Ac', 'Kc', 'Ah', '2c', '3c', 'Jc', 'Tc'])
      assert.deepEqual(['A', 'A', 'K', 'J', 'T', '3', '2'], r._ranks)

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
      assert.deepEqual([3, 11], Rank::_kicker(['J', '3'], 5))

    it 'go over combinations', ->
      spy = sinon.spy()
      spy2 = sinon.spy()
      spy3 = sinon.spy()
      class Rank2 extends Rank
      Rank2::royal_flush = ->
        spy()
        return false
      Rank2::straight_flush = ->
        spy2()
        return [0, 1]
      Rank2::high_card = ->
        spy3()
        return [1, 2]
      r = new Rank2(['Ac', 'Kc'])
      assert.deepEqual([1, 0, 1], r._hand_rank)
      assert.equal('straight_flush', r._hand_message)
      assert.equal(1, spy.callCount)
      assert.equal(1, spy2.callCount)
      assert.equal(0, spy3.callCount)


  describe 'compare', ->
    it '1 dimension', ->
      assert.deepEqual([0], Rank::compare([0, 2], [1, 1]))

    it '2 dimension', ->
      assert.deepEqual([1], Rank::compare([1, 3, 3], [1, 2, 4]))

    it 'no winner', ->
      assert.deepEqual([0, 1], Rank::compare([1, 3, 2], [1, 3, 2]))

    it 'more hands', ->
      assert.deepEqual([1, 2], Rank::compare([1, 3, 4], [1, 3, 2], [1, 3, 2]))


  describe 'royal_flush', ->
    it 'success', ->
      r = new Rank(['Ac', 'Kc', 'Ah', 'Qc', 'Jc', 'Tc'])
      assert.deepEqual([0], r.royal_flush())

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
    beforeEach ->
      r._kicker = -> [0]
      sinon.spy(r, '_kicker')

    it 'success', ->
      a = 0
      r._match = ->
        a++
        if a is 1
          return false
        'match'
      sinon.spy(r, '_match')
      r._ranks = 'ranks'
      assert.deepEqual([1, 0], r.four_of_a_kind())
      assert.equal(2, r._match.callCount)
      assert.equal('ranks', r._match.getCall(0).args[0])
      assert.equal('A', r._match.getCall(0).args[1])
      assert.equal(4, r._match.getCall(0).args[2])
      assert.equal('K', r._match.getCall(1).args[1])
      assert.equal(1, r._kicker.callCount)
      assert.equal('match', r._kicker.getCall(0).args[0])
      assert.equal(1, r._kicker.getCall(0).args[1])

    it 'not found', ->
      r._match = -> false
      sinon.spy(r, '_match')
      assert.deepEqual(false, r.four_of_a_kind())
      assert.equal(13, r._match.callCount)
      assert.equal('2', r._match.getCall(12).args[1])


  describe 'full_house', ->
    it 'success', ->
      a = 0
      r._match = ->
        a++
        if a is 2
          return 'm1'
        if a is 4
          return 'm2'
        return false
      sinon.spy(r, '_match')
      r._ranks = 'ranks'
      assert.deepEqual([1, 2], r.full_house())
      assert.equal(4, r._match.callCount)
      assert.equal('ranks', r._match.getCall(0).args[0])
      assert.equal('A', r._match.getCall(0).args[1])
      assert.equal(3, r._match.getCall(0).args[2])
      assert.equal('K', r._match.getCall(1).args[1])
      assert.equal('m1', r._match.getCall(2).args[0])
      assert.equal('A', r._match.getCall(2).args[1])
      assert.equal(2, r._match.getCall(2).args[2])
      assert.equal('Q', r._match.getCall(3).args[1])

    it 'only 3', ->
      a = 0
      r._match = ->
        a++
        if a is 1
          return 'm1'
        return false
      sinon.spy(r, '_match')
      r._ranks = 'ranks'
      assert.equal(false, r.full_house())
      assert.equal(true, r._match.callCount > 14)


  describe 'flush', ->
    it 'success', ->
      r._kicker = -> 'kicker'
      sinon.spy(r, '_kicker')
      r._flush = [1, 2]
      assert.equal('kicker', r.flush())
      assert.equal(1, r._kicker.callCount)
      assert.deepEqual([1, 2], r._kicker.getCall(0).args[0])
      assert.equal(5, r._kicker.getCall(0).args[1])

    it 'no flush', ->
      r._flush = false
      assert.equal(false, r.flush())

  describe 'straight', ->
    it 'success', ->
      r._ranks = 'ranks'
      r._straight = -> 'str'
      sinon.spy(r, '_straight')
      assert.equal('str', r.straight())
      assert.equal(1, r._straight.callCount)
      assert.equal('ranks', r._straight.getCall(0).args[0])

    it 'fail', ->
      r._straigh = -> false
      assert.equal(false, r.straight())


  describe 'three_of_kind', ->
    it 'success', ->
      r._ranks = 'ranks'
      a = 0
      r._match = ->
        a++
        if a is 2
          return 'm'
        return false
      sinon.spy(r, '_match')
      r._kicker = -> [2, 3]
      sinon.spy(r, '_kicker')
      assert.deepEqual([1, 2, 3], r.three_of_kind())
      assert.equal(2, r._match.callCount)
      assert.equal('ranks', r._match.getCall(0).args[0])
      assert.equal('A', r._match.getCall(0).args[1])
      assert.equal(3, r._match.getCall(0).args[2])
      assert.equal('K', r._match.getCall(1).args[1])
      assert.equal(1, r._kicker.callCount)
      assert.equal('m', r._kicker.getCall(0).args[0])
      assert.equal(2, r._kicker.getCall(0).args[1])

    it 'fail', ->
      r._match = -> false
      assert.equal(false, r.three_of_kind())


  describe 'two_pair', ->
    it 'success', ->
      r._ranks = 'ranks'
      a = 0
      r._match = ->
        a++
        if a is 2
          return 'm'
        if a is 4
          return 'm2'
        return false
      sinon.spy(r, '_match')
      r._kicker = -> [4]
      sinon.spy(r, '_kicker')
      assert.deepEqual([1, 3, 4], r.two_pair())
      assert.equal(4, r._match.callCount)
      assert.equal('ranks', r._match.getCall(0).args[0])
      assert.equal('A', r._match.getCall(0).args[1])
      assert.equal(2, r._match.getCall(0).args[2])
      assert.equal('K', r._match.getCall(1).args[1])
      assert.equal('m', r._match.getCall(2).args[0])
      assert.equal('Q', r._match.getCall(2).args[1])
      assert.equal(2, r._match.getCall(2).args[2])
      assert.equal('J', r._match.getCall(3).args[1])
      assert.equal(1, r._kicker.callCount)
      assert.equal('m2', r._kicker.getCall(0).args[0])
      assert.equal(1, r._kicker.getCall(0).args[1])

  it 'no second pair', ->
    r._ranks = 'ranks'
    a = 0
    r._match = ->
      a++
      if a is 2
        return 'm'
      return false
    sinon.spy(r, '_match')
    assert.equal(false, r.two_pair())
    assert.equal(true, r._match.callCount > 14)


  describe 'one_pair', ->
    it 'success', ->
      r._ranks = 'ranks'
      a = 0
      r._match = ->
        a++
        if a is 2
          return 'm'
        return false
      sinon.spy(r, '_match')
      r._kicker = -> [2, 3]
      sinon.spy(r, '_kicker')
      assert.deepEqual([1, 2, 3], r.one_pair())
      assert.equal(2, r._match.callCount)
      assert.equal('ranks', r._match.getCall(0).args[0])
      assert.equal('A', r._match.getCall(0).args[1])
      assert.equal(2, r._match.getCall(0).args[2])
      assert.equal('K', r._match.getCall(1).args[1])
      assert.equal(1, r._kicker.callCount)
      assert.equal('m', r._kicker.getCall(0).args[0])
      assert.equal(3, r._kicker.getCall(0).args[1])

    it 'fail', ->
      r._match = -> false
      assert.equal(false, r.one_pair())


  describe 'high_card', ->

    it 'success', ->
      r._ranks = 'ranks'
      r._kicker = -> 'kicker'
      sinon.spy(r, '_kicker')
      assert.equal('kicker', r.high_card())
      assert.equal(1, r._kicker.callCount)
      assert.equal('ranks', r._kicker.getCall(0).args[0])
      assert.equal(5, r._kicker.getCall(0).args[1])
