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
    PokerRank: Rank
}).PokerPlayer



describe 'Player', ->
  u = null
  spy = null
  beforeEach ->
    spy = sinon.spy()
    u = new Player({id: 2, chips: 50, position: 2})
    u.reset()
    rank_constructor = sinon.spy()

  describe 'default', ->

    it 'init', ->
      u = new Player({id: 2, chips: 50, position: 2})
      assert.equal(2, u.id)
      assert.equal(50, u.chips)
      assert.equal(2, u.position)
      assert.deepEqual([], u.cards)

    it 'reset', ->
      u.fold = true
      u.talked = true
      u.all_in = true
      u._showdown = true
      u.cards = [1, 2]
      u.cards_board = [3]
      u._bet = 3
      u._win = 4
      u._turn_history = [['x', 'f']]
      u.reset()
      assert.equal(false, u.fold)
      assert.equal(false, u.talked)
      assert.equal(false, u.all_in)
      assert.equal(false, u._showdown)
      assert.deepEqual([], u.cards)
      assert.deepEqual([], u.cards_board)
      assert.equal(0, u._bet)
      assert.equal(0, u._win)
      assert.deepEqual([[]], u._turn_history)

    it 'filter', ->
      u.fold = true
      assert.equal(true, u.filter({fold: true}))
      assert.equal(false, u.filter({fold: false}))
      u.all_in = true
      assert.equal(true, u.filter({fold: true, all_in: true}))
      assert.equal(false, u.filter({fold: true, all_in: false}))

    it 'showdown', ->
      u.cards = [1, 2]
      assert.deepEqual([1, 2], u.showdown())
      assert.equal(true, u._showdown)

    it 'budget', ->
      u.chips = 5
      u._win = 10
      assert.equal(15, u.budget())

    it 'round', ->
      u._rank_calculate = sinon.spy()
      u._win = 10
      u.chips = 5
      u.reset = sinon.spy()
      u.round([1, 2])
      assert.equal(15, u.chips_last)
      assert.equal(15, u.chips)
      assert.deepEqual([1, 2], u.cards)
      assert.equal(1, u.reset.callCount)
      assert.equal(1, u._rank_calculate.callCount)

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
      u.on 'bet', spy
      assert.equal(10, u.bet({bet: 10}) )
      assert.equal(10, u._bet)
      assert.equal(40, u.chips)
      assert.equal(true, u.talked)
      assert.equal(1, spy.callCount)
      assert.deepEqual({bet: 10}, spy.getCall(0).args[0])

    it 'bet (sum)', ->
      u.bet({bet: 10})
      u.on 'bet', spy
      u.bet({bet: 15})
      assert.equal(25, u._bet)
      assert.equal(25, spy.getCall(0).args[0].bet)

    it 'bet (all_in)', ->
      u.bet({bet: 50})
      assert.equal(50, u._bet)
      assert.equal(true, u.all_in)

    it 'bet (all_in big)', ->
      u.on 'bet', spy
      assert.equal(50, u.bet({bet: 60}) )
      assert.equal(50, u._bet)
      assert.equal(0, u.chips)
      assert.deepEqual({bet: 50}, spy.getCall(0).args[0])

    it 'bet (blind)', ->
      u.bet({bet: 10, blind: true})
      assert.equal(false, u.talked)

    it 'bet_return', ->
      u.all_in = true
      u.on 'bet_return', spy
      u.chips = 20
      u.bet_return({bet: 5})
      assert.equal(false, u.all_in)
      assert.equal(25, u.chips)
      assert.equal(1, spy.callCount)
      assert.deepEqual({bet: 5}, spy.getCall(0).args[0])

    it 'bet_pot', ->
      u._bet = 10
      assert.equal(10, u.bet_pot())
      assert.equal(0, u._bet)

    it 'progress', ->
      u.talked = true
      u._turn_history = [['f']]
      u._rank_calculate = sinon.spy()
      u.progress({cards: [1, 2]})
      assert.deepEqual([['f'], []], u._turn_history)
      assert.equal(false, u.talked)
      assert.deepEqual([1, 2], u.cards_board)
      assert.equal(1, u._rank_calculate.callCount)
      u.progress({cards: [3]})
      assert.deepEqual([1, 2, 3], u.cards_board)

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

    it 'action_require (fold)', ->
      u.fold = true
      assert.equal(false, u.action_require(10))

    it 'action_require (all in)', ->
      u.all_in = true
      assert.equal(false, u.action_require(10))

    it 'win', ->
      u.on 'win', spy
      u._win = 10
      u.win({win: 20})
      assert.equal(30, u._win)
      assert.equal(1, spy.callCount)
      assert.deepEqual({win: 20}, spy.getCall(0).args[0])

    it 'win (silent)', ->
      u.on 'win', spy
      u.win({win: 20}, true)
      assert.equal(0, spy.callCount)

    it 'toJSON', ->
      u.reset()
      u._turn_history = [['x']]
      assert.deepEqual({id: 2, chips: 50, position: 2, cards: [], fold: false, talked: false, all_in: false, sitout: false, bet: 0, win: 0, turn_history: [['x']]}, u.toJSON())

    it 'toJSON (cards)', ->
      u._showdown = false
      u.cards = []
      assert.deepEqual([], u.toJSON().cards)
      u.cards = [1, 2]
      assert.deepEqual(['', ''], u.toJSON().cards)
      u._showdown = true
      assert.deepEqual([1, 2], u.toJSON().cards)


  describe 'commands', ->

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
      assert.deepEqual(['raise', 30], u.commands({bet_max: 20, bet_raise: 25})[2])

    it 'bet (chips not enough)', ->
      u.chips = 5
      u._bet = 45
      commands = u.commands({bet_max: 70})
      assert.deepEqual(['call', 5], commands[1])
      assert.equal(2, commands.length)

    it 'bet (bet_max: 0)', ->
      assert.equal('bet', u.commands({bet_max: 0})[1][0])

    it 'bet (auto check)', ->
      u._bet = 20
      assert.deepEqual([['check']], u.commands({bet_max: 10, stacks: 1}))

    it 'bet (check or call)', ->
      u._bet = 2
      assert.deepEqual([['fold'], ['call', 8]], u.commands({bet_max: 10, stacks: 1}))

    it 'sitout', ->
      u.on 'sit', spy
      u.sit({out: true})
      assert.equal(1, spy.callCount)
      assert.deepEqual({out: true}, spy.getCall(0).args[0])
      assert.equal(true, u.sitout)

    it 'sitback', ->
      u.sit({out: true})
      u.on 'sit', spy
      u.sit({out: false})
      assert.equal(1, spy.callCount)
      assert.deepEqual({out: false}, spy.getCall(0).args[0])
      assert.equal(false, u.sitout)
      u.sit({out: false})
      assert.equal(1, spy.callCount)


  describe 'turn', ->
    beforeEach ->
      u.commands = sinon.fake.returns([['check'], ['call', 30], ['raise', 40, 500], ['bet', 40, 500]])
      u.bet = sinon.fake.returns(3)
      u.fold = sinon.spy()
      u._bet = 5
      u._turn_history = [['x'], []]
      u.on 'turn', spy

    it 'check', ->
      u.chips = 3
      assert.equal(true, u.turn('c-params', ['check']) )
      assert.equal(1, u.commands.callCount)
      assert.equal('c-params', u.commands.getCall(0).args[0])
      assert.equal(1, u.bet.callCount)
      assert.deepEqual({bet: 0}, u.bet.getCall(0).args[0])
      assert.equal(1, spy.callCount)
      assert.deepEqual({command: 'check'}, spy.getCall(0).args[0])
      assert.deepEqual([['x'], ['x']], u._turn_history)

    it 'call', ->
      u.turn('', ['call', 500])
      assert.equal(1, u.bet.callCount)
      assert.deepEqual({bet: 30}, u.bet.getCall(0).args[0])
      assert.deepEqual({command: 'call', bet: 3}, spy.getCall(0).args[0])
      assert.deepEqual([['x'], ['c']], u._turn_history)

    it 'raise', ->
      u.turn('', ['raise', 50.5])
      assert.equal(1, u.bet.callCount)
      assert.deepEqual({bet: 50}, u.bet.getCall(0).args[0])
      assert.deepEqual({command: 'raise', bet: 3}, spy.getCall(0).args[0])
      assert.deepEqual([['x'], ['r']], u._turn_history)

    it 'raise (no value)', ->
      u.turn('', ['raise'])
      assert.equal(1, u.bet.callCount)
      assert.deepEqual({bet: 40}, u.bet.getCall(0).args[0])

    it 'raise (small)', ->
      u.turn('', ['raise', 30])
      assert.equal(1, u.bet.callCount)
      assert.deepEqual({bet: 40}, u.bet.getCall(0).args[0])

    it 'raise (big)', ->
      u.turn('', ['raise', 501])
      assert.equal(1, u.bet.callCount)
      assert.deepEqual({bet: 40}, u.bet.getCall(0).args[0])

    it 'raise (big)', ->
      u.commands = -> [[], [], ['raise', 40]]
      u.turn('', ['raise', 501])
      assert.equal(1, u.bet.callCount)
      assert.deepEqual({bet: 40}, u.bet.getCall(0).args[0])

    it 'bet', ->
      u.turn('', ['bet', 50])
      assert.equal(1, u.bet.callCount)
      assert.deepEqual({bet: 50}, u.bet.getCall(0).args[0])
      assert.deepEqual({command: 'bet', bet: 3}, spy.getCall(0).args[0])
      assert.deepEqual([['x'], ['b']], u._turn_history)

    it 'fold', ->
      u.fold = false
      u.commands = -> [['fold']]
      u.turn('', ['fold'])
      assert.equal(0, u.bet.callCount)
      assert.equal(true, u.fold)
      assert.deepEqual({command: 'fold'}, spy.getCall(0).args[0])

    it 'all_in', ->
      u.all_in = true
      u.chips = 0
      u.turn('c-params', ['check'])
      assert.equal('all_in', spy.getCall(0).args[0].command)
      assert.deepEqual([['x'], ['a']], u._turn_history)

    it 'fake', ->
      assert.equal(false, u.turn('', ['fake']) )
      assert.equal(false, u.turn('', []) )
      assert.equal(false, u.turn('') )
      assert.equal(false, u.turn('', 'boom') )
      assert.equal(0, u.bet.callCount)
      assert.equal(0, u.fold.callCount)
