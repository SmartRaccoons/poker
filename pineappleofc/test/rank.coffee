assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')
EventEmitter = require('events').EventEmitter


PokerRank_constructor = ->
PokerRank_rank = (cards)-> 'rank' + cards
PokerRank__compare_hands = -> true
class PokerRank
  constructor: (cards)->
    @_hand_rank = PokerRank_rank( cards )
    @_hand_message = 'mes' + cards
    PokerRank_constructor.apply(@, arguments)

  _compare_hands: -> PokerRank__compare_hands.apply(@, arguments)


PokerOFCRank =  proxyquire('../rank', {
  '../poker/rank':
    PokerRank: PokerRank
}).PokerOFCRank


describe 'PokerOFCRank', ->
  o = null
  spy = null
  beforeEach ->
    PokerRank_constructor = sinon.spy()
    spy = sinon.spy()


  describe 'calculate', ->
    fn = null
    hand = null
    beforeEach ->
      PokerRank_constructor = sinon.spy()
      fn = PokerOFCRank::calculate
      hand = [
        ['As', 'Ah', 'Kh']
        ['Ad', 'Ac', 'Ks', 'Kd', 'Kc']
        ['2d', '2c', '2s', '2h', 'Tc']
      ]

    it 'default', ->
      result = fn(hand)
      assert.deepEqual hand[0], PokerRank_constructor.getCall(0).args[0]
      assert.equal 0, result.lines[0].royalties

    it 'filled', ->
      assert.equal true, fn(hand).filled
      assert.equal false, fn( [ hand[0].slice(1), hand[1], hand[2] ] ).filled
      assert.equal false, fn( [ hand[0], hand[1].slice(1), hand[2] ] ).filled
      assert.equal false, fn( [ hand[0], hand[1], hand[2].slice(1) ] ).filled


    describe 'lines', ->
      spy_royalty = null
      spy_royalty_prev = null
      royalties_line = null
      beforeEach ->
        royalties_line = [2, 2, 2]
        spy_royalty_prev = PokerOFCRank::_calculate_royalty
        PokerOFCRank::_calculate_royalty = spy_royalty = sinon.fake (line)-> royalties_line[line]

      afterEach ->
        PokerOFCRank::_calculate_royalty = spy_royalty_prev

      it 'royalties', ->
        result = fn(['l12', 'l2345', 'l3456'])
        assert.equal 2, result.lines[0].royalties
        assert.equal 3, spy_royalty.callCount
        assert.equal 0, spy_royalty.getCall(0).args[0]
        assert.equal 'rankl12', spy_royalty.getCall(0).args[1]
        assert.equal 1, spy_royalty.getCall(1).args[0]
        assert.equal 'rankl2345', spy_royalty.getCall(1).args[1]

      it 'royalties (total)', ->
        assert.equal 6, fn(['l12', 'l2345', 'l3456']).royalties
        assert.equal 2, fn(['l12', 'l234', 'l345']).royalties
        assert.equal 0, fn(['l1', 'l234', 'l345']).royalties

      it 'rank', ->
        result = fn(['l12', 'l2345', 'l3456'])
        assert.equal 'rankl12', result.lines[0].rank
        assert.equal 'rankl2345', result.lines[1].rank
        assert.equal 'rankl3456', result.lines[2].rank

      it 'message', ->
        result = fn(['l12', 'l2345', 'l3456'])
        assert.equal 'mesl12', result.lines[0].message
        assert.equal 'mesl2345', result.lines[1].message
        assert.equal 'mesl3456', result.lines[2].message

      it 'not enought cards', ->
        assert.deepEqual [null, null, null], fn(['l1', 'l234', 'l345']).lines


      describe 'fantasyland', ->
        it 'first time queens', ->
          royalties_line[0] = 7
          assert.equal true, fn(['l12', 'l2345', 'l3456']).fantasyland

        it 'first time jacks', ->
          royalties_line[0] = 6
          assert.equal false, fn(['l12', 'l2345', 'l3456']).fantasyland

        it 'second time aces', ->
          royalties_line[0] = 9
          assert.equal false, fn(['l12', 'l2345', 'l3456'], true).fantasyland

        it 'second time three of a kind', ->
          royalties_line[0] = 10
          assert.equal true, fn(['l12', 'l2345', 'l3456'], true).fantasyland

        it 'middle fullhouse', ->
          royalties_line[1] = 12
          assert.equal true, fn(['l12', 'l2345', 'l3456'], true).fantasyland
          assert.equal false, fn(['l12', 'l2345', 'l3456']).fantasyland
          royalties_line[1] = 8
          assert.equal false, fn(['l12', 'l2345', 'l3456'], true).fantasyland

        it 'bottom four of a kind', ->
          royalties_line[2] = 10
          assert.equal true, fn(['l12', 'l2345', 'l3456'], true).fantasyland
          assert.equal false, fn(['l12', 'l2345', 'l3456']).fantasyland
          royalties_line[2] = 8
          assert.equal false, fn(['l12', 'l2345', 'l3456'], true).fantasyland

        it 'invalid hand', ->
          PokerRank__compare_hands = -> -1
          royalties_line[0] = 10
          assert.equal false, fn(['l12', 'l2345', 'l3456']).fantasyland
          assert.equal false, fn(['l12', 'l2345', 'l3456'], true).fantasyland


    describe 'valid', ->
      ranks = null
      beforeEach ->
        ranks = [0, 0]
        PokerRank__compare_hands = sinon.fake -> ranks.pop()

      it 'default', ->
        assert.equal true, fn(['l12', 'l2345', 'l3456']).valid
        assert.equal 2, PokerRank__compare_hands.callCount
        assert.equal 'rankl3456', PokerRank__compare_hands.getCall(0).args[0]
        assert.equal 'rankl2345', PokerRank__compare_hands.getCall(0).args[1]
        assert.equal 'rankl2345', PokerRank__compare_hands.getCall(1).args[0]
        assert.equal 'rankl12', PokerRank__compare_hands.getCall(1).args[1]

      it 'error bottom line', ->
        ranks = [-1, 0]
        assert.equal false, fn(['l12', 'l2345', 'l3456']).valid

      it 'error middle line', ->
        ranks = [0, -1]
        assert.equal false, fn(['l12', 'l2345', 'l3456']).valid

      it 'rank empty', ->
        hand[0].splice(1, 1)
        assert.equal true, fn(hand).valid
        assert.equal 0, PokerRank__compare_hands.callCount


    describe '_calculate_royalty', ->
      fn = null
      beforeEach ->
        fn = PokerOFCRank::_calculate_royalty

      it 'line 1', ->
        assert.equal 22, fn(0, [6, 0])
        assert.equal 10, fn(0, [6, 12])
        assert.equal 9, fn(0, [8, 0])
        assert.equal 1, fn(0, [8, 8])
        assert.equal 0, fn(0, [8, 9])
        assert.equal 0, fn(0, [8, 12])

      it 'line 2', ->
        assert.equal 50, fn(1, [0])
        assert.equal 2, fn(1, [6])
        assert.equal 0, fn(1, [7])

      it 'line 3', ->
        assert.equal 25, fn(2, [0])
        assert.equal 15, fn(2, [1])
        assert.equal 10, fn(2, [2])
        assert.equal 6, fn(2, [3])
        assert.equal 4, fn(2, [4])
        assert.equal 2, fn(2, [5])
        assert.equal 0, fn(2, [6])


  describe 'compare', ->
    fn = null
    hands = null
    ranks = null
    beforeEach ->
      fn = PokerOFCRank::compare
      ranks = [
        0, 0, 0
        0, 0, 0
        0, 0, 0
      ]
      PokerRank__compare_hands = sinon.fake -> ranks.shift()
      hands = [
        {lines: [
          {rank: 'r1l1'}
          {rank: 'r1l2'}
          {rank: 'r1l3'}
        ], royalties: 10, valid: true}
        {lines: [
          {rank: 'r2l1'}
          {rank: 'r2l2'}
          {rank: 'r2l3'}
        ], royalties: 10, valid: true}
        {lines: [
          {rank: 'r3l1'}
          {rank: 'r3l2'}
          {rank: 'r3l3'}
        ], royalties: 10, valid: true}
      ]

    it 'equal', ->
      result = fn(hands)
      assert.equal 0, result[0].points_change
      assert.equal 0, result[0].lines[0].points_change
      assert.equal 0, result[0].lines[1].points_change
      assert.equal 0, result[0].lines[2].points_change
      assert.equal 0, result[1].points_change
      assert.equal 0, result[2].points_change
      assert.equal 9, PokerRank__compare_hands.callCount
      assert.equal 'r1l1', PokerRank__compare_hands.getCall(0).args[0]
      assert.equal 'r2l1', PokerRank__compare_hands.getCall(0).args[1]
      assert.equal 'r1l2', PokerRank__compare_hands.getCall(1).args[0]
      assert.equal 'r2l2', PokerRank__compare_hands.getCall(1).args[1]
      assert.equal 'r1l3', PokerRank__compare_hands.getCall(2).args[0]
      assert.equal 'r2l3', PokerRank__compare_hands.getCall(2).args[1]
      assert.equal 'r1l1', PokerRank__compare_hands.getCall(3).args[0]
      assert.equal 'r3l1', PokerRank__compare_hands.getCall(3).args[1]

    it 'win first', ->
      ranks = [
        1, -1, 1
        0, 0, 0
        0, 0, 0
      ]
      result = fn(hands)
      assert.equal 1, result[0].points_change
      assert.equal 1, result[0].lines[0].points_change
      assert.equal -1, result[0].lines[1].points_change
      assert.equal 1, result[0].lines[2].points_change
      assert.equal -1, result[1].points_change
      assert.equal -1, result[1].lines[0].points_change
      assert.equal 1, result[1].lines[1].points_change
      assert.equal -1, result[1].lines[2].points_change

    it 'win middle', ->
      ranks = [
        -1, -1, 1
        -1, -1, 1
        1, 1, -1
      ]
      result = fn(hands)
      assert.equal -2, result[0].points_change
      assert.equal -2, result[0].lines[0].points_change
      assert.equal -2, result[0].lines[1].points_change
      assert.equal 2, result[0].lines[2].points_change
      assert.equal 2, result[1].points_change
      assert.equal 2, result[1].lines[0].points_change
      assert.equal 2, result[1].lines[1].points_change
      assert.equal -2, result[1].lines[2].points_change
      assert.equal 0, result[2].points_change
      assert.equal 0, result[2].lines[0].points_change
      assert.equal 0, result[2].lines[1].points_change
      assert.equal 0, result[2].lines[2].points_change

    it 'invalid hand', ->
      ranks = [
        1, 1, 1
        1, 1, 1
        1, 1, 1
      ]

      hands[0].valid = false
      hands[2].valid = false
      result = fn(hands)

      assert.equal -6, result[0].points_change
      assert.equal -2, result[0].lines[0].points_change
      assert.equal -2, result[0].lines[1].points_change
      assert.equal -2, result[0].lines[2].points_change
      assert.equal 12, result[1].points_change
      assert.equal 4, result[1].lines[0].points_change
      assert.equal 4, result[1].lines[1].points_change
      assert.equal 4, result[1].lines[2].points_change
      assert.equal -6, result[2].points_change
      assert.equal -2, result[2].lines[0].points_change
      assert.equal -2, result[2].lines[1].points_change
      assert.equal -2, result[2].lines[2].points_change

    it 'scoop', ->
      ranks = [
        -1, -1, -1
        -1, -1, 1
        1, 1, 1
      ]
      result = fn(hands)
      assert.equal -7, result[0].points_change
      assert.equal -3, result[0].lines[0].points_change
      assert.equal -3, result[0].lines[1].points_change
      assert.equal -1, result[0].lines[2].points_change
      assert.equal 12, result[1].points_change
      assert.equal 4, result[1].lines[0].points_change
      assert.equal 4, result[1].lines[1].points_change
      assert.equal 4, result[1].lines[2].points_change
      assert.equal -5, result[2].points_change
      assert.equal -1, result[2].lines[0].points_change
      assert.equal -1, result[2].lines[1].points_change
      assert.equal -3, result[2].lines[2].points_change

    it 'royalties', ->
      hands[0].royalties = 5
      hands[1].royalties = 9
      hands[2].royalties = 15
      result = fn(hands)
      assert.equal -14, result[0].points_change
      assert.equal -2, result[1].points_change
      assert.equal 16, result[2].points_change

    it '2 hands', ->
      ranks = [
        1, 1, -1
      ]
      result = fn([ hands[0], hands[1] ])
      assert.equal 1, result[0].points_change
      assert.equal -1, result[1].points_change
      assert.equal 3, PokerRank__compare_hands.callCount
