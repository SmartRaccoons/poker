assert = require('assert')
sinon = require('sinon')


Rank = require('../rank').PokerRank


describe 'Rank', ->
  r = null
  beforeEach ->
    r = new Rank(['Qd'])
    r._matched = undefined

  describe 'default', ->
    it 'constructor', ->
      r = new Rank(['Qd', 'Kd', 'Ac'])
      assert.deepEqual([['A', 'c'], ['K', 'd'], ['Q', 'd']], r._hand)
      assert.equal(false, r._flush)

    it 'flush', ->
      r = new Rank(['Ac', 'Kc', 'Ah', '2c', '3c', 'Jc', 'Tc'])
      assert.deepEqual([ ['A', 'c'], ['K', 'c'], ['J', 'c'], ['T', 'c'], ['3', 'c'], ['2', 'c'] ], r._flush)

    it '_straight', ->
      assert.deepEqual [0], Rank::_straight([ ['A', 's'], ['K', 's'], ['Q', 's'], ['J', 's'], ['T', 's'], ['9', 's'], ['8', 's'], ['7', 's'] ])[0]
      assert.deepEqual [ ['A', 's'], ['K', 's'], ['Q', 's'], ['J', 's'], ['T', 's'] ], Rank::_straight([ ['A', 's'], ['K', 's'], ['Q', 's'], ['J', 's'], ['T', 's'], ['9', 's'], ['8', 's'], ['7', 's'] ])[1]
      assert.deepEqual [8], Rank::_straight([ ['A', 's'], ['Q', 's'], ['9', 's'], ['6', 's'], ['5', 's'], ['4', 's'], ['3', 's'], ['2', 's'] ])[0]
      assert.deepEqual [ ['6', 's'], ['5', 's'], ['4', 's'], ['3', 's'], ['2', 's'] ], Rank::_straight([ ['A', 's'], ['Q', 's'], ['9', 's'], ['6', 's'], ['5', 's'], ['4', 's'], ['3', 's'], ['2', 's'] ])[1]

    it '_straight (middle)', ->
      assert.deepEqual [2], Rank::_straight([ ['A', 's'], ['Q', 's'], ['J', 's'], ['T', 's'], ['9', 's'], ['8', 's'], ['7', 's'] ])[0]
      assert.deepEqual [ ['Q', 's'], ['J', 's'], ['T', 's'], ['9', 's'], ['8', 's'] ], Rank::_straight([ ['A', 's'], ['Q', 's'], ['J', 's'], ['T', 's'], ['9', 's'], ['8', 's'], ['7', 's'] ])[1]

    it '_straight (middle + duplicate)', ->
      assert.deepEqual [2], Rank::_straight([ ['A', 's'], ['Q', 's'], ['Q', 'h'], ['J', 's'], ['T', 's'], ['9', 's'], ['8', 's'], ['7', 's'] ])[0]
      assert.deepEqual [ ['Q', 's'], ['J', 's'], ['T', 's'], ['9', 's'], ['8', 's'] ], Rank::_straight([ ['A', 's'], ['Q', 's'], ['Q', 'h'], ['J', 's'], ['T', 's'], ['9', 's'], ['8', 's'], ['7', 's'] ])[1]

    it '_straight (ace)', ->
      assert.deepEqual [false], Rank::_straight([ ['Q', 's'], ['J', 's'], ['T', 's'], ['5', 's'], ['4', 's'], ['3', 's'], ['2', 's'] ])
      assert.deepEqual [9], Rank::_straight([ ['A', 's'], ['Q', 's'], ['J', 's'], ['T', 's'], ['5', 's'], ['4', 's'], ['3', 's'], ['2', 's'] ])[0]
      assert.deepEqual [ ['A', 's'], ['5', 's'], ['4', 's'], ['3', 's'], ['2', 's'] ], Rank::_straight([ ['A', 's'], ['Q', 's'], ['J', 's'], ['T', 's'], ['5', 's'], ['4', 's'], ['3', 's'], ['2', 's'] ])[1]

    it '_straight (fail)', ->
      assert.deepEqual [false], Rank::_straight([ ['A', 's'], ['Q', 's'], ['J', 's'], ['9', 's'], ['8', 's'], ['7', 's'] ])
      assert.deepEqual [false], Rank::_straight([ ['A', 's'] ])

    it '_match (2 in 3)', ->
      assert.deepEqual [ ['K', 's'], ['J', 's'] ], Rank::_match([ ['K', 'h'], ['K', 'c'], ['K', 's'], ['J', 's'] ], 'K', 2)[0]
      assert.deepEqual [ ['K', 'h'], ['K', 'c'] ], Rank::_match([ ['K', 'h'], ['K', 'c'], ['K', 's'], ['J', 's'] ], 'K', 2)[1]

    it '_match (fail)', ->
      assert.deepEqual([false], Rank::_match([ ['A', 'c'], ['K', 'c'], ['K', 's'], ['J', 's'] ], 'K', 3))

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
        royal_flush: ->
          spy()
          return false
        straight_flush: ->
          spy2()
          @_matched = [['A', 'c'], ['J', 'h']]
          return [0, 1]
        high_card: ->
          spy3()
          return [1, 2]
      r = new Rank2(['Ac', 'Kc'])
      assert.deepEqual([1, 0, 1], r._hand_rank)
      assert.equal('straight_flush', r._hand_message)
      assert.deepEqual(['Ac', 'Jh'], r._hand_matched)
      assert.equal(1, spy.callCount)
      assert.equal(1, spy2.callCount)
      assert.equal(0, spy3.callCount)


  describe 'compare', ->
    it '_compare_hands', ->
      assert.equal(1, Rank::_compare_hands([0, 2], [1, 1]))
      assert.equal(-1, Rank::_compare_hands([1, 1], [0, 2]))
      assert.equal(0, Rank::_compare_hands([1, 1], [1, 1]))
      assert.equal(1, Rank::_compare_hands([1, 1, 1], [1, 1, 2]))
      assert.equal(-1, Rank::_compare_hands([1, 1, 2], [1, 1, 1]))

    it '1 dimension', ->
      assert.deepEqual([ [0], [1] ], Rank::compare( [ [0, 2], [1, 1] ] ))

    it '2 dimension', ->
      assert.deepEqual([ [1], [0] ], Rank::compare( [ [1, 3, 3], [1, 2, 4] ] ))

    it 'no winner', ->
      assert.deepEqual([ [0, 1] ], Rank::compare( [ [1, 3, 2], [1, 3, 2] ] ))

    it 'more hands', ->
      assert.deepEqual([ [1, 2], [0, 3], [4] ], Rank::compare( [ [1, 3, 4], [1, 3, 2], [1, 3, 2], [1, 3, 4], [1, 4] ] ))


  describe 'royal_flush', ->
    it 'success', ->
      r = new Rank(['Ac', 'Kc', 'Ah', 'Qc', 'Jc', 'Tc', '9c'])
      assert.deepEqual([0], r.royal_flush())
      assert.deepEqual([ ['A', 'c'], ['K', 'c'], ['Q', 'c'], ['J', 'c'], ['T', 'c'] ], r._matched)

    it 'failed', ->
      r = new Rank(['Ac', 'Kc', 'Ah', '9c', 'Jc', 'Tc'])
      assert.equal(false, r.royal_flush())


  describe 'straight_flush', ->
    it 'success', ->
      r._flush = [1, 2, 3, 4, 5, 6]
      r._straight = -> [ [1], [2, 3] ]
      sinon.spy(r, '_straight')
      assert.deepEqual([1], r.straight_flush())
      assert.equal(1, r._straight.callCount)
      assert.deepEqual([1, 2, 3, 4, 5, 6], r._straight.getCall(0).args[0])
      assert.deepEqual([2, 3], r._matched)

    it 'no flush', ->
      r._flush = false
      r._straight = sinon.spy()
      assert.equal(0, r._straight.callCount)
      assert.equal(false, r.straight_flush())
      assert.ok !r._matched

    it 'no straight', ->
      r._flush = [1, 2]
      r._straight = -> [false]
      assert.equal(false, r.straight_flush())
      assert.ok !r._matched


  describe 'four_of_a_kind', ->
    beforeEach ->
      r._kicker = sinon.fake.returns [0]

    it 'success', ->
      a = 0
      r._match = ->
        a++
        if a is 1
          return [false]
        [ ['m', 'a'], [1, 2]]
      sinon.spy(r, '_match')
      r._hand = 'hand'
      assert.deepEqual([1, 0], r.four_of_a_kind())
      assert.equal(2, r._match.callCount)
      assert.equal('hand', r._match.getCall(0).args[0])
      assert.equal('A', r._match.getCall(0).args[1])
      assert.equal(4, r._match.getCall(0).args[2])
      assert.equal('K', r._match.getCall(1).args[1])
      assert.equal(1, r._kicker.callCount)
      assert.deepEqual( ['m', 'a'], r._kicker.getCall(0).args[0])
      assert.equal(1, r._kicker.getCall(0).args[1])
      assert.deepEqual([1, 2, 'm'], r._matched)

    it 'not found', ->
      r._match = -> [false]
      sinon.spy(r, '_match')
      assert.deepEqual(false, r.four_of_a_kind())
      assert.equal(13, r._match.callCount)
      assert.equal('2', r._match.getCall(12).args[1])
      assert.ok !r._matched


  describe 'full_house', ->
    it 'success', ->
      a = 0
      r._match = ->
        a++
        if a is 2
          return [ ['m', '1'], [1] ]
        if a is 4
          return [ ['m', '1'], [2] ]
        return [false]
      r._hand = 'hand'
      sinon.spy(r, '_match')
      assert.deepEqual([1, 2], r.full_house())
      assert.equal(4, r._match.callCount)
      assert.equal('hand', r._match.getCall(0).args[0])
      assert.equal('A', r._match.getCall(0).args[1])
      assert.equal(3, r._match.getCall(0).args[2])
      assert.equal('K', r._match.getCall(1).args[1])
      assert.deepEqual( ['m', '1'], r._match.getCall(2).args[0])
      assert.equal('A', r._match.getCall(2).args[1])
      assert.equal(2, r._match.getCall(2).args[2])
      assert.equal('Q', r._match.getCall(3).args[1])
      assert.deepEqual([1, 2], r._matched)

    it 'only 3', ->
      a = 0
      r._match = ->
        a++
        if a is 1
          return [ ['m', '1'], [1, 2]]
        return [false]
      sinon.spy(r, '_match')
      r._ranks = 'ranks'
      assert.equal(false, r.full_house())
      assert.equal(true, r._match.callCount > 14)


  describe 'flush', ->
    it 'success', ->
      r._kicker = -> 'kicker'
      sinon.spy(r, '_kicker')
      r._flush = [1, 2, 3, 4, 5, 6]
      assert.equal('kicker', r.flush())
      assert.equal(1, r._kicker.callCount)
      assert.deepEqual([1, 2, 3, 4, 5, 6], r._kicker.getCall(0).args[0])
      assert.equal(5, r._kicker.getCall(0).args[1])
      assert.deepEqual([1, 2, 3, 4, 5], r._matched)

    it 'no flush', ->
      r._flush = false
      assert.equal(false, r.flush())
      assert.ok !r._matched


  describe 'straight', ->
    it 'success', ->
      r._hand = 'hand'
      r._straight = -> [ 'str', [1, 2] ]
      sinon.spy(r, '_straight')
      assert.equal('str', r.straight())
      assert.equal(1, r._straight.callCount)
      assert.equal('hand', r._straight.getCall(0).args[0])
      assert.deepEqual [1, 2], r._matched

    it 'fail', ->
      r._straigh = -> [false]
      assert.equal(false, r.straight())
      assert.ok !r._matched


  describe 'three_of_a_kind', ->
    it 'success', ->
      r._hand = 'hand'
      a = 0
      r._match = ->
        a++
        if a is 2
          return [ ['m', 'a', 't', 'c'], [1, 2] ]
        return [false]
      sinon.spy(r, '_match')
      r._kicker = -> [2, 3]
      sinon.spy(r, '_kicker')
      assert.deepEqual([1, 2, 3], r.three_of_a_kind())
      assert.equal(2, r._match.callCount)
      assert.equal('hand', r._match.getCall(0).args[0])
      assert.equal('A', r._match.getCall(0).args[1])
      assert.equal(3, r._match.getCall(0).args[2])
      assert.equal('K', r._match.getCall(1).args[1])
      assert.equal(1, r._kicker.callCount)
      assert.deepEqual(['m', 'a', 't', 'c'], r._kicker.getCall(0).args[0])
      assert.equal(2, r._kicker.getCall(0).args[1])
      assert.deepEqual [1, 2, 'm', 'a'], r._matched

    it 'fail', ->
      r._match = -> [false]
      assert.equal(false, r.three_of_a_kind())
      assert.ok !r._matched


  describe 'two_pair', ->
    it 'success', ->
      r._hand = 'hand'
      a = 0
      r._match = ->
        a++
        if a is 2
          return [ ['m'], [1, 2] ]
        if a is 4
          return [ ['m', '2', '3'], [3, 4] ]
        return [false]
      sinon.spy(r, '_match')
      r._kicker = -> [4]
      sinon.spy(r, '_kicker')
      assert.deepEqual([1, 3, 4], r.two_pair())
      assert.equal(4, r._match.callCount)
      assert.equal('hand', r._match.getCall(0).args[0])
      assert.equal('A', r._match.getCall(0).args[1])
      assert.equal(2, r._match.getCall(0).args[2])
      assert.equal('K', r._match.getCall(1).args[1])
      assert.deepEqual(['m'], r._match.getCall(2).args[0])
      assert.equal('Q', r._match.getCall(2).args[1])
      assert.equal(2, r._match.getCall(2).args[2])
      assert.equal('J', r._match.getCall(3).args[1])
      assert.equal(1, r._kicker.callCount)
      assert.deepEqual(['m', '2', '3'], r._kicker.getCall(0).args[0])
      assert.equal(1, r._kicker.getCall(0).args[1])
      assert.deepEqual [1, 2, 3, 4, 'm'], r._matched

    it 'no second pair', ->
      r._ranks = 'ranks'
      a = 0
      r._match = ->
        a++
        if a is 2
          return [['m'], [1, 2]]
        return [false]
      sinon.spy(r, '_match')
      assert.equal(false, r.two_pair())
      assert.equal(true, r._match.callCount > 14)
      assert.ok !r._matched


  describe 'one_pair', ->
    it 'success', ->
      r._hand = 'hand'
      a = 0
      r._match = ->
        a++
        if a is 2
          return [ ['m', '2', '3', '4'], [1, 2] ]
        return [false]
      sinon.spy(r, '_match')
      r._kicker = -> [2, 3]
      sinon.spy(r, '_kicker')
      assert.deepEqual([1, 2, 3], r.one_pair())
      assert.equal(2, r._match.callCount)
      assert.equal('hand', r._match.getCall(0).args[0])
      assert.equal('A', r._match.getCall(0).args[1])
      assert.equal(2, r._match.getCall(0).args[2])
      assert.equal('K', r._match.getCall(1).args[1])
      assert.equal(1, r._kicker.callCount)
      assert.deepEqual([ 'm', '2', '3', '4' ], r._kicker.getCall(0).args[0])
      assert.equal(3, r._kicker.getCall(0).args[1])
      assert.deepEqual [1, 2, 'm', '2', '3'], r._matched

    it 'fail', ->
      r._match = -> [false]
      assert.equal(false, r.one_pair())
      assert.ok !r._matched


  describe 'high_card', ->
    it 'success', ->
      r._hand = ['h', 'a', 'n', 'd', '1', '2']
      r._kicker = -> 'kicker'
      sinon.spy(r, '_kicker')
      assert.equal('kicker', r.high_card())
      assert.equal(1, r._kicker.callCount)
      assert.deepEqual(['h', 'a', 'n', 'd', '1', '2'], r._kicker.getCall(0).args[0])
      assert.equal(5, r._kicker.getCall(0).args[1])
      assert.deepEqual ['h', 'a', 'n', 'd', '1'], r._matched
