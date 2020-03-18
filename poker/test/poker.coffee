assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')


class Cards
  round: ->

class Rank
  compare: -> [0, 1]

Poker = proxyquire('../poker', {
  './cards':
    Cards: Cards
  './rank':
    PokerRank: Rank
}).Poker

Player = Poker::Player
Board = Poker::Board


describe 'Poker', ->
  clock = null
  spy = null
  spy2 = null
  p = null
  player1 = null
  player2 = null
  player3 = null
  beforeEach ->
    spy = sinon.spy()
    spy2 = sinon.spy()
    clock = sinon.useFakeTimers()
    p = new Poker
      blinds: [1, 2]
      players: [2, 3]
      timeout: 10
      chips: 1500
    p._cards.shuffle = sinon.spy()
    p._cards.deal = sinon.spy()
    p._board.round = sinon.spy()
    p._board.progress = sinon.spy()
    p._board.pot_total = sinon.fake.returns 5
    player1 = new Player({id: 1, chips: 20})
    player1.bet = sinon.spy()
    player1.round = sinon.spy()
    player1.options.cards = ['1', '11']
    player1.options.position = 0
    player1.action_require = -> true
    player2 = new Player({id: 2, chips: 15})
    player2.bet = sinon.spy()
    player2.round = sinon.spy()
    player2.options.cards = ['2', '22']
    player2.options.position = 1
    player2.action_require = -> true
    player3 = new Player({id: 3, chips: 10})
    player3.bet = sinon.spy()
    player3.round = sinon.spy()
    player3.options.cards = ['3', '33']
    player3.action_require = -> true
    Math.random = sinon.fake.returns(0)


  afterEach ->
    clock.restore()


  describe 'default', ->
    beforeEach ->
      p._progress = ->

    it 'constructor', ->
      assert.deepEqual([null, null, null], p._players)
      assert.deepEqual([1, 2], p._blinds)
      assert.deepEqual({}, p._players_ids)
      assert.equal(1500, p._chips_start)
      assert.equal(0, p._round_count)

    it 'contructor (default)', ->
      p = new Poker()
      assert.deepEqual([1, 2], p.options.blinds)
      assert.deepEqual([2, 9], p.options.players)
      assert.equal(10, p.options.timeout)
      assert.equal(false, p.options.autostart)
      assert.equal(1000, p.options.delay_progress)

    it 'constructor (users)', ->
      class Poker2 extends Poker
        player_add: -> spy.apply(this, arguments)
      new Poker2({users: [{id: 2}]})
      assert.equal(1, spy.callCount)
      assert.deepEqual({id: 2}, spy.getCall(0).args[0])

    it 'constructor (pot:return)', ->
      p._players = [null, player1]
      player1.bet_return = sinon.spy()
      p._board.emit 'pot:return', {pot: 10, position: 1}
      assert.equal(1, player1.bet_return.callCount)
      assert.deepEqual({bet: 10}, player1.bet_return.getCall(0).args[0])

    it 'constructor (pot)', ->
      p.on 'pot', spy
      p._board.emit 'pot:update', 'pot'
      assert.equal(1, spy.callCount)
      assert.equal('pot', spy.getCall(0).args[0])

    it 'cards change event', ->
      player1.options_update = sinon.spy()
      player2.options_update = sinon.spy()
      p._players = [null, player1, null, player2]
      p._board.options.cards = 'c1'
      p._board.emit 'change:cards'
      assert.equal 1, player1.options_update.callCount
      assert.deepEqual {cards_board: 'c1'}, player1.options_update.getCall(0).args[0]
      assert.equal true, player1.options_update.getCall(0).args[1]
      assert.equal 1, player2.options_update.callCount

    it 'progress event', ->
      p.on 'card', spy
      player1.progress = sinon.spy()
      player2.progress = sinon.spy()
      p._board.cards = sinon.spy()
      p._players = [null, player1, null, player2]
      p.emit 'progress', 'pa'
      assert.equal(1, player1.progress.callCount)
      assert.equal(1, player2.progress.callCount)
      assert.equal(1, p._board.progress.callCount)
      assert.equal('pa', p._board.progress.getCall(0).args[0])

    it '_player_position_next', ->
      p._players = [null, 'u', null, 'u']
      assert.equal(1, p._player_position_next(0))
      assert.equal(1, p._player_position_next(0))
      assert.equal(3, p._player_position_next(1))
      assert.equal(1, p._player_position_next(3))

    it '_player_position', ->
      p._players = [null, 'u', null, 'u']
      Math.random = -> 0.9999999
      assert.equal(2, p._player_position_free())
      Math.random = -> 0
      assert.equal(0, p._player_position_free())

    it '_player_position (none)', ->
      p._players = ['u', 'u', 'u', 'u']
      Math.random = sinon.spy()
      assert.equal(-1, p._player_position_free())
      assert.equal(0, Math.random.callCount)

    it 'is_full', ->
      p._players = ['u', 'u']
      assert.equal(true, p.is_full())
      p._players = ['u', null]
      assert.equal(false, p.is_full())

    it 'player_add', ->
      p._player_position_free = -> 0
      assert.equal true, p.player_add({id: 1, chips: 50})
      assert.equal(1, p._players[0].options.id)
      assert.equal(0, p._players[0].options.position)
      assert.equal(50, p._players[0].options.chips)
      assert.equal('fold', p._players[0].options.command)
      assert.deepEqual({1: 0}, p._players_ids)

    it 'player_add (default chips)', ->
      p._chips_start = 100
      p.player_add({id: 1})
      assert.equal(100, p._players[0].options.chips)

    it 'player_add (start)', ->
      p.start = sinon.spy()
      p.options.autostart = true
      p.player_add({id: 1, position: 0})
      assert.equal(0, p.start.callCount)
      player = p.player_add({id: 2, position: 1})
      assert.equal(1, p.start.callCount)
      p._player_remove({options: {id: 2, position: 1} })
      p._started = true
      p.player_add({id: 2})
      assert.equal(1, p.start.callCount)

    it 'player_add (disable autostart)', ->
      p.start = sinon.spy()
      p.player_add({id: 1, position: 0})
      p.player_add({id: 2, position: 1})
      assert.equal(0, p.start.callCount)

    it 'player_add (event)', ->
      p.on 'player:add', spy
      p.player_add({id: 1})
      assert.equal(1, spy.callCount)
      assert.equal(1, spy.getCall(0).args[0].id)
      assert.equal(1, spy.getCall(0).args[1][1].id)
      assert.equal(true, spy.getCall(0).args[1][1].hero)

    it 'player_add (bet)', ->
      p.player_add({id: 1})
      p.player_add({id: 2})
      p._board.bet = sinon.spy()
      p._players[0].options.command = 'blind'
      p._players[0].emit 'bet', {bet: 10}
      assert.equal(1, p._board.bet.callCount)
      assert.deepEqual({bet: 10, position: 0, command: 'blind'}, p._board.bet.getCall(0).args[0])

    it 'player_add (turn)', ->
      p.player_add({id: 1})
      p.on 'turn', spy
      p._players[0].emit 'turn', {command: 'allin'}
      assert.equal(1, spy.callCount)
      assert.deepEqual({command: 'allin', position: 0}, spy.getCall(0).args[0])

    it 'player_add (win)', ->
      p.player_add({id: 1})
      p.on 'win', spy
      p._players[0].emit 'win', {p: 'a'}
      assert.equal(1, spy.callCount)
      assert.deepEqual({p: 'a', position: 0}, spy.getCall(0).args[0])

    it 'player_add (bet_return)', ->
      p.player_add({id: 1})
      p.on 'bet_return', spy
      p._players[0].emit 'bet_return', {bet: 2}
      assert.equal(1, spy.callCount)
      assert.deepEqual({bet: 2, position: 0}, spy.getCall(0).args[0])

    it 'player_add (out)', ->
      p.player_add({id: 1})
      p.on 'out', spy
      p._players[0].emit 'out', {out: true}
      assert.equal(1, spy.callCount)
      assert.deepEqual({out: true, position: 0}, spy.getCall(0).args[0])

    it 'player_add (last)', ->
      p.player_add({id: 1})
      p.on 'last', spy
      p._players[0].emit 'last', {last: true}
      assert.equal(1, spy.callCount)
      assert.deepEqual({last: true, position: 0}, spy.getCall(0).args[0])

    it 'player_add (readd)', ->
      p.player_add({id: 1})
      p.on 'readd', spy
      p._players[0].emit 'readd', {chips: 1500}
      assert.equal(1, spy.callCount)
      assert.deepEqual({chips: 1500, position: 0}, spy.getCall(0).args[0])

    it 'player_add (no position)', ->
      p._player_position_free = -> -1
      p._players = [null]
      assert.equal false, p.player_add({id: 1})
      assert.deepEqual [null], p._players

    it 'player_add (remove_safe)', ->
      p._player_remove_options = sinon.fake.returns('op')
      p.on 'player:remove_safe', spy
      p.player_add({id: 1})
      p._players[0].emit 'remove_safe'
      assert.equal 1, p._player_remove_options.callCount
      assert.equal 1, p._player_remove_options.getCall(0).args[0].options.id
      assert.equal 1, spy.callCount
      assert.equal 'op', spy.getCall(0).args[0]

    it 'player_add (rounds_out_max)', ->
      p.player_add({id: 1})
      p.last = sinon.spy()
      p.options.rounds_out_max = 1
      p._players[0].emit 'rounds_out', {rounds_out: 2}
      assert.equal(1, p.last.callCount)
      assert.deepEqual({user_id: 1, last: true}, p.last.getCall(0).args[0])

    it 'player_add (rounds_out_max disabled)', ->
      p.player_add({id: 1})
      p.last = sinon.spy()
      p.options.rounds_out_max = 0
      p._players[0].emit 'rounds_out', {rounds_out: 2}
      assert.equal(0, p.last.callCount)

    it 'player_add (rounds_out_max not enough)', ->
      p.player_add({id: 1})
      p.last = sinon.spy()
      p.options.rounds_out_max = 1
      p._players[0].emit 'rounds_out', {rounds_out: 1}
      assert.equal(0, p.last.callCount)

    it 'player_get', ->
      p._player_position_free = -> 1
      p.player_add({id: 2})
      assert.equal(2, p.player_get(2).options.id)
      assert.equal(null, p.player_get(3))

    it '_player_remove_options', ->
      assert.deepEqual({id: 5, chips_last: 200, chips_start: 5, rounds: 2, position: 1, chips: 10},
        p._player_remove_options({options: {id: 5, chips_last: 200, chips_start: 5, rounds: 2, position: 1}, budget: -> 10 })
      )

    it '_player_remove', ->
      p._player_remove_options = sinon.fake.returns('op')
      p._players = [null, 'u']
      p._players_ids = {5: 1}
      p.on 'player:remove', spy
      p._player_remove({options: {position: 1, id: 5} })
      assert.equal(1, p._player_remove_options.callCount)
      assert.equal('u', p._player_remove_options.getCall(0).args[0])
      assert.deepEqual([null, null], p._players)
      assert.equal(1, spy.callCount)
      assert.deepEqual('op', spy.getCall(0).args[0])
      assert.deepEqual({}, p._players_ids)

    it 'player_remove', ->
      p.player_get = sinon.fake.returns('p')
      p._player_remove = sinon.spy()
      p.player_remove(5)
      assert.equal(1, p.player_get.callCount)
      assert.equal(5, p.player_get.getCall(0).args[0])
      assert.equal(1, p._player_remove.callCount)
      assert.equal('p', p._player_remove.getCall(0).args[0])

    it 'players', ->
      p._players = [null, 'p']
      assert.deepEqual(['p'], p.players())

    it 'players (filter)', ->
      spy = sinon.fake.returns(true)
      p._players = [null, {id: 5, filter: spy}, {id: 6, filter: -> false}]
      players_filter = p.players({fold: true})
      assert.equal(1, players_filter.length)
      assert.equal(5, players_filter[0].id)
      assert.equal(1, spy.callCount)
      assert.deepEqual({fold: true}, spy.getCall(0).args[0])

    it 'start', ->
      p.round = sinon.spy()
      p._dealer_next = -> true
      p._emit_start_params = sinon.fake.returns [1, 2]
      p.on 'start', spy
      p.start()
      assert.equal(1, spy.callCount)
      assert.equal(1, spy.getCall(0).args[0])
      assert.equal(2, spy.getCall(0).args[1])
      assert.equal(true, p._started)
      assert.equal(1, p.round.callCount)


    describe 'round', ->
      beforeEach ->
        p._emit_round_params = ->
        p._showdown_call = true
        p._dealer = 0
        p._players = [player1, player2, player3]
        p._progress = sinon.spy()
        p._blinds = [2, 4]
        p._round_count = 1

      it 'default', ->
        p.round()
        assert.equal(2, p._round_count)
        assert.equal(1, p._board.round.callCount)
        assert.deepEqual({bet_raise_default: 4, show_first: 2}, p._board.round.getCall(0).args[0])
        assert.equal(1, p._cards.shuffle.callCount)
        assert.equal(1, player3.bet.callCount)
        assert.deepEqual({bet: 2, command: 'blind'}, player3.bet.getCall(0).args[0])
        assert.equal(1, player1.bet.callCount)
        assert.deepEqual({bet: 4, command: 'blind'}, player1.bet.getCall(0).args[0])
        assert.equal(1, p._dealer)
        assert.equal(0, p._waiting)
        assert.deepEqual([2, 0], p._blinds_position)
        assert.equal(0, p._progress_round)
        assert.equal(1, p._progress.callCount)
        assert.equal(false, p._showdown_call)

      it 'bet_raise_blind', ->
        p.options.bet_raise_blind = 5
        p.round()
        assert.equal 20, p._board.round.getCall(0).args[0].bet_raise_default

      it 'blinds_next', ->
        p._blinds_next = [2, 4]
        p._players = [player1, player2]
        p.round()
        assert.deepEqual([2, 4], p._blinds)
        assert.deepEqual(null, p._blinds_next)
        p.round()
        assert.deepEqual([2, 4], p._blinds)

      it '2 players', ->
        p._players = [player1, player2]
        p.round()
        assert.equal(4, player1.bet.getCall(0).args[0].bet)
        assert.equal(2, player2.bet.getCall(0).args[0].bet)
        assert.equal(0, p._waiting)
        assert.deepEqual([1, 0], p._blinds_position)

      it 'players', ->
        p._players = [player1, player2]
        p._round_player_addon =  sinon.fake.returns('add')
        p.round()
        assert.equal(2, p._round_player_addon.callCount)
        assert.deepEqual(player1, p._round_player_addon.getCall(0).args[0])
        assert.equal(1, player1.round.callCount)
        assert.equal(1, player2.round.callCount)
        assert.equal(1, player1.round.callCount)
        assert.equal('add', player1.round.getCall(0).args[0])
        assert.equal(1, player2.round.callCount)
        assert.equal('add', player2.round.getCall(0).args[0])

      it 'emit', ->
        p._players = [player1, player2]
        player1.options.bet = 1
        player1.options.command = 'c'
        player2.options.bet = 2
        player2.options.command = 'c2'
        a = 0
        p._cards.deal = ->
          a++
          a
        p._emit_round_params = sinon.fake.returns [1, 2]
        p.on 'round', spy
        p.round()
        assert.equal(1, spy.callCount)
        assert.equal(1, spy.getCall(0).args[0])
        assert.equal(2, spy.getCall(0).args[1])


    it '_round_player_addon', ->
      p._cards.deal = sinon.fake.returns [1, 2]
      assert.deepEqual({cards: [1, 2]}, p._round_player_addon())
      assert.equal(1, p._cards.deal.callCount)
      assert.equal(2, p._cards.deal.getCall(0).args[0])

    it '_emit_round_params', ->
      p._players = [player1, player2, null]
      p.players = -> [player1, player2]
      p._blinds_position = [0, 1]
      p._dealer = 0
      player1.options.command = 'c'
      player1.options.bet = 1
      player2.options.command = 'c2'
      player2.options.bet = 2
      params = p._emit_round_params()
      assert.deepEqual({dealer: 0, blinds: [{position: 0, bet: 1, command: 'c'}, {position: 1, bet: 2, command: 'c2'}], players: [{cards: ['', '']}, {cards: ['', '']}, null] }, params[0])
      assert.deepEqual({
        1: {players: [ {cards: ['1', '11']}, {cards: ['', '']}, null ] }
        2: {players: [ {cards: ['', '']}, {cards: ['2', '22']}, null ] }
      }, params[1])

    it '_emit_round_params (rake)', ->
      p._rake = 5
      p._blinds_position = []
      params = p._emit_round_params()
      assert.equal(5, params[0].rake)

    it 'round (rake calc)', ->
      p._rake_calc = sinon.fake.returns 'rr'
      p._players = [player1, player2, null]
      p.round()
      assert.equal(1, p._rake_calc.callCount)
      assert.equal(2, p._rake_calc.getCall(0).args[0])
      assert.equal('rr', p._rake)

    it 'round (no rake)', ->
      p._rake_calc = sinon.fake.returns false
      p._players = [player1, player2]
      p.round()
      assert.equal(false, p._rake)

    it '_rake_calc', ->
      p.options.rake = {percent: 5, progress: 1, cap: 30}
      assert.deepEqual({percent: 5, progress: 1, cap: 30}, p._rake_calc())

    it '_rake_calc (dynamic cap)', ->
      p.options.rake = {percent: 5, progress: 1, cap: [ [2, 30], [3, 40], [5, 50] ]}
      assert.deepEqual(30, p._rake_calc(2).cap)
      assert.deepEqual(40, p._rake_calc(4).cap)
      assert.deepEqual(50, p._rake_calc(5).cap)
      assert.deepEqual(50, p._rake_calc(8).cap)

    it '_rake_calc (no options)', ->
      assert.equal(false, p._rake_calc())

    it 'blinds', ->
      p.blinds([15, 30])
      assert.deepEqual([15, 30], p._blinds_next)

    it '_waiting_commands', ->
      p._progress_round = 5
      p.players = sinon.fake.returns([1, 2])
      p._waiting = 1
      p._board.bet_max = -> 5
      p._board.bet_raise = -> 3
      p._board.bet_raise_count = sinon.fake.returns 6
      player1.options.bet = 1
      p._players = [null, player1]
      player1.commands = sinon.fake.returns('commands')
      assert.deepEqual({commands: 'commands'}, p._waiting_commands())
      assert.equal(1, player1.commands.callCount)
      assert.deepEqual({bet_max: 5, cap: null, bet_raise: 3, bet_raise_count: 6, stacks: 2, blind: 2, pot: 5, bet_total: 1, progress: 5}, player1.commands.getCall(0).args[0])
      assert.equal(1, p.players.callCount)
      assert.deepEqual({fold: false, all_in: false}, p.players.getCall(0).args[0])
      assert.equal 1, p._board.pot_total.callCount

    it '_waiting_commands (cap)', ->
      p.players = sinon.fake.returns([1, 2])
      p._progress_round = 0
      p.options.cap = [2, 3]
      p._blinds = [5, 10]
      p._waiting = 1
      p._board.bet_max = -> 5
      p._board.bet_raise = -> 3
      p._players = [null, player1]
      player1.commands = sinon.fake.returns('commands')
      p._waiting_commands()
      assert.equal(20, player1.commands.getCall(0).args[0].cap)
      p._progress_round = 1
      p._waiting_commands()
      assert.equal(30, player1.commands.getCall(1).args[0].cap)

    it '_get_ask', ->
      p._timeout_activity_callback = 2
      p._activity_timeout_left = sinon.fake.returns(5)
      p._waiting = 2
      p._players = [null, null, player1]
      p._waiting_commands = -> {commands: 'commands'}
      assert.deepEqual([{position: 2, timeout: 5}, 1: {commands: 'commands'}], p._get_ask())

    it '_get_ask (no activity)', ->
      assert.equal(null, p._get_ask())

    it '_emit_ask', ->
      p._players = [player1, player2]
      p.on 'ask', spy
      p._get_ask = -> ['1', '2']
      p._waiting = 1
      p._emit_ask(0)
      assert.equal(0, p._waiting)
      assert.equal(1, spy.callCount)
      assert.equal('1', spy.getCall(0).args[0])
      assert.equal('2', spy.getCall(0).args[1])

    it '_emit_ask (timeout)', ->
      p._players = [player1, player2]
      p._activity = sinon.spy()
      p._emit_ask(1)
      assert.equal(1, p._activity.callCount)

    it '_emit_ask (only one command)', ->
      p._players = [player1, player2]
      p._waiting_commands = sinon.fake.returns({commands: [['check']]})
      p.turn = sinon.spy()
      p._emit_ask(1)
      assert.equal(1, p._waiting_commands.callCount)
      assert.equal(1, p.turn.callCount)
      assert.deepEqual(['check'], p.turn.getCall(0).args[0])

    it '_emit_ask (out)', ->
      p._waiting_commands = sinon.fake.returns({commands: [['check'], ['call']]})
      player1.options.out = true
      p._waiting = 0
      p._players = [player1]
      p._activity = sinon.spy()
      p.turn = sinon.spy()
      p._emit_ask(0)
      assert.equal(0, p._activity.callCount)
      assert.equal(1, p.turn.callCount)

    it '_showdown', ->
      player1.options.position = 0
      player1.showdown = sinon.fake.returns('sh')
      p.players = sinon.fake.returns([player1])
      p.on 'showdown', spy
      p._showdown()
      assert.equal(1, p.players.callCount)
      assert.deepEqual({fold: false}, p.players.getCall(0).args[0])
      assert.equal(1, spy.callCount)
      assert.deepEqual([{position: 0, cards: 'sh'}], spy.getCall(0).args[0])

    it '_activity', ->
      p.turn = sinon.spy()
      p._activity()
      assert.equal(10 * 1000, p._timeout_activity_timeout)
      clock.tick(1000 * 10)
      assert.equal(0, p.turn.callCount)
      clock.tick(1000 * 2)
      assert.equal(1, p.turn.callCount)

    it '_activity (custom timeout)', ->
      p._activity(40)
      assert.equal(40, p._timeout_activity_timeout)

    it '_activity_timeout_left', ->
      p._timeout_activity_timeout = 10 * 1000
      p._timeout_activity_timeout_start = new Date()
      assert.equal(10, p._activity_timeout_left())
      clock.tick(1000 * 5 + 400)
      assert.equal(5, p._activity_timeout_left())
      clock.tick(200)
      assert.equal(4, p._activity_timeout_left())
      clock.tick(1000 * 6)
      assert.equal(1, p._activity_timeout_left())

    it '_activity_clear', ->
      p.turn = sinon.spy()
      p._activity()
      clock.tick(1000 * 10)
      assert.ok(!!p._timeout_activity_callback)
      p._activity_clear()
      clock.tick(1000 * 2)
      assert.equal(0, p.turn.callCount)
      assert.ok(!p._timeout_activity_callback)

    it 'toJSON', ->
      player1.toJSON = sinon.fake.returns('pjson')
      p._board.toJSON = sinon.fake.returns('bjson')
      p._dealer = 'd'
      p._progress_round = 'p'
      p._get_ask = -> [ {a: 'sk'}, {1: {s: 'k'}} ]
      p._players = [null, player1, null]
      json = p.toJSON(5)
      assert.deepEqual([null, 'pjson', null], json.players)
      assert.equal('d', json.dealer)
      assert.equal('p', json.progress)
      assert.deepEqual([1, 2], json.blinds)
      assert.equal(1, player1.toJSON.callCount)
      assert.equal(5, player1.toJSON.getCall(0).args[0])
      assert.deepEqual({a: 'sk'}, json.ask)
      assert.deepEqual({a: 'sk', s: 'k'}, p.toJSON(1).ask)

    it 'toJSON (no ask)', ->
      p._get_ask = -> null
      json = p.toJSON()
      assert.ok(!('ask' of json))


  describe 'commands', ->
    beforeEach ->
      p._started = true
      p._waiting = 1
      p._players_ids = {5: 1}
      p._players = [null, player1]
      p._progress = sinon.spy()
      p._activity_clear = sinon.spy()
      player1.turn = sinon.fake.returns(true)
      player1.out = sinon.spy()
      player1.last = sinon.spy()
      p._board =
        bet_max: -> 'bm'
        bet_raise: -> 'br'
      p._started = true

    it 'last', ->
      p._player_remove = sinon.spy()
      p.last({user_id: 5, last: true})
      assert.equal(1, player1.last.callCount)
      assert.deepEqual({last: true}, player1.last.getCall(0).args[0])
      assert.equal(0, p._player_remove.callCount)

    it 'last (not started)', ->
      p._started = false
      p._player_remove = sinon.spy()
      p.last({user_id: 5, last: true})
      assert.equal(0, player1.last.callCount)
      assert.equal(1, p._player_remove.callCount)
      assert.deepEqual(player1, p._player_remove.getCall(0).args[0])

    it 'last (round_last enable)', ->
      p._round_last = true
      p._player_remove = sinon.spy()
      p.last({user_id: 5, last: false})
      assert.equal(0, player1.last.callCount)

    it 'round_last', ->
      p.last = sinon.spy()
      p.round_last()
      assert.equal(true, p._round_last)
      assert.equal(1, p.last.callCount)
      assert.deepEqual({user_id: 5, last: true}, p.last.getCall(0).args[0])

    it 'out', ->
      p.out({user_id: 5, out: true})
      assert.equal(1, player1.out.callCount)
      assert.deepEqual({out: true}, player1.out.getCall(0).args[0])

    it 'out (turn active)', ->
      p.turn = sinon.spy()
      p.waiting = -> 2
      p.out({user_id: 5, out: true})
      assert.equal(0, p.turn.callCount)
      p.out({user_id: 5, out: false})
      assert.equal(0, p.turn.callCount)
      p.waiting = -> 5
      p.out({user_id: 5, out: true})
      assert.equal(1, p.turn.callCount)

    it 'out (not started)', ->
      p._started = false
      p.turn = sinon.spy()
      p.out({user_id: 5, out: true})
      assert.equal(0, p.turn.callCount)

    it 'waiting', ->
      p._timeout_activity_callback = 's'
      player1.options.id = 5
      assert.equal(5, p.waiting())
      p._timeout_activity_callback = null
      assert.equal(null, p.waiting())


  describe 'turn', ->
    beforeEach ->
      p._waiting_commands = sinon.fake.returns({commands: [['boom', 2], ['bem', 2, 5]]})
      p._waiting = 1
      p._activity_clear = sinon.spy()
      p._progress = sinon.spy()
      p._players = [null, player1]
      p._progress_round = 0
      player1.out = sinon.spy()
      player1.turn = sinon.fake.returns(true)
      player1.options.out = true

    it 'default', ->
      p.turn(['bem'])
      assert.equal(0, player1.out.callCount)
      assert.equal(1, player1.turn.callCount)
      assert.deepEqual(['bem', 2, 5], player1.turn.getCall(0).args[0])
      assert.deepEqual(['bem'], player1.turn.getCall(0).args[1])
      assert.equal(1, p._progress.callCount)
      assert.equal(1, p._activity_clear.callCount)

    it 'command not found', ->
      p.turn(['bum'])
      assert.equal(1, player1.out.callCount)
      assert.deepEqual(['boom', 2], player1.turn.getCall(0).args[0])
      assert.deepEqual(['boom', 2], player1.turn.getCall(0).args[1])

    it 'command empty', ->
      p.turn()
      assert.equal(1, player1.out.callCount)
      assert.deepEqual(['boom', 2], player1.turn.getCall(0).args[0])
      assert.deepEqual(['boom', 2], player1.turn.getCall(0).args[1])

    it 'command empty (auto fold)', ->
      p._waiting_commands = sinon.fake.returns({commands: [['check'], ['bet', 2, 5]]})
      p.turn()
      assert.deepEqual(['check'], player1.turn.getCall(0).args[0])
      assert.deepEqual(['fold'], player1.turn.getCall(0).args[1])

    it 'command empty (auto fold) no check', ->
      p._waiting_commands = sinon.fake.returns({commands: [['notcheck'], ['bet', 2, 5]]})
      p.turn()
      assert.notEqual('fold', player1.turn.getCall(0).args[1][0])

    it 'command empty (auto fold) not out', ->
      player1.options.out = false
      p._waiting_commands = sinon.fake.returns({commands: [['check'], ['bet', 2, 5]]})
      p.turn()
      assert.notEqual('fold', player1.turn.getCall(0).args[1][0])

    it 'command empty (auto fold) other rounds', ->
      p._progress_round = 1
      p._waiting_commands = sinon.fake.returns({commands: [['check'], ['bet', 2, 5]]})
      p.turn()
      assert.notEqual('fold', player1.turn.getCall(0).args[1][0])

    it 'command same', ->
      p._waiting_commands = sinon.fake.returns({commands: [['boom', 2], ['boom', 5]]})
      p.turn(['boom', 5])
      assert.deepEqual(['boom', 5], player1.turn.getCall(0).args[0])

    it 'command same (not found)', ->
      p._waiting_commands = sinon.fake.returns({commands: [['boom', 2], ['boom', 5]]})
      p.turn(['boom'])
      assert.deepEqual(['boom', 2], player1.turn.getCall(0).args[0])


  describe '_progress_action', ->
    beforeEach ->
      p._players = [player1, player2, player3]
      p._waiting = 0
      p._emit_ask = sinon.spy()
      p._board =
        bet_max: -> 5
      p.players = sinon.fake.returns([1, 2])
      p._round_end = sinon.spy()
      p._progress_pot = sinon.spy()
      player1.action_require = sinon.fake.returns(false)
      player2.action_require = sinon.fake.returns(false)
      player3.action_require = sinon.fake.returns(false)

    it '_progess_action', ->
      assert.equal(false, p._progress_action())

    it '_progress_action (true)', ->
      player3.action_require = sinon.fake.returns(true)
      assert.equal(true, p._progress_action())
      assert.equal(1, player2.action_require.callCount)
      assert.equal(5, player2.action_require.getCall(0).args[0])
      assert.equal(1, player3.action_require.callCount)
      assert.equal(0, player1.action_require.callCount)
      assert.equal(1, p._emit_ask.callCount)
      assert.equal(2, p._emit_ask.getCall(0).args[0])

    it '_progress_action (showdown)', ->
      player3.action_require = sinon.fake.returns(true)
      p._showdown_call = true
      assert.equal(false, p._progress_action())
      assert.equal(0, player2.action_require.callCount)

    it '_progress_action (fold)', ->
      p.players = sinon.fake.returns([1])
      player3.action_require = sinon.fake.returns(true)
      assert.equal(false, p._progress_action())
      assert.equal(0, player2.action_require.callCount)
      assert.equal(1, p.players.callCount)
      assert.deepEqual({fold: false}, p.players.getCall(0).args[0])

    it 'action required', ->
      player3.action_require = sinon.fake.returns(true)
      p._progress_pot = sinon.spy()
      p._progress_action = sinon.fake.returns(true)
      p._progress(->)
      assert.equal(1, p._progress_action.callCount)
      assert.equal(0, p._progress_pot.callCount)
      assert.equal(0, p._round_end.callCount)


  describe 'progress', ->
    beforeEach ->
      p._progress_round = 0
      p._waiting = 0
      p._dealer = 1
      p._board =
        bet_max: -> 5
        cards: sinon.spy()
        pot: ->
        progress: ->
      p._cards.deal = sinon.fake.returns 'ca'
      p.players = sinon.fake.returns([{progress: ->}, {progress: ->}])
      p._round_end = sinon.spy()
      p._progress_pot = sinon.spy()
      p._progress_action = sinon.fake.returns(false)

    it 'pot', ->
      p._progress_pot = sinon.spy()
      p._progress(->)
      assert.equal(1, p._progress_pot.callCount)

    it 'one left', ->
      p.players = sinon.fake.returns([1])
      p._round_end = sinon.fake.returns('re')
      assert.equal('re', p._progress())
      assert.equal(1, p._round_end.callCount)
      assert.equal(1, p.players.callCount)
      assert.deepEqual({fold: false}, p.players.getCall(0).args[0])

    it 'one left with chips', ->
      p.players = sinon.stub()
      p.players.withArgs({fold: false}).returns([1, 2])
      p.players.withArgs({fold: false, all_in: false}).returns([])
      p._showdown = sinon.spy()
      p._progress_round = 0
      sinon.spy p, '_progress'
      p._progress('callback')
      assert.equal(0, p._progress_round)
      assert.equal(2, p._progress.callCount)
      assert.equal('callback', p._progress.getCall(1).args[0])
      assert.equal(1, p._showdown.callCount)
      assert.equal(true, p._showdown_call)

    it 'one left with chips (second call)', ->
      p.players = sinon.stub()
      p.players.returns([{progress: ->}, {progress: ->}])
      p.players.withArgs({fold: false}).returns([1, 2])
      p.players.withArgs({fold: false, all_in: false}).returns([])
      p._showdown = sinon.spy()
      p._progress_round = 0
      p._showdown_call = true
      p._progress(->)
      assert.equal(1, p._progress_round)
      assert.equal(0, p._showdown.callCount)

    it 'showdown', ->
      p._progress_round = 3
      p._round_end = sinon.fake.returns('sd')
      assert.equal('sd', p._progress())
      assert.equal(1, p._round_end.callCount)

    it 'flop', ->
      p.on 'progress', spy
      p._progress_round = 0
      p._progress(->)
      assert.equal(1, spy.callCount)
      assert.deepEqual({cards: 'ca'}, spy.getCall(0).args[0])
      assert.equal(1, p._progress_round)
      assert.equal(1, p._cards.deal.callCount)
      assert.equal(3, p._cards.deal.getCall(0).args[0])

    it 'flop (waiting)', ->
      p._dealer = 5
      p._progress(spy)
      assert.equal(5, p._waiting)
      assert.equal(1, spy.callCount)
      assert.deepEqual(spy, spy.getCall(0).args[0])

    it 'turn/river', ->
      p._progress_round = 1
      p.on 'progress', spy
      p._progress(->)
      assert.equal(1, p._cards.deal.getCall(0).args[0])

    it 'delay', ->
      p._progress(->)
      p._progress(spy)
      assert.equal(0, spy.callCount)
      clock.tick(1500)
      assert.equal(1, spy.callCount)
      assert.deepEqual(spy, spy.getCall(0).args[0])

    it 'delay disabled', ->
      p.options.delay_progress = 0
      p._progress(->)
      p._progress(spy)
      assert.equal(1, spy.callCount)


  describe 'pot', ->
    pot = null
    beforeEach ->
      p._players = [player1, null, player2, null]
      p._board.pot = pot = sinon.spy()
      player1.bet_pot = sinon.fake.returns(9)
      player1.options.position = 0
      player1.fold = -> true
      player2.bet_pot = sinon.fake.returns(10)
      player2.options.position = 2

    it 'default', ->
      p._progress_pot()
      assert.equal(1, player1.bet_pot.callCount)
      assert.equal(1, player2.bet_pot.callCount)
      assert.equal(1, pot.callCount)
      assert.deepEqual([{position: 0, fold: true, bet: 9}, {position: 2, fold: false, bet: 10}], pot.getCall(0).args[0])

    it 'all zero bet', ->
      player1.bet_pot = sinon.fake.returns(0)
      p._progress_pot()
      assert.equal(1, pot.callCount)
      player2.bet_pot = sinon.fake.returns(0)
      p._progress_pot()
      assert.equal(1, pot.callCount)


  describe 'round end', ->
    pot_devide = null
    compare = null
    beforeEach ->
      p._board.pot_devide = pot_devide = sinon.fake.returns([
        {pot: 15, positions: [2, 4, 5], winners: [{position: 2, win: 1}, {position: 4, win: 1}], showdown: [5, 2, 4]}
      ])
      Rank::compare = compare = sinon.fake.returns([ [1], [0] ])
      player1.rank = sinon.fake.returns({rank: 'r1'})
      player1.options.position = 2
      player1.win = sinon.spy()
      player2.rank = sinon.fake.returns({rank: 'r2'})
      player2.options.position = 4
      player2.win = sinon.spy()
      player3.options.position = 5
      player3.win = sinon.spy()
      p._players = [null, null, player1, null, player2, player3]
      p.players = sinon.stub()
      p.players.withArgs({fold: false}).returns([player1, player2])
      p.players.withArgs().returns([player2, player3])
      p.on 'end', spy

    it 'default', ->
      p._progress_round = 1
      p._rake = {percent: 5, progress: 1}
      p._round_end()
      assert.equal(1, player1.rank.callCount)
      assert.equal(1, compare.callCount)
      assert.deepEqual(['r1', 'r2'], compare.getCall(0).args[0])
      assert.equal(1, pot_devide.callCount)
      assert.deepEqual([ [4], [2] ], pot_devide.getCall(0).args[0])
      assert.deepEqual({percent: 5, progress: 1}, pot_devide.getCall(0).args[1])
      assert.equal(0, spy.callCount)

    it 'rake (not progress)', ->
      p._rake = {percent: 5, progress: 1}
      p._progress_round = 0
      p._round_end()
      assert.deepEqual(false, pot_devide.getCall(0).args[1])

    it 'rake (false)', ->
      p._rake = false
      p._round_end()
      assert.deepEqual(false, pot_devide.getCall(0).args[1])

    it 'one player', ->
      p.players = sinon.fake.returns([player1])
      p._round_end()
      assert.equal(0, compare.callCount)
      assert.equal(1, pot_devide.callCount)
      assert.deepEqual([ [2] ], pot_devide.getCall(0).args[0])

    it 'calculate pot winners', ->
      p._board.pot_devide = sinon.fake.returns([
        {pot: 11, positions: [2, 4, 5], winners: [{position: 2, win: 5}, {position: 4, win: 6}], showdown: []}
      ])
      player1.win = sinon.spy()
      p._round_end()
      assert.equal(1, player1.win.callCount)
      assert.equal(1, player2.win.callCount)
      assert.deepEqual({win: 5}, player1.win.getCall(0).args[0])
      assert.equal(true, player1.win.getCall(0).args[1])
      assert.deepEqual({win: 6}, player2.win.getCall(0).args[0])

    it 'emit', ->
      spy = sinon.spy()
      p.on 'round_end', spy
      player1.showdown = sinon.fake.returns('s1')
      player2.showdown = sinon.fake.returns('s2')
      player3.showdown = sinon.fake.returns('s3')
      p._round_end()
      assert.equal(1, spy.callCount)
      assert.deepEqual([ {position: 5, cards: 's3'}, {position: 2, cards: 's1'}, {position: 4, cards: 's2'} ], spy.getCall(0).args[0].pots[0].showdown)
      assert.deepEqual([], spy.getCall(0).args[0].players_remove)

    it 'emit with loosers', ->
      round_end = sinon.spy()
      player1.budget = -> 1
      player2.budget = -> 1
      player3.budget = -> 0
      player3.options.chips_last = 100
      p.on 'round_end', round_end
      p._round_end()
      assert.deepEqual([ {position: 5, chips_last: 100, chips: 0, id: 3} ], round_end.getCall(0).args[0].players_remove)
      p._player_remove = sinon.spy()
      clock.tick(3000)
      assert.equal(1, p._player_remove.callCount)
      assert.equal(3, p._player_remove.getCall(0).args[0].options.id)

    it 'emit with last', ->
      round_end = sinon.spy()
      player1.budget = -> 1
      player2.budget = -> 1
      player3.budget = -> 1
      player3.options.last = true
      p.on 'round_end', round_end
      p._round_end()
      p._player_remove = sinon.spy()
      clock.tick(3000)
      assert.equal(1, p._player_remove.callCount)
      assert.equal(3, p._player_remove.getCall(0).args[0].options.id)

    it 'next round delay', ->
      p.round = sinon.spy()
      p.options.players[0] = 2
      p._round_end()
      assert.equal(0, p.round.callCount)
      clock.tick(3000)
      assert.equal(1, p.round.callCount)
      assert.equal(0, spy.callCount)

    it 'next round not enough players', ->
      p.options.players[0] = 3
      p.round = sinon.spy()
      p._round_end()
      clock.tick(3000)
      assert.equal(1, spy.callCount)
      assert.equal(0, p.round.callCount)
      assert.equal(false, p._started)
