assert = require('assert')
sinon = require('sinon')

Board = require('../poker.board').PokerBoard


describe 'Board', ->
  b = null
  spy = null
  beforeEach ->
    spy = sinon.spy()
    b = new Board({show_first: 2})

  describe 'default', ->
    it 'constructor', ->
      assert.deepEqual([], b.options.cards)
      assert.deepEqual([], b.options.pot)
      assert.equal(0, b.options.bet_max)
      assert.equal(-1, b.options.bet_raise_position)
      assert.equal(0, b.options.bet_raise_count)

    it 'round', ->
      b.options_update = sinon.spy()
      b.round({show_first: 'f', bet_raise_default: 2})
      assert.equal(1, b.options_update.callCount)
      assert.equal('f', b.options_update.getCall(0).args[0].show_first)
      assert.equal(2, b.options_update.getCall(0).args[0].bet_raise)
      assert.equal(-1, b.options_update.getCall(0).args[0].bet_raise_position)
      assert.equal(0, b.options_update.getCall(0).args[0].bet_raise_count)

    it 'bet_max', ->
      b.options.bet_max = 5
      assert.equal(5, b.bet_max())

    it 'bet_raise', ->
      b.options.bet_raise = 3
      assert.equal(3, b.bet_raise())

    it 'bet_raise_count', ->
      b.options.bet_raise_count = 4
      assert.equal(4, b.bet_raise_count())

    it '_bet_raise_calc', ->
      b.options.bet_raise_default = 3
      assert.equal 6, b._bet_raise_calc(5)
      assert.equal 9, b._bet_raise_calc(7)

    it 'progress', ->
      b.options_update = sinon.spy()
      b.options.bet_raise_position = 2
      b.options.bet_raise_count = 3
      b.options.bet_raise = 3
      b.options.bet_raise_default = 4
      b.options.bet_max = 6
      b.options.cards = [3, 4]
      b.progress({cards: [1, 2]})
      assert.equal(1, b.options_update.callCount)
      assert.deepEqual({cards: [3, 4, 1, 2], bet_max: 0, bet_raise: 4, bet_raise_position: -1, bet_raise_count: 0}, b.options_update.getCall(0).args[0])

    it 'pot_total', ->
      b.options.pot = [{pot: 20}, {pot: 10}]
      assert.equal 30, b.pot_total()

    it 'toJSON', ->
      b.options.cards = 'c'
      b.options.pot = 'p'
      assert.deepEqual({cards: 'c', pot: 'p'}, b.toJSON())


  describe 'bet', ->
    beforeEach ->
      b.options_update = sinon.spy()
      b.options.bet_max = 10
      b.options.bet_raise_default = 3
      b.options.bet_raise = 1
      b.options.bet_raise_count = 1
      b._bet_raise_calc = sinon.fake.returns 5

    it 'same', ->
      b.bet({bet: 9})
      b.bet({bet: 10})
      assert.equal(0, b.options_update.callCount)

    it 'small', ->
      b.bet({bet: 11, position: 2})
      assert.equal(1, b.options_update.callCount)
      assert.deepEqual({bet_max: 11, bet_raise_position: 2, bet_raise_count: 2}, b.options_update.getCall(0).args[0])

    it 'raise up', ->
      b.bet({bet: 12, position: 2})
      assert.equal(1, b.options_update.callCount)
      assert.deepEqual({bet_max: 12, bet_raise_position: 2, bet_raise_count: 2, bet_raise: 5}, b.options_update.getCall(0).args[0])
      assert.equal 1, b._bet_raise_calc.callCount
      assert.equal 2, b._bet_raise_calc.getCall(0).args[0]

    it 'command blind', ->
      b.bet({bet: 11, position: 2, command: 'blind'})
      assert.equal false, Object.keys(b.options_update.getCall(0).args[0]).indexOf('bet_raise_count') >= 0


  describe 'pot', ->
    spy2 = null
    spy3 = null
    beforeEach ->
      spy2 = sinon.spy()
      b.options_update = spy = sinon.spy()
      spy3 = sinon.spy()
      b.on 'pot:update', spy3

    it 'equal', ->
      b.pot([{bet: 10, position: 0}, {bet: 10, position: 1}])
      assert.equal(1, spy.callCount)
      assert.deepEqual([ { pot: 20, positions: [0, 1], contributors: [ {position: 0, bet: 10}, {position: 1, bet: 10} ] } ], spy.getCall(0).args[0].pot)
      assert.equal(1, spy3.callCount)
      assert.deepEqual([ { pot: 20, positions: [0, 1], contributors: [ {position: 0, bet: 10}, {position: 1, bet: 10} ] } ], spy3.getCall(0).args[0])

    it 'silent', ->
      b.pot([{bet: 10, position: 0}, {bet: 10, position: 1}], true)
      assert.equal(0, spy3.callCount)

    it 'negative progression', ->
      b.pot([{bet: 20, position: 0}, {bet: 20, position: 1}, {bet: 10, position: 2}, {bet: 10, position: 3}])
      pot = spy.getCall(0).args[0].pot
      assert.equal(2, pot.length)
      assert.deepEqual([0, 1, 2, 3], pot[0].positions)
      assert.equal(40, pot[0].pot)
      assert.deepEqual([0, 1], pot[1].positions)
      assert.equal(20, pot[1].pot)

    it 'zero bets', ->
      b.pot([{bet: 0, position: 0}, {bet: 10, position: 1}, {bet: 10, position: 2}])
      pot = spy.getCall(0).args[0].pot
      assert.equal(1, pot.length)
      assert.deepEqual([1, 2], pot[0].positions)
      assert.equal(20, pot[0].pot)

    it 'middle big', ->
      b.pot([{bet: 10, position: 0}, {bet: 20, position: 1}, {bet: 10, position: 2}, {bet: 20, position: 3}])
      pot = spy.getCall(0).args[0].pot
      assert.equal(2, pot.length)
      assert.deepEqual([0, 1, 2, 3], pot[0].positions)
      assert.equal(40, pot[0].pot)
      assert.deepEqual([1, 3], pot[1].positions)
      assert.equal(20, pot[1].pot)

    it 'first 2 big', ->
      b.pot([{bet: 20, position: 0}, {bet: 20, position: 1}, {bet: 10, position: 2}])
      pot = spy.getCall(0).args[0].pot
      assert.equal(2, pot.length)
      assert.deepEqual([0, 1, 2], pot[0].positions)
      assert.equal(30, pot[0].pot)
      assert.deepEqual([0, 1], pot[1].positions)
      assert.equal(20, pot[1].pot)

    it 'combine', ->
      b.options.pot = [{pot: 20, positions: [0, 1], contributors: [{position: 0, bet: 5}, {position: 1, bet: 5}, {position: 2, bet: 10}] }]
      b.pot([{bet: 5, position: 0}, {bet: 5, position: 1}])
      pot = spy.getCall(0).args[0].pot
      assert.deepEqual([{pot: 30, positions: [0, 1], contributors: [{position: 0, bet: 10}, {position: 1, bet: 10}, {position: 2, bet: 10}] }], pot)

    it 'combine (new)', ->
      b.options.pot = [{pot: 20, positions: [0, 1], contributors: [{position: 0, bet: 10}, {position: 1, bet: 10}] }]
      b.pot([{bet: 5, position: 0}, {bet: 5, position: 2}])
      pot = spy.getCall(0).args[0].pot
      assert.deepEqual([
        {pot: 20, positions: [0, 1], contributors: [{position: 0, bet: 10}, {position: 1, bet: 10}] }
        {pot: 10, positions: [0, 2], contributors: [{position: 0, bet: 5}, {position: 2, bet: 5}] }
      ], pot)

    it 'combine (folded)', ->
      b.options.pot = [{pot: 30, positions: [0, 1, 2], contributors: [{position: 0, bet: 10}, {position: 1, bet: 10}, {position: 2, bet: 10}] }]
      b.pot([{bet: 20, position: 0}, {bet: 20, position: 1}, {bet: 0, position: 2, fold: true}])
      pot = spy.getCall(0).args[0].pot
      assert.deepEqual([{pot: 70, positions: [0, 1], contributors: [{bet: 30, position: 0}, {bet: 30, position: 1}, {bet: 10, position: 2}] }], pot)

    it 'fold', ->
      b.pot([{bet: 20, position: 0}, {bet: 20, position: 1}, {bet: 10, position: 2, fold: true}])
      pot = spy.getCall(0).args[0].pot
      assert.deepEqual([{pot: 50, positions: [0, 1], contributors: [{bet: 20, position: 0}, {bet: 20, position: 1}, {bet: 10, position: 2}] }], pot)

    it 'fold (all_in)', ->
      b.pot([{bet: 20, position: 0}, {bet: 20, position: 1}, {bet: 10, position: 2, fold: true}, {bet: 5, position: 3}])
      pot = spy.getCall(0).args[0].pot
      assert.deepEqual([
        {pot: 20, positions: [0, 1, 3], contributors: [ {position: 0, bet: 5}, {position: 1, bet: 5}, {position: 2, bet: 5}, {position: 3, bet: 5} ]}
        {pot: 35, positions: [0, 1], contributors: [ {position: 0, bet: 15}, {position: 1, bet: 15}, {position: 2, bet: 5} ] }
      ], pot)

    it 'fold (all_in bigger)', ->
      b.pot([{bet: 20, position: 0}, {bet: 20, position: 1}, {bet: 10, position: 2, fold: true}, {bet: 15, position: 3}])
      pot = spy.getCall(0).args[0].pot
      assert.deepEqual([
        {pot: 55, positions: [0, 1, 3], contributors: [{position: 0, bet: 15}, {position: 1, bet: 15}, {position: 2, bet: 10}, {position: 3, bet: 15}]}
        {pot: 10, positions: [0, 1], contributors: [{position: 0, bet: 5}, {position: 1, bet: 5}]}
      ], pot)

    it 'only one user', ->
      b.on 'pot:return', spy2
      b.pot([{bet: 5, fold: true, position: 0}, {bet: 15, position: 1}])
      assert.equal(1, spy2.callCount)
      assert.deepEqual({pot: 10, position: 1}, spy2.getCall(0).args[0])
      pot = spy.getCall(0).args[0].pot
      assert.deepEqual([{pot: 10, positions: [1], contributors: [{position: 0, bet: 5}, {position: 1, bet: 5}] }], pot)

    it 'no bets', ->
      b.pot([])
      assert.equal(0, spy.callCount)


  describe 'pot devide', ->
    it 'default', ->
      b.options.pot = [{pot: 20, positions: [0, 1, 2]}]
      pots = b.pot_devide( [ [1], [0] ] )
      assert.equal(1, pots.length)
      assert.deepEqual([{position: 1, win: 20}], pots[0].winners)

    it '2 winners', ->
      b.options.pot = [{pot: 21, positions: [0, 1, 2, 3, 4]}]
      pots = b.pot_devide( [ [1, 2] ] )
      assert.deepEqual([{position: 1, win: 10}, {position: 2, win: 11}], pots[0].winners)

    it '2 winner not in positions', ->
      b.options.pot = [{pot: 20, positions: [0, 2, 3, 4]}]
      pots = b.pot_devide( [ [1, 2] ] )
      assert.deepEqual([{position: 2, win: 20}], pots[0].winners)

    it 'more pots', ->
      b.options.pot = [{pot: 20, positions: [0, 1, 2]}, {pot: 10, positions: [0, 2]}]
      pots = b.pot_devide([ [3, 4], [1], [0] ] )
      assert.equal(2, pots.length)
      assert.deepEqual([{position: 1, win: 20}], pots[0].winners)
      assert.deepEqual([{position: 0, win: 10}], pots[1].winners)

    it 'showdown', ->
      b.options.pot = [{pot: 20, positions: [0, 2, 4]}]
      b.options.show_first = 0
      pots = b.pot_devide( [ [2], [1], [0], [4] ] )
      assert.deepEqual([0, 2], pots[0].showdown)

    it 'showdown (big show)', ->
      b.options.pot = [{pot: 20, positions: [0, 1, 2]}]
      b.options.show_first = 10
      pots = b.pot_devide( [ [1], [2], [0] ] )
      assert.deepEqual([0, 1], pots[0].showdown)

    it 'showdown (order)', ->
      b.options.pot = [{pot: 20, positions: [0, 1, 2]}]
      b.options.show_first = 1
      pots = b.pot_devide( [ [2], [1] ] )
      assert.deepEqual([1, 2], pots[0].showdown)

    it 'showdown (other winners)', ->
      b.options.pot = [{pot: 20, positions: [0, 1, 2, 3, 4]}]
      b.options.show_first = 1
      pots = b.pot_devide( [ [2, 4], [1] ] )
      assert.deepEqual([1, 2, 4], pots[0].showdown)

    it 'showdown (last raiser)', ->
      b.options.pot = [{pot: 20, positions: [0, 1, 2, 3, 4]}]
      b.options.show_first = 0
      b.options.bet_raise_position = 2
      pots = b.pot_devide( [ [2], [1] ] )
      assert.deepEqual([2], pots[0].showdown)

    it 'showdown (last raiser not in positions)', ->
      b.options.pot = [{pot: 20, positions: [0, 2, 3, 4]}]
      b.options.show_first = 0
      b.options.bet_raise_position = 1
      pots = b.pot_devide( [ [2], [1, 0] ] )
      assert.deepEqual([0, 2], pots[0].showdown)

    it 'showdown (one player)', ->
      b.options.pot = [{pot: 20, positions: [0, 2, 3, 4]}]
      b.options.show_first = 0
      pots = b.pot_devide( [ [2] ])
      assert.deepEqual([], pots[0].showdown)

    it 'showdown (one player in pot)', ->
      b.options.pot = [{pot: 20, positions: [0]}]
      b.options.show_first = 0
      pots = b.pot_devide( [ [2, 1, 0] ])
      assert.deepEqual([], pots[0].showdown)

    it 'showdown (not in winners)', ->
      b.options.pot = [{pot: 20, positions: [0, 2, 3, 4]}]
      b.options.show_first = 0
      pots = b.pot_devide( [ [3], [2] ])
      assert.deepEqual([2, 3], pots[0].showdown)

    it 'showdown (middle not winner)', ->
      b.options.pot = [{pot: 20, positions: [0, 1, 2]}]
      b.options.show_first = 0
      pots = b.pot_devide( [ [2], [0], [1] ])
      assert.deepEqual([0, 2], pots[0].showdown)

    it 'showdown (middle not winner (2 players))', ->
      b.options.pot = [{pot: 20, positions: [0, 1, 2, 3]}]
      b.options.show_first = 0
      pots = b.pot_devide( [ [3], [0, 1], [2] ])
      assert.deepEqual([0, 1, 3], pots[0].showdown)

    it 'rake', ->
      b.options.pot = [{pot: 20, positions: [0]}]
      pots = b.pot_devide( [ [0] ], {percent: 5, cap: 100})
      assert.equal(1, pots[0].rake)
      assert.equal(19, pots[0].winners[0].win)

    it 'rake (not enough)', ->
      b.options.pot = [{pot: 19, positions: [0]}]
      pots = b.pot_devide( [ [0] ], {percent: 5, cap: 100})
      assert.ok(Object.keys(pots[0]).indexOf('rake') is -1)
      assert.equal(19, pots[0].winners[0].win)

    it 'rake (cap)', ->
      b.options.pot = [{pot: 20, positions: [0]}, {pot: 60, positions: [0]}, {pot: 20, positions: [0]}]
      pots = b.pot_devide( [ [0] ], {percent: 5, cap: 3})
      assert.equal(1, pots[0].rake)
      assert.equal(19, pots[0].winners[0].win)
      assert.equal(2, pots[1].rake)
      assert.equal(58, pots[1].winners[0].win)
      assert.ok(Object.keys(pots[2]).indexOf('rake') is -1)
