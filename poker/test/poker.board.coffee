assert = require('assert')
sinon = require('sinon')

Board = require('../poker.board').PokerBoard


describe 'Board', ->
  b = null
  spy = null
  beforeEach ->
    spy = sinon.spy()
    b = new Board()
    b.reset({blinds: [1, 2], show_first: 2})

  describe 'default', ->

    it 'reset', ->
      b._bet_max = 11
      b._bet_raise = 11
      b.reset({blinds: [1, 2], show_first: 3})
      assert.equal(0, b._bet_max)
      assert.equal(2, b._bet_raise)
      assert.deepEqual([], b._cards)
      assert.deepEqual([], b._pot)
      assert.deepEqual([1, 2], b._blinds)
      assert.equal(-1, b._bet_raise_position)
      assert.equal(3, b._show_first)

    it 'bet_max', ->
      b.bet({bet: 10})
      b.bet({bet: 11})
      b.bet({bet: 9})
      assert.equal(11, b.bet_max())

    it 'bet_raise', ->
      b.bet({bet: 1, position: 1})
      b.bet({bet: 5, position: 2})
      b.bet({bet: 5, position: 3})
      assert.equal(4, b.bet_raise())
      assert.equal(2, b._bet_raise_position)

    it 'bet_raise (no max)', ->
      b.bet({bet: 6})
      b.bet({bet: 8})
      assert.equal(6, b.bet_raise())

    it 'bet_raise (round)', ->
      b.bet({bet: 5})
      assert.equal(6, b.bet_raise())

    it 'cards', ->
      b.on('card', spy)
      b._bet_raise_position = 2
      b.cards([1, 2])
      assert.equal(1, spy.callCount)
      assert.deepEqual([1, 2], spy.getCall(0).args[0])
      assert.equal(-1, b._bet_raise_position)
      assert.deepEqual([[1, 2]], b._cards)
      b.cards([3])
      assert.deepEqual([[1, 2], [3]], b._cards)


  describe 'pot', ->

    it 'reset bet', ->
      b._bet_max = 10
      b._bet_raise = 10
      b.pot([])
      assert.equal(b._bet_max, 0)
      assert.equal(b._bet_raise, 2)

    it 'equal', ->
      b.pot([{bet: 10, position: 0}, {bet: 10, position: 1}])
      assert.deepEqual([{pot: 20, positions: [0, 1]}], b._pot)

    it 'negative progression', ->
      b.pot([{bet: 20, position: 0}, {bet: 10, position: 2}, {bet: 10, position: 1}])
      assert.deepEqual([{pot: 30, positions: [0, 1, 2]}], b._pot)

    it 'zero bets', ->
      b.pot([{bet: 0, position: 0}, {bet: 10, position: 1}, {bet: 10, position: 2}])
      assert.deepEqual([{pot: 20, positions: [1, 2]}], b._pot)

    it 'middle big', ->
      b.pot([{bet: 10, position: 0}, {bet: 20, position: 1}, {bet: 10, position: 2}, {bet: 20, position: 3}])
      assert.deepEqual([{pot: 40, positions: [0, 1, 2, 3]}, {pot: 20, positions: [1, 3]}], b._pot)

    it 'first 2 big', ->
      b.pot([{bet: 20, position: 0}, {bet: 20, position: 1}, {bet: 10, position: 2}])
      assert.deepEqual([{pot: 30, positions: [0, 1, 2]}, {pot: 20, positions: [0, 1]}], b._pot)

    it 'combine', ->
      b._pot = [{pot: 20, positions: [0, 1]}]
      b.pot([{bet: 5, position: 0}, {bet: 5, position: 1}])
      assert.deepEqual([{pot: 30, positions: [0, 1]}], b._pot)

    it 'combine (new)', ->
      b._pot = [{pot: 20, positions: [0, 1]}]
      b.pot([{bet: 5, position: 0}, {bet: 5, position: 2}])
      assert.deepEqual([{pot: 20, positions: [0, 1]}, {pot: 10, positions: [0, 2]}], b._pot)

    it 'only one user', ->
      b.on 'pot:return', spy
      b.pot([{bet: 5, position: 0}, {bet: 15, position: 1}])
      assert.equal(1, spy.callCount)
      assert.deepEqual([{pot: 10, positions: [0, 1]}], b._pot)
      assert.deepEqual({pot: 10, position: 1}, spy.getCall(0).args[0])


  describe 'pot devide', ->
    it 'default', ->
      b._pot = [{pot: 20, positions: [0, 1, 2]}]
      pots = b.pot_devide( [ [1], [0] ] )
      assert.equal(1, pots.length)
      assert.deepEqual([1], pots[0].winners)
      assert.deepEqual([20], pots[0].winners_pot)

    it '2 winners', ->
      b._pot = [{pot: 21, positions: [0, 1, 2, 3, 4]}]
      pots = b.pot_devide( [ [1, 2] ] )
      assert.deepEqual([1, 2], pots[0].winners)
      assert.deepEqual([10, 11], pots[0].winners_pot)

    it '2 winner not in positions', ->
      b._pot = [{pot: 20, positions: [0, 2, 3, 4]}]
      pots = b.pot_devide( [ [1, 2] ] )
      assert.deepEqual([2], pots[0].winners)

    it 'more pots', ->
      b._pot = [{pot: 20, positions: [0, 1, 2]}, {pot: 10, positions: [0, 2]}]
      pots = b.pot_devide([ [3, 4], [1], [0] ] )
      assert.equal(2, pots.length)
      assert.deepEqual([1], pots[0].winners)
      assert.deepEqual([0], pots[1].winners)

    it 'showdown', ->
      b._pot = [{pot: 20, positions: [0, 2, 4]}]
      b._show_first = 0
      pots = b.pot_devide( [ [2], [1] ] )
      assert.deepEqual([0, 2], pots[0].showdown)

    it 'showdown (big show)', ->
      b._pot = [{pot: 20, positions: [0, 1, 2]}]
      b._show_first = 10
      pots = b.pot_devide( [ [1], [2] ] )
      assert.deepEqual([0, 1], pots[0].showdown)

    it 'showdown (order)', ->
      b._pot = [{pot: 20, positions: [0, 1, 2]}]
      b._show_first = 1
      pots = b.pot_devide( [ [2], [1] ] )
      assert.deepEqual([1, 2], pots[0].showdown)

    it 'showdown (other winners)', ->
      b._pot = [{pot: 20, positions: [0, 1, 2, 3, 4]}]
      b._show_first = 1
      pots = b.pot_devide( [ [2, 4] ] )
      assert.deepEqual([1, 2, 4], pots[0].showdown)

    it 'showdown (last raiser)', ->
      b._pot = [{pot: 20, positions: [0, 1, 2, 3, 4]}]
      b._show_first = 0
      b._bet_raise_position = 2
      pots = b.pot_devide( [ [2], [1] ] )
      assert.deepEqual([2], pots[0].showdown)

    it 'showdown (last raiser not in positions)', ->
      b._pot = [{pot: 20, positions: [0, 2, 3, 4]}]
      b._show_first = 0
      b._bet_raise_position = 1
      pots = b.pot_devide( [ [2], [1] ] )
      assert.deepEqual([0, 2], pots[0].showdown)

    it 'showdown (one player)', ->
      b._pot = [{pot: 20, positions: [0, 2, 3, 4]}]
      b._show_first = 0
      pots = b.pot_devide( [ [2] ])
      assert.deepEqual([], pots[0].showdown)
