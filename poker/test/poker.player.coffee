assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')


rank_constructor = ->
class Rank
  constructor: ->
    @name = 'rank'
    rank_constructor.apply(this, arguments)


Player = proxyquire('../poker.player', {
  './rank':
    Rank: Rank
}).PokerPlayer



describe 'Player', ->
  u = null
  beforeEach ->
    u = new Player({id: 2, chips: 50, position: 2})
    u.reset()
    rank_constructor = sinon.spy()

  describe 'default', ->

    it 'init', ->
      assert.equal(2, u.id)
      assert.equal(50, u.chips)
      assert.equal(2, u.position)

    it 'reset', ->
      u.folded = true
      u.talked = true
      u.all_in = true
      u.cards = [1, 2]
      u.cards_board = [3]
      u.bet = 0
      u.reset()
      assert.equal(false, u.folded)
      assert.equal(false, u.talked)
      assert.equal(false, u.all_in)
      assert.deepEqual([], u.cards)
      assert.deepEqual([], u.cards_board)
      assert.equal(0, u._bet)

    it 'filter', ->
      u.folded = true
      assert.equal(true, u.filter({folded: true}))
      assert.equal(false, u.filter({folded: false}))
      u.all_in = true
      assert.equal(true, u.filter({folded: true, all_in: true}))
      assert.equal(false, u.filter({folded: true, all_in: false}))

    it 'round', ->
      u._rank_calculate = sinon.spy()
      u.reset = sinon.spy()
      u.round([1, 2])
      assert.deepEqual([1, 2], u.cards)
      assert.equal(1, u.reset.callCount)
      assert.equal(1, u._rank_calculate.callCount)

    it 'board_cards', ->
      u._rank_calculate = sinon.spy()
      u.board_cards([1, 2])
      assert.deepEqual([1, 2], u.cards_board)
      assert.equal(1, u._rank_calculate.callCount)
      u.board_cards([3])
      assert.deepEqual([1, 2, 3], u.cards_board)

    it '_rank_calculate', ->
      u.cards = [1, 2]
      u.cards_board = [3, 4]
      u._rank_calculate()
      assert.equal(1, rank_constructor.callCount)
      assert.deepEqual([1, 2, 3, 4], rank_constructor.getCall(0).args[0])
      assert.equal('rank', u._rank.name)

    it 'rank', ->
      u._rank =
        _hand_rank: 'rank'
        _hand_message: 'mes'
      assert.deepEqual({rank: 'rank', message: 'mes'}, u.rank())

    it 'bet', ->
      u.bet({bet: 10})
      assert.equal(10, u._bet)
      assert.equal(40, u.chips)
      assert.equal(true, u.talked)

    it 'bet (sum)', ->
      u.bet({bet: 10})
      u.bet({bet: 15})
      assert.equal(25, u._bet)

    it 'bet (all_in)', ->
      u.bet({bet: 50})
      assert.equal(50, u._bet)
      assert.equal(true, u.all_in)

    it 'bet (all_in big)', ->
      u.bet({bet: 60})
      assert.equal(50, u._bet)
      assert.equal(0, u.chips)

    it 'bet (silent)', ->
      u.bet({bet: 10, silent: true})
      assert.equal(false, u.talked)

    it 'progress', ->
      u._bet = 10
      assert.equal(10, u.progress())
      assert.equal(0, u._bet)

    it 'action_require (no talked)', ->
      u._bet = 10
      assert.equal(true, u.action_require(10))

    it 'action_require (bet less)', ->
      u._bet = 9
      u.talked = true
      assert.equal(true, u.action_require(10))

    it 'action_require (bet bigger)', ->
      u._bet = 10
      u.talked = true
      assert.equal(false, u.action_require(10))

    it 'action_require (folded)', ->
      u.folded = true
      assert.equal(false, u.action_require(10))

    it 'action_require (all in)', ->
      u.all_in = true
      assert.equal(false, u.action_require(10))

    it 'fold', ->
      u.fold()
      assert.equal(true, u.folded)

    it 'win', ->
      u.chips = 10
      u.win(20)
      assert.equal(30, u.chips)

    it 'toJSON', ->
      u.reset()
      assert.deepEqual({id: 2, chips: 50, position: 2, folded: false, talked: false, all_in: false, bet: 0}, u.toJSON())


  describe 'commands', ->

    it 'bet (small)', ->
      u._bet = 20
      assert.deepEqual(['check'], u.commands({bet_max: 10})[0])
      assert.deepEqual(['raise', 5, 50], u.commands({bet_max: 10, bet_raise: 5})[1])

    it 'bet (same)', ->
      u._bet = 10
      assert.deepEqual(['check'], u.commands({bet_max: 10})[0])
      assert.deepEqual(['raise', 5, 50], u.commands({bet_max: 10, bet_raise: 5})[1])
      assert.equal(0, u.commands({bet_max: 10}).filter((c)-> c[0] is 'call').length)

    it 'bet (ok)', ->
      u._bet = 10
      assert.deepEqual(['raise', 20, 50], u.commands({bet_max: 15, bet_raise: 15})[2])

    it 'bet (big)', ->
      u._bet = 15
      u.chips = 30
      assert.deepEqual(['fold'], u.commands({bet_max: 20})[0])
      assert.deepEqual(['call', 5], u.commands({bet_max: 20})[1])
      assert.deepEqual(['raise', 30], u.commands({bet_max: 20, bet_raise: 30})[2])

    it 'bet (chips not enough)', ->
      u.chips = 5
      u._bet = 45
      commands = u.commands({bet_max: 70})
      assert.deepEqual(['call', 5], commands[1])
      assert.equal(2, commands.length)
