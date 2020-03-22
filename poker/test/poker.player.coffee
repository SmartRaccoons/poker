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
  spy2 = null
  up = null
  beforeEach ->
    spy = sinon.spy()
    spy2 = sinon.spy()
    u = new Player({id: 2, chips: 50, position: 2, cards: ['Ah', 'Ac']})
    rank_constructor = sinon.spy()
    u.options_update = up = sinon.spy()

  describe 'default', ->
    it 'options', ->
      assert.deepEqual({
        id: null
        position: null
        chips: 0
        chips_start: 0
        talked: false
        command: ''
        showdown: false
        cards: []
        cards_board: []
        bet: 0
        win: 0
        turn_history: [[]]
        out: false
        last: false
        rounds: 0
        rounds_out: 0
      }, u.options_default)
      assert.deepEqual(["talked", "command", "showdown", "cards", "cards_board", "bet", "win", "turn_history"], u.options_round_reset)

    it 'budget', ->
      u.options.chips = 5
      u.options.win = 2
      assert.equal(7, u.budget())

    it 'constructor', ->
      assert.equal 50, u.options.chips_start
      assert.equal 50, u.options.chips_cap

    it '_remove_safe', ->
      u.on 'remove_safe', spy
      u.fold = -> true
      u.options.last = true
      assert.equal true, u._remove_safe()
      assert.equal 1, spy.callCount

    it '_remove_safe (not last)', ->
      u.on 'remove_safe', spy
      u.fold = -> true
      u.options.last = false
      assert.equal false, u._remove_safe()
      assert.equal 0, spy.callCount

    it '_remove_safe (no fold)', ->
      u.on 'remove_safe', spy
      u.fold = -> false
      u.options.last = true
      assert.equal false, u._remove_safe()
      assert.equal 0, spy.callCount

    it '_remove_safe (no cards)', ->
      u.on 'remove_safe', spy
      u.fold = -> false
      u.options.last = true
      u.options.cards = []
      assert.equal true, u._remove_safe()
      assert.equal 1, spy.callCount


    describe 'round', ->
      beforeEach ->
        u.options.chips = 5
        u.options.win = 2
        u.options.rounds = 2

      it 'default', ->
        u.round({cards: 'c'})
        assert.equal(1, up.callCount)
        assert.equal(0, up.getCall(0).args[0].win)
        assert.equal(7, up.getCall(0).args[0].chips_last)
        assert.equal(7, up.getCall(0).args[0].chips)
        assert.equal(7, up.getCall(0).args[0].chips_cap)
        assert.equal('c', up.getCall(0).args[0].cards)
        assert.equal(3, up.getCall(0).args[0].rounds)

      it 'chips_cap', ->
        u.round({cards: 'c', chips_cap: 6})
        assert.equal(6, up.getCall(0).args[0].chips_cap)

      it 'chips_cap to big', ->
        u.round({cards: 'c', chips_cap: 16})
        assert.equal(7, up.getCall(0).args[0].chips_cap)

      it 'default_options', ->
        u.options_default.winner = 0
        u.options_default.talked = 'talk'
        u.options_round_reset = ['winner', 'talked']
        u.options.talked = 'to'
        u.options.winner = 2
        u.round('c')
        assert.equal(0, up.getCall(0).args[0].winner)
        assert.equal('talk', up.getCall(0).args[0].talked)

      it 'out', ->
        u.options.rounds_out = 2
        u.options.out = true
        u.round('c')
        assert.equal(3, up.getCall(0).args[0].rounds_out)


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


    describe 'bet', ->
      beforeEach ->
        u.options.chips = 20
        u.options.chips_cap = 10
        u.options.bet = 2

      it 'default', ->
        assert.equal(5, u.bet({bet: 5, command: 'bet'}))
        assert.equal(1, up.callCount)
        assert.deepEqual({chips_cap: 5, chips: 15, bet: 7, command: 'bet', talked: true}, up.getCall(0).args[0])

      it 'blind', ->
        u.bet({bet: 5, command: 'blind'})
        assert.deepEqual({chips_cap: 5, chips: 15, bet: 7, command: 'blind'}, up.getCall(0).args[0])

      it 'ante', ->
        u.bet({bet: 1, command: 'ante'})
        assert.equal false, 'talked' in Object.keys(up.getCall(0).args[0])

      it 'all_in', ->
        assert.equal(10, u.bet({bet: 15, command: 'blind'}))
        assert.deepEqual({chips_cap: 0, chips: 10, bet: 12, command: 'all_in'}, up.getCall(0).args[0])


    it 'bet_return', ->
      u.options.chips_cap = 10
      u.options.chips = 20
      u.options.bet = 10
      u.on 'bet_return', spy
      u.bet_return({bet: 5})
      assert.equal(1, up.callCount)
      assert.deepEqual({chips: 25, chips_cap: 15, bet: 5}, up.getCall(0).args[0])
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
      u.progress()
      assert.equal(1, up.callCount)
      assert.deepEqual({command: null, turn_history: [['x'], []], talked: false}, up.getCall(0).args[0])

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

    it 'action_require (no cards)', ->
      u.options.cards = []
      assert.equal(false, u.action_require(10))

    it 'out', ->
      u.out({out: true})
      assert.equal(1, up.callCount)
      assert.deepEqual({out: true}, up.getCall(0).args[0])

    it 'last', ->
      u.last({last: true})
      assert.equal(1, up.callCount)
      assert.deepEqual({last: true}, up.getCall(0).args[0])

    it 'readd', ->
      u.on 'readd', spy
      u.readd({chips: 1500})
      assert.equal(1, up.callCount)
      assert.deepEqual({last: false, chips: 1500}, up.getCall(0).args[0])
      assert.equal 1, spy.callCount
      assert.deepEqual {last: false, chips: 1500}, spy.getCall(0).args[0]

    it 'toJSON', ->
      u.options.cards = [1, 2]
      u.options.bet = 10
      u.options.chips_cap = 30
      assert.equal(10, u.toJSON().bet)
      assert.ok(Object.keys(u.toJSON()).indexOf('cards_board') is -1)
      assert.equal(2, u.toJSON().id)
      assert.equal(2, u.toJSON().position)
      assert.equal(50, u.toJSON().chips)
      assert.equal(30, u.toJSON().chips_cap)
      assert.equal(false, u.toJSON().out)
      assert.equal(false, u.toJSON().last)
      assert.deepEqual(['', ''], u.toJSON().cards)

    it 'toJSON (chips_cap same)', ->
      u.options.chips_cap = 50
      assert.equal false, 'chips_cap' in Object.keys(u.toJSON())

    it 'toJSON (showdown)', ->
      u.options.cards = [1, 2]
      u.options.showdown = true
      assert.deepEqual([1, 2], u.toJSON().cards)

    it 'toJSON (self)', ->
      u.options.cards = [1, 2]
      assert.deepEqual([1, 2], u.toJSON(2).cards)
      assert.equal(true, u.toJSON(2).hero)


  describe 'turn', ->
    commands = null
    beforeEach ->
      u.commands = sinon.fake.returns([['check'], ['call', 30], ['raise', 40, 500], ['bet', 40, 500]])
      commands = [['check'], ['call', 30], ['raise', 40, 500], ['bet', 40, 500]]
      u.bet = sinon.fake.returns(3)
      u.fold = sinon.spy()
      u.options.bet = 5
      u.options.turn_history = [['x'], []]
      u._remove_safe = sinon.spy()
      u.on 'turn', spy

    it 'check', ->
      u.options.command = 'ch'
      u.options.chips = 3
      u.turn(['check'], ['check'])
      assert.equal(1, u.bet.callCount)
      assert.deepEqual({bet: 0, command: 'check'}, u.bet.getCall(0).args[0])
      assert.equal(1, spy.callCount)
      assert.deepEqual({bet: 3, command: 'ch'}, spy.getCall(0).args[0])
      assert.deepEqual([['x'], ['x']], u.options.turn_history)
      assert.equal 1, u._remove_safe.callCount

    it 'call', ->
      u.turn(['call', 30], ['call', 500])
      assert.deepEqual({bet: 30, command: 'call'}, u.bet.getCall(0).args[0])
      assert.deepEqual([['x'], ['c']], u.options.turn_history)

    it 'raise', ->
      u.turn(['raise', 40, 500], ['raise', 50.5])
      assert.equal(50, u.bet.getCall(0).args[0].bet)

    it 'raise (no value)', ->
      u.turn(['raise', 40, 500], ['raise'])
      assert.equal(40, u.bet.getCall(0).args[0].bet)

    it 'raise (small)', ->
      u.turn(['raise', 40, 500], ['raise', 30])
      assert.equal(40, u.bet.getCall(0).args[0].bet)

    it 'raise (big)', ->
      u.turn(['raise', 40, 500], ['raise', 501])
      assert.equal(40, u.bet.getCall(0).args[0].bet)

    it 'bet', ->
      u.turn(['bet', 40, 500], ['bet', 50])
      assert.equal(50, u.bet.getCall(0).args[0].bet)

    it 'fold', ->
      u.turn(['fold'], ['fold'])
      assert.equal(0, u.bet.getCall(0).args[0].bet)


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
      u.options.chips_cap = 30
      assert.deepEqual(['fold'], u.commands({bet_max: 20})[0])
      assert.deepEqual(['call', 5], u.commands({bet_max: 20})[1])
      assert.deepEqual(['raise', 30], u.commands({bet_max: 20, bet_raise: 25})[2])

    it 'bet (chips not enough)', ->
      u.options.chips_cap = 5
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

    it 'bet (cap)', ->
      u.options.bet = 10
      assert.deepEqual(['check'], u.commands({bet_max: 10})[0])
      assert.deepEqual(['raise', 20], u.commands({bet_max: 10, cap: 20, bet_raise: 20})[1])

    it 'bet (cap more then chips)', ->
      u.options.bet = 10
      u.options.chips_cap = 15
      assert.deepEqual(['check'], u.commands({bet_max: 10})[0])
      assert.deepEqual(['raise', 15], u.commands({bet_max: 10, cap: 20, bet_raise: 20})[1])


  describe 'options bind', ->
    fn = null
    beforeEach ->
      fn = u.options_bind

    it 'rank update', ->
      u.options.cards = [1, 2]
      u.options.cards_board = [3, 4]
      fn['cards,cards_board'].bind(u)()
      assert.equal(1, rank_constructor.callCount)
      assert.deepEqual([3, 4, 1, 2], rank_constructor.getCall(0).args[0])
      assert.equal(1, up.callCount)
      assert.equal('rank', up.getCall(0).args[0].rank.rank)
      assert.equal('mes', up.getCall(0).args[0].rank.message)

    it 'rank update (no cards)', ->
      u.options.cards = []
      u.options.cards_board = []
      fn['cards,cards_board'].bind(u)()
      assert.equal(0, rank_constructor.callCount)
      assert.equal(null, up.getCall(0).args[0].rank)

    it 'out', ->
      u.options.out = true
      u.on 'out', spy
      fn['out'].bind(u)()
      assert.equal(1, spy.callCount)
      assert.deepEqual({out: true}, spy.getCall(0).args[0])

    it 'out (rounds_out reset)', ->
      u.options_update = sinon.spy()
      u.options.rounds_out = 1
      u.options.out = false
      fn['out'].bind(u)()
      assert.equal(1, u.options_update.callCount)
      assert.deepEqual({rounds_out: 0}, u.options_update.getCall(0).args[0])

    it 'out (rounds_out reset out)', ->
      u.options_update = sinon.spy()
      u.options.rounds_out = 2
      u.options.out = true
      fn['out'].bind(u)()
      assert.equal(0, u.options_update.callCount)

    it 'out (rounds_out reset zero)', ->
      u.options_update = sinon.spy()
      u.options.rounds_out = 0
      u.options.out = false
      fn['out'].bind(u)()
      assert.equal(0, u.options_update.callCount)

    it 'rounds_out', ->
      u.on 'rounds_out', spy
      u.options.rounds_out = 2
      fn['rounds_out'].bind(u)()
      assert.equal(1, spy.callCount)
      assert.deepEqual({rounds_out: 2}, spy.getCall(0).args[0])

    it 'last', ->
      u._remove_safe = sinon.fake.returns false
      u.on 'last', spy
      fn['last'].bind(u)()
      assert.equal(1, u._remove_safe.callCount)
      assert.equal(1, spy.callCount)

    it 'last (removed)', ->
      u._remove_safe = sinon.fake.returns true
      u.on 'last', spy
      fn['last'].bind(u)()
      assert.equal(0, spy.callCount)

    it 'bet', ->
      u.options.bet = 5
      u.on 'bet', spy
      fn['bet'].bind(u)()
      assert.equal(1, spy.callCount)
      assert.deepEqual({bet: 5}, spy.getCall(0).args[0])
