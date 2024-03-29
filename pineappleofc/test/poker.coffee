assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')
EventEmitter = require('events').EventEmitter
_cloneDeep = require('lodash').cloneDeep


class Player extends EventEmitter
  constructor: (options)->
    super()
    @options = options

class Cards
  constructor: ->
    @initc = true
  shuffle: ->
  deal: (v)-> return v

PokerOFCRank_compare = ->
class PokerOFCRank
  compare: -> PokerOFCRank_compare.apply(@, arguments)

PokerPineappleOFC =  proxyquire('../poker', {
  './player':
    PokerPineappleOFCPlayer: Player
  './cards':
    CardsId: Cards
  './rank':
    PokerOFCRank: PokerOFCRank
}).PokerPineappleOFC


describe 'PokerPineappleOFC', ->
  o = null
  spy = null
  up = null
  clock = null
  player1 = null
  player2 = null
  beforeEach ->
    spy = sinon.spy()
    o = new PokerPineappleOFC()
    o.options_update = up = sinon.spy()
    clock = sinon.useFakeTimers()
    player1 = new Player
    player1.options =
      id: 1
      timebank: 10
      position: 0
      chips: 5
      rounds: 10
    player1.options_update = sinon.spy()
    player1.round = sinon.spy()
    player1.ask = sinon.spy()
    player2 = new Player
    player2.options =
      id: 2
      timebank: 15
      position: 1
    player2.options_update = sinon.spy()
    player2.round = sinon.spy()
    player2.ask = sinon.spy()

  afterEach ->
    clock.restore()


  describe 'default', ->
    it 'options', ->
      assert.equal 0, PokerPineappleOFC::options_default.bet
      assert.equal null, PokerPineappleOFC::options_default.rake
      assert.equal 10, PokerPineappleOFC::options_default.timeout
      assert.equal 20, PokerPineappleOFC::options_default.timeout_first
      assert.equal 60, PokerPineappleOFC::options_default.timeout_fantasyland
      assert.equal 10, PokerPineappleOFC::options_default.delay_round_prepare
      assert.deepEqual [], PokerPineappleOFC::options_default.timebank_rounds
      assert.equal true, PokerPineappleOFC::options_default.autostart
      assert.equal 2000, PokerPineappleOFC::options_default.delay_round
      assert.equal 200, PokerPineappleOFC::options_default.delay_player_turn
      assert.equal 200, PokerPineappleOFC::options_default.delay_player_ask
      assert.equal 0, PokerPineappleOFC::options_default.turns_out_max
      assert.equal 3, PokerPineappleOFC::options_default.turns_out_limit

      assert.equal 0, PokerPineappleOFC::options_default.dealer
      assert.equal false, PokerPineappleOFC::options_default.running
      assert.equal false, PokerPineappleOFC::options_default.showdown
      assert.equal false, PokerPineappleOFC::options_default.fantasyland
      assert.equal false, PokerPineappleOFC::options_default.fantasyland_only

    it 'constructor', ->
      assert.deepEqual [null, null, null], o._players
      assert.deepEqual {}, o._players_id
      assert.equal true, o._cards.initc

    it 'constructor players_add', ->
      class PokerPineappleOFC2 extends PokerPineappleOFC
        player_add: spy
      o = new PokerPineappleOFC2({players: ['p', 'z']})
      assert.equal false, 'players' of o.options
      assert.equal 2, spy.callCount
      assert.equal 'p', spy.getCall(0).args[0]
      assert.equal 'z', spy.getCall(1).args[0]

    it 'constructor players_add (users)', ->
      class PokerPineappleOFC2 extends PokerPineappleOFC
        player_add: spy
      o = new PokerPineappleOFC2({users: ['p']})
      assert.equal false, 'users' of o.options
      assert.equal 1, spy.callCount
      assert.equal 'p', spy.getCall(0).args[0]


  describe 'players', ->
    filter1 = null
    filter2 = null
    beforeEach ->
      filter1 = sinon.fake.returns false
      filter2 = sinon.fake.returns true
      o._players = [null, {filter: filter1}, {filter: filter2}]

    it 'default', ->
      assert.deepEqual [{filter: filter2}], o.players('params')
      assert.equal 1, filter1.callCount
      assert.equal 'params', filter1.getCall(0).args[0]
      assert.equal 1, filter2.callCount
      assert.equal 'params', filter2.getCall(0).args[0]

    it 'no filter', ->
      assert.deepEqual [{filter: filter1}, {filter: filter2}], o.players()
      assert.equal 0, filter1.callCount


  describe '_players_not_fantasyland', ->
    players = null
    beforeEach ->
      players = [
        {options: {id: 1, hand_full: true, fantasyland: true}}
        {options: {id: 2, hand_full: false, fantasyland: false}}
      ]
      o.players = sinon.fake.returns players

    it 'default', ->
      assert.deepEqual [], o._players_not_fantasyland()
      assert.equal 1, o.players.callCount
      assert.deepEqual {playing: true}, o.players.getCall(0).args[0]

    it 'fantasyland', ->
      players[1].options.fantasyland = true
      assert.deepEqual [1], o._players_not_fantasyland()

    it 'fantasyland active', ->
      players[0].options.hand_full = false
      assert.deepEqual [2], o._players_not_fantasyland()


  describe 'position', ->
    beforeEach ->
      o._players = [null, 'u', null, 'u']

    it 'next', ->
      assert.equal(1, o._player_position_next(0))
      assert.equal(3, o._player_position_next(1))
      assert.equal(1, o._player_position_next(3))

    describe 'next_action', ->
      action_require1 = null
      action_require2 = null
      action_require3 = null
      next = null
      beforeEach ->
        next = [0, 1, 2]
        o._player_position_next = sinon.fake -> next.shift()
        action_require1 = sinon.fake.returns false
        action_require2 = sinon.fake.returns false
        action_require3 = sinon.fake.returns true
        o._players = [{action_require: action_require1}, {action_require: action_require2}, {action_require: action_require3}]

      it 'default', ->
        assert.equal 2, o._player_position_next_action(5)
        assert.equal 3, o._player_position_next.callCount
        assert.equal 5, o._player_position_next.getCall(0).args[0]
        assert.equal 0, o._player_position_next.getCall(1).args[0]
        assert.equal 1, o._player_position_next.getCall(2).args[0]

      it 'not found', ->
        o._players[2].action_require = -> false
        assert.equal null, o._player_position_next_action(5)


    it 'free', ->
      Math.random = -> 0.9999999
      assert.equal(2, o._player_position_free())
      Math.random = -> 0
      assert.equal(0, o._player_position_free())

    it 'free (full)', ->
      o._players = ['u', 'u', 'u', 'u']
      Math.random = sinon.spy()
      assert.equal(-1, o._player_position_free())
      assert.equal(0, Math.random.callCount)


  describe 'player_add', ->
    beforeEach ->
      o._player_position_free = sinon.fake.returns 0
      o.start = sinon.spy()
      o.options.autostart = true
      o.options.timeout = 10
      o.options.timeout_first = 11
      o.options.timeout_fantasyland = 12
      o.options.delay_player_turn = 111
      o.options.turns_out_limit = 5
      o.options.fantasyland_only = true
      o._players = [null, '1', '2']
      o.players = sinon.fake.returns [1, 2]
      o._round_prepare_timeout = null
      o._player_toJSON = sinon.fake (p, id)->
        if id
          return 'pjs_local_' + id
        return 'pjs_global'
      o._round_prepare_emit = sinon.spy()
      o.on 'player:add', spy

    it 'default', ->
      assert.equal true, o.player_add({id: 5})
      assert.equal(5, o._players[0].options.id)
      assert.equal(0, o._players[0].options.position)
      assert.equal(10, o._players[0].options.timeout)
      assert.equal(11, o._players[0].options.timeout_first)
      assert.equal(12, o._players[0].options.timeout_fantasyland)
      assert.equal(111, o._players[0].options.delay_player_turn)
      assert.equal(5, o._players[0].options.turns_out_limit)
      assert.equal(true, o._players[0].options.fantasyland_only)
      assert.deepEqual({5: 0}, o._players_id)
      assert.equal 1, o.start.callCount
      assert.equal 1, o.players.callCount
      assert.equal 0, o._round_prepare_emit.callCount

    it 'event', ->
      o.player_add {id: 5}
      assert.equal 1, spy.callCount
      assert.equal 'pjs_global', spy.getCall(0).args[0]
      assert.deepEqual {5: 'pjs_local_5' }, spy.getCall(0).args[1]
      assert.equal 2, o._player_toJSON.callCount
      assert.equal 5, o._player_toJSON.getCall(0).args[0].options.id
      assert.equal undefined, o._player_toJSON.getCall(0).args[1]
      assert.equal 5, o._player_toJSON.getCall(1).args[0].options.id
      assert.equal 5, o._player_toJSON.getCall(1).args[1]

    it 'no place', ->
      o._player_position_free = sinon.fake.returns -1
      assert.equal false, o.player_add({id: 5})
      assert.equal 0, o.start.callCount

    it 'autostart disabled', ->
      o.options.autostart = false
      o.player_add({id: 5})
      assert.equal 0, o.start.callCount

    it 'running', ->
      o.options.running = true
      o.player_add({id: 5})
      assert.equal 0, o.start.callCount

    it '_round_prepare_timeout', ->
      o._round_prepare_timeout = 3
      o.player_add({id: 5})
      assert.equal 0, o.start.callCount
      assert.equal 1, o._round_prepare_emit.callCount

    it 'players not enough', ->
      o.players = sinon.fake.returns [1]
      o.player_add({id: 5})
      assert.equal 0, o.start.callCount


    describe 'events', ->
      player = null
      beforeEach ->
        o.player_add({id: 5})
        spy = sinon.spy()
        player = o._players[0]

      it 'out', ->
        o.on 'out', spy
        player.emit 'out', {p: 'r'}
        assert.equal 1, spy.callCount
        assert.deepEqual {p: 'r', position: 0}, spy.getCall(0).args[0]

      it 'timebank', ->
        o.on 'timebank', spy
        player.emit 'timebank'
        assert.equal 1, spy.callCount

      it 'ask', ->
        player._get_ask = sinon.fake.returns [1, 2]
        o._players_not_fantasyland = sinon.fake.returns 'not_f'
        o.on 'ask', spy
        player.emit 'ask'
        assert.equal 1, spy.callCount
        assert.equal 1, spy.getCall(0).args[0]
        assert.equal 2, spy.getCall(0).args[1]
        assert.equal 1, player._get_ask.callCount
        assert.equal 'not_f', player._get_ask.getCall(0).args[0]
        assert.equal 1, o._players_not_fantasyland.callCount


    describe 'turn_temp', ->
      player = null
      turn_emit = null
      beforeEach ->
        turn_emit = sinon.spy()
        o.player_add {id: 5}
        player = o._players[0]
        o.on 'turn_temp', turn_emit
        player.options.fantasyland = false

      it 'default', ->
        player.emit 'turn_temp', 'trn'
        assert.equal 1, turn_emit.callCount
        assert.equal 'trn', turn_emit.getCall(0).args[0]

      it 'fantasyland', ->
        player.options.fantasyland = true
        player.emit 'turn_temp', 'trn'
        assert.equal 0, turn_emit.callCount


    describe 'turn', ->
      player = null
      turn_emit = null
      beforeEach ->
        turn_emit = sinon.spy()
        o._progress_check = sinon.spy()
        o._progress = sinon.spy()
        o.player_add {id: 5}
        o.players = sinon.fake.returns [{options: {hand: 'h1', position: 1}}, {options: {hand: 'h2', position: 2}}]
        player = o._players[0]
        player._get_turn = sinon.fake.returns ['1', '2']
        o.on 'turn', turn_emit
        o._players_not_fantasyland = sinon.fake.returns 'pl_no_f'
        player.options.fantasyland = false
        player.options.position = 5

      it 'default', ->
        player.emit 'turn', 'trn'
        assert.equal 0, o._progress_check.callCount
        assert.equal 1, o._progress.callCount
        assert.equal 5, o._progress.getCall(0).args[0]
        assert.equal 1, turn_emit.callCount
        assert.equal '1', turn_emit.getCall(0).args[0]
        assert.equal '2', turn_emit.getCall(0).args[1]
        assert.equal 1, player._get_turn.callCount
        assert.equal 'trn', player._get_turn.getCall(0).args[0]
        assert.equal 'pl_no_f', player._get_turn.getCall(0).args[1]
        assert.deepEqual [{hand: 'h1', position: 1}, {hand: 'h2', position: 2}], player._get_turn.getCall(0).args[2]
        assert.equal 1, o._players_not_fantasyland.callCount
        assert.equal 1, o.players.callCount
        assert.deepEqual {playing: true, fantasyland: false}, o.players.getCall(0).args[0]

      it 'fantasyland', ->
        player.options.fantasyland = true
        player.emit 'turn', 'trn'
        assert.equal 1, o._progress_check.callCount
        assert.equal 0, o._progress.callCount


  describe '_player_remove', ->
    beforeEach ->
      o._players_id = {[player1.options.id]: 1, 2: 0}
      o._players = [player1, null, null]
      o.players = sinon.fake.returns [1]
      o._round_prepare_cancel = sinon.spy()
      o.on 'player:remove', spy

    it 'default', ->
      o._player_remove player1
      assert.deepEqual {2: 0}, o._players_id
      assert.deepEqual [null, null, null], o._players
      assert.equal 1, spy.callCount
      assert.deepEqual {id: 1, chips: 5, rounds: 10}, spy.getCall(0).args[0]
      assert.equal 1, o._round_prepare_cancel.callCount

    it 'enought players', ->
      o.players = sinon.fake.returns [1, 2]
      o._player_remove player1
      assert.equal 0, o._round_prepare_cancel.callCount


  describe '_round_prepare', ->
    beforeEach ->
      o.options.delay_round_prepare = 10
      o.options.fantasyland = true
      o._round = sinon.spy()
      o.on 'round_prepare', spy
      o._round_prepare_timeout = null

    it 'default', ->
      o._round_prepare_emit = sinon.spy()
      o._round_prepare()
      assert.equal 0, o._round.callCount
      assert.equal 1, o._round_prepare_emit.callCount
      assert.equal true, !!o._round_prepare_timeout
      date = new Date().getTime()
      assert.equal true, new Date(date - 1000) <= o._round_prepare_start <= new Date(date + 1000)
      clock.tick 10600
      assert.equal null, o._round_prepare_timeout
      assert.equal 1, o._round.callCount

    it '_round_prepare_cancel', ->
      spy_cancel = sinon.spy()
      o.on 'round_cancel', spy_cancel
      o._round_prepare()
      o._round_prepare_cancel()
      assert.equal null, o._round_prepare_timeout
      clock.tick 10600
      assert.equal 0, o._round.callCount
      assert.equal 1, spy_cancel.callCount

    it '_round_prepare_emit', ->
      o._round_prepare_start = new Date()
      o._round_prepare_emit()
      assert.equal 1, spy.callCount
      assert.deepEqual {delay: 10, fantasyland: true}, spy.getCall(0).args[0]

    it '_round_prepare_emit (pass 5.4 sec )', ->
      o._round_prepare_start = new Date()
      clock.tick 5400
      o._round_prepare_emit()
      assert.equal 4, spy.getCall(0).args[0].delay

    it '_round_prepare_emit (pass 12 sec )', ->
      o._round_prepare_start = new Date()
      clock.tick 12000
      o._round_prepare_emit()
      assert.equal 0, spy.getCall(0).args[0].delay

    it 'no delay', ->
      o._round_prepare_emit = sinon.spy()
      o.options.delay_round_prepare = 0
      o._round_prepare()
      assert.equal 1, o._round.callCount
      assert.equal 0, o._round_prepare_emit.callCount

    it 'fantasyland_only', ->
      o._round_prepare_start = new Date()
      o.options.fantasyland_only = true
      o._round_prepare_emit()
      assert.equal false, 'fantasyland' of spy.getCall(0).args[0]


  describe '_round', ->
    beforeEach ->
      o.options.dealer = 0
      positions = [2, 1]
      o.players = sinon.fake ->
        [player1, player2]
      o._player_position_next = sinon.fake -> positions.shift()
      player1.options.rounds = 5
      player1.cards_require = sinon.fake.returns 14
      player2.options.rounds = 5
      player2.cards_require = sinon.fake.returns 0
      o.options.timebank_rounds = [
        [0, 5]
        [3, 6]
      ]
      o.on 'round', spy
      o._players = [player1, player2, null]
      o._progress = sinon.spy()
      o._cards.shuffle = sinon.spy()
      o._cards.deal = sinon.fake.returns 'deal'

    it 'default', ->
      o._round()
      assert.equal 1, up.callCount
      assert.deepEqual {dealer: 2, running: true}, up.getCall(0).args[0]
      assert.equal 1, o._player_position_next.callCount
      assert.equal 0, o._player_position_next.getCall(0).args[0]
      assert.equal 1, player1.round.callCount
      assert.deepEqual {}, player1.round.getCall(0).args[0]
      assert.equal 1, player2.round.callCount
      assert.deepEqual {}, player2.round.getCall(0).args[0]
      assert.equal 3, o.players.callCount
      assert.equal undefined, o.players.getCall(0).args[0]
      assert.deepEqual {playing: true}, o.players.getCall(1).args[0]
      assert.deepEqual {playing: true}, o.players.getCall(2).args[0]
      assert.equal 1, spy.callCount
      assert.deepEqual {dealer: 2, players: [{timebank: 10, position: 0, rounds: 5}, {timebank: 15, position: 1, rounds: 5}]}, spy.getCall(0).args[0]
      assert.equal 1, o._progress.callCount
      assert.equal 2, o._progress.getCall(0).args[0]
      assert.equal 1, o._cards.shuffle.callCount

    it 'fantasyland', ->
      o.options.fantasyland = true
      o._round()
      assert.deepEqual {playing: true}, o.players.getCall(0).args[0]
      assert.equal 0, up.callCount
      assert.equal 0, o._player_position_next.callCount

    it 'cards_require', ->
      o._round()
      assert.equal 1, player1.cards_require.callCount
      assert.equal true, player1.cards_require.getCall(0).args[0]
      assert.equal 1, player2.cards_require.callCount
      assert.equal true, player2.cards_require.getCall(0).args[0]
      assert.equal 1, player1.ask.callCount
      assert.deepEqual {cards: 'deal'}, player1.ask.getCall(0).args[0]
      assert.equal 0, player2.ask.callCount
      assert.equal 1, o._cards.deal.callCount
      assert.equal 14, o._cards.deal.getCall(0).args[0]

    it 'timebank', ->
      player1.options.rounds = 0
      player2.options.rounds = 3
      o._round()
      assert.equal 5, player1.round.getCall(0).args[0].timebank
      assert.equal 6, player2.round.getCall(0).args[0].timebank

    it 'timebank (after)', ->
      player2.options.rounds = 9
      o._round()
      assert.equal 6, player2.round.getCall(0).args[0].timebank


  describe '_progress_check', ->
    players = null
    beforeEach ->
      o._round_end = sinon.spy()
      players = [[1, 2], [3, 4], [player1, 6], [player1]]
      o.players = sinon.fake -> players.shift()
      player1.action_fantasyland = sinon.spy()

    it 'default', ->
      assert.equal false, o._progress_check()
      assert.equal 1, o._round_end.callCount
      assert.equal 2, o.players.callCount
      assert.deepEqual {playing: true}, o.players.getCall(0).args[0]
      assert.deepEqual {playing: true, hand_full: true}, o.players.getCall(1).args[0]

    it 'keep playing', ->
      players[1] = [3]
      assert.equal true, o._progress_check()
      assert.equal 0, o._round_end.callCount
      assert.equal 4, o.players.callCount
      assert.deepEqual {playing: true, hand_full: false, fantasyland: true, out: true}, o.players.getCall(2).args[0]
      assert.deepEqual {playing: true, hand_full: false}, o.players.getCall(3).args[0]
      assert.equal 0, player1.action_fantasyland.callCount

    it 'user out in fantasyland', ->
      players = [[1, 2], [3], [player1], [player1]]
      o._progress_check()
      assert.equal 1, player1.action_fantasyland.callCount


  describe '_progress', ->
    beforeEach ->
      o._players = [player1]
      o._progress_check = sinon.fake.returns true
      o._player_position_next_action = sinon.fake.returns 0
      o._cards.deal = sinon.fake.returns 'deal'
      player1.cards_require = sinon.fake.returns 5

    it 'default', ->
      o._progress(2)
      assert.equal 1, o._progress_check.callCount
      assert.equal 1, o._player_position_next_action.callCount
      assert.equal 2, o._player_position_next_action.getCall(0).args[0]
      clock.tick 200
      assert.equal 1, o._cards.deal.callCount
      assert.equal 5, o._cards.deal.getCall(0).args[0]
      assert.equal 1, player1.cards_require.callCount
      assert.equal 1, player1.ask.callCount
      assert.deepEqual {cards: 'deal'}, player1.ask.getCall(0).args[0]

    it 'progress check fail', ->
      o._progress_check = -> false
      o._progress(2)
      assert.equal 0, o._player_position_next_action.callCount
      assert.equal 0, player1.ask.callCount

    it 'no action user', ->
      o._player_position_next_action = -> null
      o._progress(2)
      assert.equal 0, player1.ask.callCount


  describe 'user actions', ->
    beforeEach ->
      o._players_id = {1: 2}
      o._players = [null, null, player1]
      player1.options.waiting = true
      player1.out = sinon.spy()
      o._player_remove = sinon.spy()


    describe 'turn', ->
      beforeEach ->
        player1.turn = sinon.spy()
        player1.options.waiting = true

      it 'default', ->
        o.turn {user_id: 1, turn: {c: 'a'}}
        assert.equal 1, player1.turn.callCount
        assert.deepEqual {c: 'a'}, player1.turn.getCall(0).args[0]

      it 'not waiting', ->
        player1.options.waiting = false
        o.turn {user_id: 1, turn: {c: 'a'}}
        assert.equal 0, player1.turn.callCount


    describe 'turn_temp', ->
      beforeEach ->
        player1.turn_temp = sinon.spy()
        player1.options.waiting = true

      it 'default', ->
        o.turn_temp {user_id: 1, turn: {c: 'a'}}
        assert.equal 1, player1.turn_temp.callCount
        assert.deepEqual {c: 'a'}, player1.turn_temp.getCall(0).args[0]

      it 'not waiting', ->
        player1.options.waiting = false
        o.turn_temp {user_id: 1, turn: {c: 'a'}}
        assert.equal 0, player1.turn_temp.callCount


    it 'out', ->
      o.out {user_id: 1, out: true}
      assert.equal 1, player1.out.callCount
      assert.deepEqual {out: true}, player1.out.getCall(0).args[0]


    describe 'last', ->
      beforeEach ->
        o.options.running = true
        player1.options.playing = false

      it 'default', ->
        o.last {user_id: 1}
        assert.equal 1, o._player_remove.callCount
        assert.deepEqual player1, o._player_remove.getCall(0).args[0]

      it 'running and playing', ->
        player1.options.playing = true
        o.last {user_id: 1}
        assert.equal 0, o._player_remove.callCount

    it 'round_last', ->
      o.round_last()
      assert.equal true, o._round_last


  describe '_calculate_pot', ->
    fn = null
    num = null
    beforeEach ->
      o.options.bet = 5
      fn = o._calculate_pot.bind(o)
      num = (p)->
        {...p, players: p.players.map ({chips_change})-> chips_change}

    it 'default', ->
      o.options.bet = 1
      assert.deepEqual {
        players: [
          {chips_change: -10, chips: 100, points_change: -10}
          {chips_change: -5, chips: 100, points_change: -5}
          {chips_change: 15, chips: 200, points_change: 15}
        ]
      }, fn([ {chips: 100, points_change: -10}, {chips: 100, points_change: -5}, {chips: 200, points_change: 15} ])
      assert.deepEqual {
        players: [-10, -5, 15]
      }, num fn([ {chips: 100, points_change: -10}, {chips: 100, points_change: -5}, {chips: 200, points_change: 15} ])

    it 'bet x5', ->
      assert.deepEqual {
        players: [
          {chips_change: -50, chips: 100, points_change: -10}
          {chips_change: -25, chips: 100, points_change: -5}
          {chips_change: 75, chips: 200, points_change: 15}
        ]
      }, fn([ {chips: 100, points_change: -10}, {chips: 100, points_change: -5}, {chips: 200, points_change: 15} ])

    it 'win low chips', ->
      assert.deepEqual {
        players: [  -28, -14, 42 ]
      }, num fn([ {chips: 100, points_change: -10}, {chips: 100, points_change: -5}, {chips: 21, points_change: 15} ])

    it 'win low chips (round to near)', ->
      assert.deepEqual {
        players: [  -27, -13, 40 ]
      }, num fn([ {chips: 100, points_change: -10}, {chips: 100, points_change: -5}, {chips: 20, points_change: 15} ])

    it 'win low chips (round to near + not enough)', ->
      assert.deepEqual {
        players: [  -16, -24, 40 ]
      }, num fn([ {chips: 16, points_change: -10}, {chips: 100, points_change: -5}, {chips: 20, points_change: 15} ])

    it 'win low chips (round to near + not enough 3 players)', ->
      assert.deepEqual {
        players: [  -6, -12, -12, 30 ]
      }, num fn([ {chips: 6, points_change: -10}, {chips: 100, points_change: -5}, {chips: 100, points_change: -5}, {chips: 10, points_change: 25} ])

    it 'win low chips (3 winners)', ->
      assert.deepEqual {
        players: [  -95, 30, 50, 15 ]
      }, num fn([ {chips: 1000, points_change: -50}, {chips: 10, points_change: 10}, {chips: 100, points_change: 10}, {chips: 5, points_change: 25} ])

    it 'win low chips (3 winners 1 looser only some chips)', ->
      assert.deepEqual {
        players: [  -50, 18, 17, 15 ]
      }, num fn([ {chips: 50, points_change: -50}, {chips: 10, points_change: 10}, {chips: 100, points_change: 10}, {chips: 5, points_change: 25} ])

    describe 'rake', ->
      beforeEach ->
        o.options.rake =
          percent: 3.5
          cap: 5

      it 'default', ->
        assert.deepEqual {
          rake: 2
          players: [
            {chips_change: -50, chips: 100, points_change: -10}
            {chips_change: -25, chips: 100, points_change: -5}
            {chips_change: 73, chips: 200, points_change: 15}
          ]
        }, fn([ {chips: 100, points_change: -10}, {chips: 100, points_change: -5}, {chips: 200, points_change: 15} ])

      it 'cap', ->
        assert.deepEqual {
          rake: 5
          players: [ -500, -250, 745 ]
        }, num fn([ {chips: 1000, points_change: -100}, {chips: 1000, points_change: -50}, {chips: 1000, points_change: 150} ])

      it 'cap complicated winners', ->
        assert.deepEqual {
          rake: 1
          players: [  -50, 17, 17, 15 ]
        }, num fn([ {chips: 50, points_change: -50}, {chips: 10, points_change: 10}, {chips: 100, points_change: 10}, {chips: 5, points_change: 25} ])


  # describe '_calculate_pot old', ->
  #   fn = null
  #   numbers = null
  #   beforeEach ->
  #     o.options.bet = 5
  #     o.options.rake =
  #       percent: 3.5
  #       cap: 5
  #     fn = o._calculate_pot.bind(o)
  #     numbers = (p)->
  #       {rake: p.rake, players: p.players.map (p)-> p.chips_change}


  #   it 'default', ->
  #     assert.deepEqual {
  #       rake: 3
  #       players: [
  #         {chips_change: -50, chips: 100, points_change: -10}
  #         {chips_change: -50, chips: 100, points_change: -10}
  #         {chips_change: 97, chips: 200, points_change: 20}
  #       ]
  #     }, fn([ {chips: 100, points_change: -10}, {chips: 100, points_change: -10}, {chips: 200, points_change: 20} ])

  #   it 'chips change', ->
  #     assert.deepEqual {rake: 3, players: [-100, -10, 107]}, numbers fn([ {chips: 100, points_change: -21}, {chips: 100, points_change: -2}, {chips: 200, points_change: 23} ])
  #     assert.deepEqual {rake: 3, players: [-100, 5, 92]}, numbers fn([ {chips: 100, points_change: -21}, {chips: 100, points_change: 1}, {chips: 100, points_change: 20} ])
  #     assert.deepEqual {rake: 1, players: [-13, -20, 32]}, numbers fn([ {chips: 13, points_change: -8}, {chips: 20, points_change: -8}, {chips: 100, points_change: 16} ])

  #   it 'rake', ->
  #     assert.equal 3, fn([ {chips: 1000, points_change: -20}, {chips: 100, points_change: 20} ]).rake
  #     assert.equal 5, fn([ {chips: 1000, points_change: -40}, {chips: 1000, points_change: 40} ]).rake
  #     assert.equal 5, fn([ {chips: 1000, points_change: -50}, {chips: 1000, points_change: 50} ]).rake

  #   it 'no rake', ->
  #     o.options.rake = null
  #     assert.equal false, 'rake' of fn([ {chips: 100, points_change: -20}, {chips: 100, points_change: -2}, {chips: 200, points_change: 22} ])


  describe '_round_end', ->
    players = null
    players_return = null
    beforeEach ->
      o._players = [player1, null, player2]
      o.on 'round_end', spy
      player1.round_end = sinon.spy()
      player2.round_end = sinon.spy()
      player1.options.fantasyland = true
      player1.options.hand = 'h'
      player2.options.fantasyland = false
      player2.options.hand = 'h2'
      players_return = [
        [ {options: {chips: 100, position: 0, rank: 'r1'}}, {options: {chips: 101, position: 2, rank: 'r2'}} ]
        [ {points_change: 'pch'} ]
      ]
      o.players = sinon.fake -> players_return.shift()
      PokerOFCRank_compare = sinon.fake.returns 'pco'
      players = [
        {chips: 10, position: 0, chips_change: -5, points_change: -1 }
        {chips: 20, position: 2, chips_change: -15, points_change: -2 }
      ]
      o._calculate_pot = sinon.fake -> { rake: 2, players }
      o._player_remove = sinon.spy()
      player2.options.turns_out = 2
      o._round_prepare = sinon.spy()

    it 'default', ->
      o._round_end()
      assert.equal 1, spy.callCount
      players_copy = _cloneDeep(players)
      players_copy[0].fantasyland = true
      players_copy[0].hand = 'h'
      players_copy[0].chips = 5
      players_copy[0].timebank = 10
      players_copy[1].fantasyland = false
      players_copy[1].hand = 'h2'
      players_copy[1].chips = 20
      players_copy[1].timebank = 15
      assert.deepEqual {players: players_copy, rake: 2, fantasyland: true}, spy.getCall(0).args[0]
      assert.equal 1, o.players.callCount
      assert.deepEqual {playing: true}, o.players.getCall(0).args[0]
      assert.equal 1, PokerOFCRank_compare.callCount
      assert.deepEqual [{chips: 100, position: 0, rank: 'r1'}, {chips: 101, position: 2, rank: 'r2'}], PokerOFCRank_compare.getCall(0).args[0]
      assert.equal 1, o._calculate_pot.callCount
      assert.equal 'pco', o._calculate_pot.getCall(0).args[0]
      assert.equal 1, player1.round_end.callCount
      assert.deepEqual {chips_change: -5, points_change: -1}, player1.round_end.getCall(0).args[0]
      assert.equal true, player1.round_end.getCall(0).args[1]
      assert.equal 1, player2.round_end.callCount
      assert.deepEqual {chips_change: -15, points_change: -2}, player2.round_end.getCall(0).args[0]
      assert.equal 1, up.callCount
      assert.deepEqual {showdown: true}, up.getCall(0).args[0]

    it 'fantasyland_only', ->
      o.options.fantasyland_only = true
      o._round_end()
      assert.equal false, 'fantasyland' of spy.getCall(0).args[0].players[0]
      assert.equal false, 'fantasyland' of spy.getCall(0).args[0].players[1]


    describe 'remove on timeout', ->
      round_finish = null
      beforeEach ->
        round_finish = sinon.spy()
        o.on 'round_end_timeout', round_finish
        players[0].chips = 5

      it 'default', ->
        o._round_end()
        o.options_update = up = sinon.spy()
        o.players = sinon.fake -> [1, 2]
        clock.tick 3000
        assert.equal 1, o._player_remove.callCount
        assert.equal 1, o._player_remove.getCall(0).args[0].options.id
        assert.equal 1, round_finish.callCount
        assert.deepEqual {players_remove: [1], fantasyland: true}, round_finish.getCall(0).args[0]
        assert.equal 1, up.callCount
        assert.deepEqual {fantasyland: true, showdown: false}, up.getCall(0).args[0]
        assert.equal 1, o.players.callCount
        assert.equal 1, o._round_prepare.callCount

      it 'no fantasyland', ->
        player1.options.fantasyland = false
        o._round_end()
        o.players = sinon.fake -> [1, 2]
        clock.tick 3000
        assert.equal false, 'fantasyland' in Object.keys(round_finish.getCall(0).args[0])

      it 'fantasyland_only', ->
        o.options.fantasyland_only = true
        o._round_end()
        o.players = sinon.fake -> [1, 2]
        clock.tick 3000
        assert.equal false, 'fantasyland' in Object.keys(round_finish.getCall(0).args[0])

      it 'autostart disabled', ->
        player1.options.fantasyland = false
        o.options.autostart = false
        o._round_end()
        o.players = sinon.fake -> [1, 2]
        clock.tick 3000
        assert.equal 0, o._round_prepare.callCount

      it 'not enough users', ->
        o._round_end()
        o.players = sinon.fake -> [1]
        clock.tick 3000
        assert.equal 0, o._round_prepare.callCount


    it 'round_last', ->
      o._round_prepare = sinon.spy()
      o._round_end()
      o.players = sinon.fake.returns [1, 2]
      o._round_last = true
      clock.tick 3000
      assert.equal 1, o.players.callCount
      assert.equal 2, o._player_remove.callCount
      assert.equal 1, o._player_remove.getCall(0).args[0]
      assert.equal 2, o._player_remove.getCall(1).args[0]
      assert.equal 0, o._round_prepare.callCount

    it 'user not enough', ->
      players[0].chips = 5
      o._round_end()
      assert.equal false, player1.round_end.getCall(0).args[1]

    it 'user turns_out (no fantasyland)', ->
      player1.options.fantasyland = false
      o.options.turns_out_max = 2
      o._round_end()
      o.options_update = up = sinon.spy()
      assert.equal false, 'fantasyland' of spy.getCall(0).args[0]
      clock.tick 3000
      assert.equal 1, o._player_remove.callCount
      assert.deepEqual {running: false, fantasyland: false, showdown: false}, up.getCall(0).args[0]

    it 'user turns_out', ->
      o.options.turns_out_max = 2
      o._round_end()
      clock.tick 3000
      assert.equal 0, o._player_remove.callCount

    it 'event', ->
      o._round_end()
      assert.equal 1, spy.callCount
      assert.equal 2, spy.getCall(0).args[0].rake

    it 'event (no rake)', ->
      o._calculate_pot = sinon.fake ->
        {
          players: [
            {position: 0, chips_change: -5, points_change: -1 }
          ]
        }
      o._round_end()
      assert.equal false, 'rake' of spy.getCall(0).args[0]


  describe 'start', ->
    beforeEach ->
      o.options.delay_round_prepare = 0
      o._round = sinon.spy()
      o._round_prepare = sinon.spy()
      o._players_id[1] = 0
      o._players_id[2] = 2
      o._players = [player1, null, player2]
      o.options_update = sinon.spy()

    it 'default', ->
      o.start()
      assert.equal 1, o._round.callCount
      assert.equal 0, o._round_prepare.callCount
      assert.equal 0, o.options_update.callCount

    it 'round_prepare', ->
      o.options.delay_round_prepare = 10
      o.start()
      assert.equal 0, o._round.callCount
      assert.equal 1, o._round_prepare.callCount

    it 'params', ->
      o.start {players: [{id: 1, timebank: 11}, {id: 2, timebank: 5}]}
      assert.equal 1, player1.options_update.callCount
      assert.deepEqual {timebank: 11}, player1.options_update.getCall(0).args[0]
      assert.equal 1, player2.options_update.callCount
      assert.deepEqual {timebank: 5}, player2.options_update.getCall(0).args[0]
      assert.equal 0, o.options_update.callCount

    it 'bet', ->
      o.start {bet: 0}
      assert.equal 1, o.options_update.callCount
      assert.deepEqual {bet: 0}, o.options_update.getCall(0).args[0]


  describe '_player_toJSON', ->
    beforeEach ->
      o.options.running = true
      o.options.showdown = false
      o._players_not_fantasyland = sinon.fake.returns 'nf'
      player1.toJSON = sinon.fake.returns 'pj1'

    it 'default', ->
      assert.equal 'pj1', o._player_toJSON(player1, 'us')
      assert.equal 1, o._players_not_fantasyland.callCount
      assert.equal 1, player1.toJSON.callCount
      assert.equal 'us', player1.toJSON.getCall(0).args[0]
      assert.equal 'nf', player1.toJSON.getCall(0).args[1]
      assert.equal true, player1.toJSON.getCall(0).args[2]

    it 'not running', ->
      o.options.running = false
      o._player_toJSON(player1)
      assert.equal false, player1.toJSON.getCall(0).args[2]

    it 'showdown', ->
      o.options.showdown = true
      o._player_toJSON(player1)
      assert.equal false, player1.toJSON.getCall(0).args[2]


  describe 'toJSON', ->
    beforeEach ->
      o.options.bet = 5
      o.options.dealer = 2
      o.options.running = true
      o.options.fantasyland = true
      player1.toJSON = sinon.fake.returns 'pj1'
      player2.toJSON = sinon.fake.returns 'pj2'
      o._players = [player1, null, player2]
      _player_toJSON = ['pj1', 'pj2']
      o._player_toJSON = sinon.fake -> _player_toJSON.shift()

    it 'default', ->
      assert.deepEqual {bet: 5, dealer: 2, running: true, fantasyland: true, players: ['pj1', null, 'pj2']}, o.toJSON('us')
      assert.equal 2, o._player_toJSON.callCount
      assert.deepEqual player1, o._player_toJSON.getCall(0).args[0]
      assert.deepEqual 'us', o._player_toJSON.getCall(0).args[1]
      assert.deepEqual player2, o._player_toJSON.getCall(1).args[0]
      assert.deepEqual 'us', o._player_toJSON.getCall(1).args[1]

    it 'fantasyland_only', ->
      o.options.fantasyland_only = true
      assert.equal false, 'fantasyland' of o.toJSON('us')
