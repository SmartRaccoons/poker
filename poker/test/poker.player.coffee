assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')


rank_constructor = ->
class Rank
  constructor: ->
    @_hand_rank = 'rank'
    @_hand_message = 'mes'
    rank_constructor.apply(this, arguments)


Player = proxyquire('../poker.player', {
  './rank':
    PokerRank: Rank
}).PokerPlayer



describe 'Player', ->
  u = null
  spy = null
  up = null
  beforeEach ->
    spy = sinon.spy()
    u = new Player({id: 2, chips: 50, position: 2})
    rank_constructor = sinon.spy()
    u.options_update = up = sinon.spy()

  describe 'default', ->
    it 'options', ->
      assert.deepEqual({
        talked: false
        command: ''
        showdown: false
        cards: []
        cards_board: []
        bet: 0
        win: 0
        turn_history: [[]]
      }, u._options_default())

    it 'budget', ->
      u.options.chips = 5
      u.options.win = 2
      assert.equal(7, u.budget())

    it 'round', ->
      u.options.chips = 5
      u.options.win = 2
      u.round('c')
      assert.equal(1, up.callCount)
      assert.equal(0, up.getCall(0).args[0].win)
      assert.equal(7, up.getCall(0).args[0].chips_last)
      assert.equal(7, up.getCall(0).args[0].chips)
      assert.equal('c', up.getCall(0).args[0].cards)

    it 'rank', ->
      u.options.rank = 'r'
      assert.equal('r', u.rank())

    it 'showdown', ->
      u.options.cards = [1]
      assert.deepEqual([1], u.showdown())
      assert.equal(1, up.callCount)
      assert.deepEqual({showdown: true}, up.getCall(0).args[0])

    it 'filter', ->
      u.fold = -> true
      assert.equal(true, u.filter({fold: true}))
      assert.equal(false, u.filter({fold: false}))
      u.all_in = -> true
      assert.equal(true, u.filter({fold: true, all_in: true}))
      assert.equal(false, u.filter({fold: true, all_in: false}))

    it 'all_in', ->
      u.options.command = 'all_in'
      assert.equal(true, u.all_in())
      u.options.command = 'fold'
      assert.equal(false, u.all_in())

    it 'fold', ->
      u.options.command = 'fold'
      assert.equal(true, u.fold())
      u.options.command = 'all_in'
      assert.equal(false, u.fold())

    it 'id', ->
      u.options.id = 5
      assert.equal(5, u.id())

    it 'bet', ->
      u.options.chips = 10
      u.options.bet = 2
      assert.equal(5, u.bet({bet: 5, command: 'bet'}))
      assert.equal(1, up.callCount)
      assert.deepEqual({chips: 5, bet: 7, command: 'bet', talked: true}, up.getCall(0).args[0])

    it 'bet (blind)', ->
      u.options.chips = 10
      u.options.bet = 2
      u.bet({bet: 5, command: 'blind'})
      assert.deepEqual({chips: 5, bet: 7, command: 'blind'}, up.getCall(0).args[0])

    it 'bet (all_in)', ->
      u.options.chips = 10
      u.options.bet = 2
      assert.equal(10, u.bet({bet: 15, command: 'blind'}))
      assert.deepEqual({chips: 0, bet: 12, command: 'all_in'}, up.getCall(0).args[0])

    it 'bet_return', ->
      u.options.chips = 20
      u.options.bet = 10
      u.on 'bet_return', spy
      u.bet_return({bet: 5})
      assert.equal(1, up.callCount)
      assert.deepEqual({chips: 25, bet: 5}, up.getCall(0).args[0])
      assert.equal(1, spy.callCount)
      assert.deepEqual({bet: 5}, spy.getCall(0).args[0])

    it 'bet_pot', ->
      u.options.bet = 10
      assert.equal(10, u.bet_pot())
      assert.equal(1, up.callCount)
      assert.deepEqual({bet: 0}, up.getCall(0).args[0])

    it 'win', ->
      u.on 'win', spy
      u.options.win = 1
      u.win({win: 5})
      assert.equal(1, up.callCount)
      assert.deepEqual({win: 6}, up.getCall(0).args[0])
      assert.equal(1, spy.callCount)
      assert.deepEqual({win: 5}, spy.getCall(0).args[0])

    it 'win (silent)', ->
      u.on 'win', spy
      u.options.win = 1
      u.win({win: 5}, true)
      assert.equal(0, spy.callCount)

    it 'progress', ->
      u.on 'win', spy
      u.options.command = 'raise'
      u.options.cards_board = [2]
      u.options.turn_history = [['x']]
      u.progress({cards: [5]})
      assert.equal(1, up.callCount)
      assert.deepEqual({command: null, turn_history: [['x'], []], cards_board: [2, 5], talked: false}, up.getCall(0).args[0])

    it 'progress (command all_in/fold)', ->
      u.options.command = 'all_in'
      u.progress({cards: [5]})
      assert.ok(Object.keys(up.getCall(0).args[0]).indexOf('command') < 0)
      u.options.command = 'fold'
      u.progress({cards: [5]})
      assert.ok(Object.keys(up.getCall(1).args[0]).indexOf('command') < 0)

    it 'action_require (bet less)', ->
      u.options.bet = 9
      u.options.talked = true
      assert.equal(true, u.action_require(10))

    it 'action_require (bet bigger)', ->
      u.options.bet = 10
      u.options.talked = true
      assert.equal(false, u.action_require(10))

    it 'action_require (fold)', ->
      u.fold = -> true
      assert.equal(false, u.action_require(10))

    it 'action_require (all in)', ->
      u.all_in = -> true
      assert.equal(false, u.action_require(10))

    it 'sit', ->
      u.sit({out: true})
      assert.equal(1, up.callCount)
      assert.deepEqual({sitout: true}, up.getCall(0).args[0])

    it 'toJSON', ->
      u.options.cards = [1, 2]
      u.options.bet = 10
      assert.equal(10, u.toJSON().bet)
      assert.ok(Object.keys(u.toJSON()).indexOf('cards_board') is -1)
      assert.equal(2, u.toJSON().id)
      assert.equal(2, u.toJSON().position)
      assert.equal(50, u.toJSON().chips)
      assert.equal(false, u.toJSON().sitout)
      assert.deepEqual(['', ''], u.toJSON().cards)

    it 'toJSON (showdown)', ->
      u.options.cards = [1, 2]
      u.options.showdown = true
      assert.deepEqual([1, 2], u.toJSON().cards)


  describe 'turn', ->
    beforeEach ->
      u.commands = sinon.fake.returns([['check'], ['call', 30], ['raise', 40, 500], ['bet', 40, 500]])
      u.bet = sinon.fake.returns(3)
      u.fold = sinon.spy()
      u.options.bet = 5
      u.options.turn_history = [['x'], []]
      u.on 'turn', spy

    it 'check', ->
      u.options.command = 'ch'
      u.options.chips = 3
      assert.equal(true, u.turn('c-params', ['check']) )
      assert.equal(1, u.commands.callCount)
      assert.equal('c-params', u.commands.getCall(0).args[0])
      assert.equal(1, u.bet.callCount)
      assert.deepEqual({bet: 0, command: 'check'}, u.bet.getCall(0).args[0])
      assert.equal(1, spy.callCount)
      assert.deepEqual({bet: 3, command: 'ch'}, spy.getCall(0).args[0])
      assert.deepEqual([['x'], ['x']], u.options.turn_history)

    it 'call', ->
      u.turn('', ['call', 500])
      assert.deepEqual({bet: 30, command: 'call'}, u.bet.getCall(0).args[0])
      assert.deepEqual([['x'], ['c']], u.options.turn_history)

    it 'raise', ->
      u.turn('', ['raise', 50.5])
      assert.equal(50, u.bet.getCall(0).args[0].bet)

    it 'raise (no value)', ->
      u.turn('', ['raise'])
      assert.equal(40, u.bet.getCall(0).args[0].bet)

    it 'raise (small)', ->
      u.turn('', ['raise', 30])
      assert.equal(40, u.bet.getCall(0).args[0].bet)

    it 'raise (big)', ->
      u.turn('', ['raise', 501])
      assert.equal(40, u.bet.getCall(0).args[0].bet)

    it 'bet', ->
      u.turn('', ['bet', 50])
      assert.equal(50, u.bet.getCall(0).args[0].bet)

    it 'fold', ->
      u.commands = -> [['fold']]
      u.turn('', ['fold'])
      assert.equal(0, u.bet.getCall(0).args[0].bet)

    it 'fake', ->
      assert.equal(false, u.turn('', ['fake']) )
      assert.equal(false, u.turn('', []) )
      assert.equal(false, u.turn('') )
      assert.equal(false, u.turn('', 'boom') )
      assert.equal(0, u.bet.callCount)


  describe 'commands', ->

    it 'bet (same)', ->
      u.options.bet = 10
      assert.deepEqual(['check'], u.commands({bet_max: 10})[0])
      assert.deepEqual(['raise', 5, 50], u.commands({bet_max: 10, bet_raise: 5})[1])
      assert.equal(0, u.commands({bet_max: 10}).filter((c)-> c[0] is 'call').length)

    it 'bet (ok)', ->
      u.options.bet = 10
      assert.deepEqual(['raise', 20, 50], u.commands({bet_max: 15, bet_raise: 15})[2])

    it 'bet (big)', ->
      u.options.bet = 15
      u.options.chips = 30
      assert.deepEqual(['fold'], u.commands({bet_max: 20})[0])
      assert.deepEqual(['call', 5], u.commands({bet_max: 20})[1])
      assert.deepEqual(['raise', 30], u.commands({bet_max: 20, bet_raise: 25})[2])

    it 'bet (chips not enough)', ->
      u.options.chips = 5
      u.options.bet = 45
      commands = u.commands({bet_max: 70})
      assert.deepEqual(['call', 5], commands[1])
      assert.equal(2, commands.length)

    it 'bet (bet_max: 0)', ->
      assert.equal('bet', u.commands({bet_max: 0})[1][0])

    it 'bet (auto check)', ->
      u.options.bet = 20
      assert.deepEqual([['check']], u.commands({bet_max: 10, stacks: 1}))

    it 'bet (check or call)', ->
      u.options.bet = 2
      assert.deepEqual([['fold'], ['call', 8]], u.commands({bet_max: 10, stacks: 1}))


  describe 'options bind', ->
    fn = null
    beforeEach ->
      fn = u._options_bind

    it 'rank update', ->
      u.options.cards = [1, 2]
      u.options.cards_board = [3, 4]
      fn['cards,cards_board'].bind(u)()
      assert.equal(1, rank_constructor.callCount)
      assert.deepEqual([1, 2, 3, 4], rank_constructor.getCall(0).args[0])
      assert.equal(1, up.callCount)
      assert.equal('rank', up.getCall(0).args[0].rank.rank)
      assert.equal('mes', up.getCall(0).args[0].rank.message)

    it 'rank update (no cards)', ->
      u.options.cards = []
      u.options.cards_board = []
      fn['cards,cards_board'].bind(u)()
      assert.equal(0, rank_constructor.callCount)
      assert.equal(null, up.getCall(0).args[0].rank)

    it 'sitout', ->
      u.options.sitout = true
      u.on 'sit', spy
      fn['sitout'].bind(u)()
      assert.equal(1, spy.callCount)
      assert.deepEqual({out: true}, spy.getCall(0).args[0])

    it 'bet', ->
      u.options.bet = 5
      u.on 'bet', spy
      fn['bet'].bind(u)()
      assert.equal(1, spy.callCount)
      assert.deepEqual({bet: 5}, spy.getCall(0).args[0])
