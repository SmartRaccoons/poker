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
    Rank: Rank
}).Poker

Player = Poker::player
Board = Poker::board


describe 'Poker', ->
  clock = null
  spy = null
  p = null
  player1 = null
  player2 = null
  player3 = null
  beforeEach ->
    spy = sinon.spy()
    clock = sinon.useFakeTimers()
    p = new Poker
      blinds: [1, 2]
      players: [2, 3]
      timeout: 10
    p._cards.shuffle = sinon.spy()
    p._cards.pop = sinon.spy()
    p._board.reset = sinon.spy()
    player1 = new Player({id: 1, chips: 20})
    player1.bet = sinon.spy()
    player1.round = sinon.spy()
    player1.cards = ['1', '11']
    player1.action_require = -> true
    player2 = new Player({id: 2, chips: 15})
    player2.bet = sinon.spy()
    player2.round = sinon.spy()
    player2.cards = ['2', '22']
    player2.action_require = -> true
    player3 = new Player({id: 3, chips: 10})
    player3.bet = sinon.spy()
    player3.round = sinon.spy()
    player3.cards = ['3', '33']
    player3.action_require = -> true


  afterEach ->
    clock.restore()


  describe 'default', ->
    beforeEach ->
      p.progress = ->

    it 'constructor', ->
      assert.deepEqual([null, null, null], p._players)
      assert.deepEqual([1, 2], p._blinds)

    it '_player_position_next', ->
      p._players = [null, 'u', null, 'u']
      assert.equal(1, p._player_position_next(0))
      assert.equal(1, p._player_position_next(0))
      assert.equal(3, p._player_position_next(1))
      assert.equal(1, p._player_position_next(3))

    it '_player_position', ->
      assert.equal(0, p._player_free_position())
      p._players[0] = 'u'
      assert.equal(1, p._player_free_position())

    it 'add_player', ->
      p._player_free_position = -> 0
      p.player_add({id: 1, chips: 50})
      assert.equal(1, p._players[0].id)
      assert.equal(0, p._players[0].position)

    it 'player_add (start)', ->
      p.start = sinon.spy()
      p.player_add({id: 1})
      assert.equal(0, p.start.callCount)
      p.player_add({id: 2})
      assert.equal(1, p.start.callCount)

    it 'player_add (event)', ->
      p.on 'player:add', spy
      p.player_add({id: 1})
      assert.equal(1, spy.callCount)

    it '_player_remove', ->
      p._players = [null, {id: 5}]
      p.on 'player:remove', spy
      p._player_remove({position: 1, id: 5})
      assert.deepEqual([null, null], p._players)
      assert.equal(1, spy.callCount)
      assert.deepEqual({id: 5}, spy.getCall(0).args[0])

    it 'players', ->
      p._players = [null, 'p']
      assert.deepEqual(['p'], p.players())

    it 'players (filter)', ->
      spy = sinon.fake.returns(true)
      p._players = [null, {id: 5, filter: spy}, {id: 6, filter: -> false}]
      players_filter = p.players({folded: true})
      assert.equal(1, players_filter.length)
      assert.equal(5, players_filter[0].id)
      assert.equal(1, spy.callCount)
      assert.deepEqual({folded: true}, spy.getCall(0).args[0])

    it 'start (event)', ->
      p._dealer_next = -> true
      p.on 'start', spy
      p.start()
      assert.equal(1, spy.callCount)

    it 'round', ->
      p._showdown_call = true
      p._dealer = 0
      p._players = [player1, player2, player3]
      p._player_bet = b = sinon.spy()
      p.progress = sinon.spy()
      p._blinds = [2, 4]
      p.round()
      assert.equal(1, p._board.reset.callCount)
      assert.deepEqual({blinds: [2, 4], show_first: 2}, p._board.reset.getCall(0).args[0])
      assert.equal(1, p._cards.shuffle.callCount)
      assert.equal(2, b.callCount)
      assert.deepEqual({bet: 2, silent: true}, b.getCall(0).args[0])
      assert.equal(2, b.getCall(0).args[1])
      assert.equal(4, b.getCall(1).args[0].bet)
      assert.equal(1, p._dealer)
      assert.equal(0, p._waiting)
      assert.deepEqual([2, 0], p._blinds_position)
      assert.equal(0, p._progress)
      assert.equal(1, p.progress.callCount)
      assert.equal(false, p._showdown_call)

    it 'round (2 players)', ->
      p._dealer = 0
      p._players = [player1, player2]
      p._player_bet = b = sinon.spy()
      p.round()
      assert.equal(1, b.getCall(0).args[0].bet)
      assert.equal(1, b.getCall(0).args[1])
      assert.equal(2, b.getCall(1).args[0].bet)
      assert.equal(0, p._waiting)
      assert.deepEqual([1, 0], p._blinds_position)

    it 'round (players)', ->
      p._players = [player1, player2]
      a = 0
      p._cards.pop = ->
        a++
        a
      p.round()
      assert.equal(1, player1.round.callCount)
      assert.equal(1, player2.round.callCount)
      assert.equal(1, player1.round.callCount)
      assert.deepEqual([1, 2], player1.round.getCall(0).args[0])
      assert.equal(1, player2.round.callCount)
      assert.deepEqual([3, 4], player2.round.getCall(0).args[0])

    it 'round (emit)', ->
      p._players = [player1, player2]
      player1._bet = 1
      player2._bet = 2
      a = 0
      p._cards.pop = ->
        a++
        a
      p.on 'round', spy
      p.round()
      assert.equal(1, spy.callCount)
      assert.deepEqual([{position: 0, bet: 1}, {position: 1, bet: 2}], spy.getCall(0).args[0].blinds)
      assert.equal(0, spy.getCall(0).args[0].dealer)

    it '_player_bet', ->
      p._progress = 2
      p._waiting = 1
      p._players[1] = player1
      p._player_bet({bet: 5})
      assert.equal(1, player1.bet.callCount)
      assert.deepEqual({bet: 5, progress: 2}, player1.bet.getCall(0).args[0])

    it '_player_bet (board)', ->
      p._waiting = 1
      p._progress = 2
      p._players[0] = player1
      p._board =
          bet: sinon.spy()
      p._player_bet({bet: 2}, 0)
      assert.equal(1, player1.bet.callCount)
      assert.equal(1, p._board.bet.callCount)
      assert.deepEqual({bet: 2, position: 0, progress: 2}, p._board.bet.getCall(0).args[0])

    it '_waiting_commands', ->
      p._waiting = 1
      p._board.bet_max = -> 5
      p._board.bet_raise = -> 3
      p._players = [null, player1]
      player1.commands = sinon.fake.returns('commands')
      p._waiting_commands()
      assert.equal(1, player1.commands.callCount)
      assert.deepEqual({bet_max: 5, bet_raise: 3}, player1.commands.getCall(0).args[0])

    it '_emit_ask', ->
      p.on 'player:ask', spy
      p._waiting = 1
      p._players = [player1]
      p._waiting_commands = -> 'commands'
      p._emit_ask(0)
      assert.equal(0, p._waiting)
      assert.equal(1, spy.callCount)
      assert.deepEqual({user: 1, commands: 'commands'}, spy.getCall(0).args[0])

    it '_emit_ask (timeout)', ->
      p._players = [player1]
      p._activity = sinon.spy()
      p._emit_ask(0)
      assert.equal(1, p._activity.callCount)

    it '_showdown', ->
      player1.position = 0
      p.players = sinon.fake.returns([player1])
      p.on 'showdown', spy
      p._showdown()
      assert.equal(1, p.players.callCount)
      assert.deepEqual({folded: false}, p.players.getCall(0).args[0])
      assert.equal(1, spy.callCount)
      assert.deepEqual([{position: 0, cards: ['1', '11']}], spy.getCall(0).args[0])

    it '_activity', ->
      p.player_turn = sinon.spy()
      p._waiting_commands = -> [['check']]
      p._activity()
      clock.tick(1000 * 10)
      assert.equal(0, p.player_turn.callCount)
      clock.tick(1000 * 2)
      assert.equal(1, p.player_turn.callCount)
      assert.deepEqual(['check'], p.player_turn.getCall(0).args[0])

    it '_activity_clear', ->
      p.player_turn = sinon.spy()
      p._activity()
      clock.tick(1000 * 10)
      p._activity_clear()
      clock.tick(1000 * 2)
      assert.equal(0, p.player_turn.callCount)


  describe 'turn', ->
    bet = null
    beforeEach ->
      p._waiting = 1
      p._players = [null, player1]
      player1.fold = sinon.spy()
      p._waiting_commands = -> [['check'], ['call', 30], ['raise', 40, 500]]
      p._player_bet = bet = sinon.spy()
      p.progress = sinon.spy()
      p._activity_clear = sinon.spy()

    it 'check', ->
      p.player_turn(['check'])
      assert.equal(1, bet.callCount)
      assert.deepEqual({bet: 0}, bet.getCall(0).args[0])
      assert.equal(1, p.progress.callCount)
      assert.equal(1, p._activity_clear.callCount)

    it 'call', ->
      p.player_turn(['call', 500])
      assert.equal(1, bet.callCount)
      assert.deepEqual({bet: 30}, bet.getCall(0).args[0])

    it 'raise', ->
      p.player_turn(['raise', 50.5])
      assert.equal(1, bet.callCount)
      assert.deepEqual({bet: 50}, bet.getCall(0).args[0])

    it 'raise (no value)', ->
      p.player_turn(['raise'])
      assert.equal(1, bet.callCount)
      assert.deepEqual({bet: 40}, bet.getCall(0).args[0])

    it 'raise (small)', ->
      p.player_turn(['raise', 30])
      assert.equal(1, bet.callCount)
      assert.deepEqual({bet: 40}, bet.getCall(0).args[0])

    it 'raise (big)', ->
      p.player_turn(['raise', 501])
      assert.equal(1, bet.callCount)
      assert.deepEqual({bet: 40}, bet.getCall(0).args[0])

    it 'raise (big)', ->
      p._waiting_commands = -> [[], [], ['raise', 40]]
      p.player_turn(['raise', 501])
      assert.equal(1, bet.callCount)
      assert.deepEqual({bet: 40}, bet.getCall(0).args[0])

    it 'fold', ->
      p._waiting_commands = -> [['fold']]
      p.player_turn(['fold'])
      assert.equal(0, bet.callCount)
      assert.equal(1, player1.fold.callCount)
      assert.equal(1, p.progress.callCount)

    it 'fake', ->
      p.player_turn(['fake'])
      p.player_turn([])
      p.player_turn()
      p.player_turn('boom')
      assert.equal(0, bet.callCount)
      assert.equal(0, p.progress.callCount)

    it 'board add card', ->
      player1.board_cards = sinon.spy()
      player2.board_cards = sinon.spy()
      p._players = [null, player1, null, player2]
      p._board.emit 'card', [1, 2]
      assert.equal(1, player1.board_cards.callCount)
      assert.deepEqual([1, 2], player1.board_cards.getCall(0).args[0])
      assert.equal(1, player2.board_cards.callCount)
      assert.deepEqual([1, 2], player2.board_cards.getCall(0).args[0])


  describe 'progress', ->
    beforeEach ->
      p._players = [player1, player2, player3]
      p._progress = 0
      p._waiting = 0
      p._dealer = 1
      p._emit_ask = sinon.spy()
      p._board =
        bet_max: -> 5
        cards: sinon.spy()
        pot: ->
      c = 0
      p._cards.pop = sinon.fake ->
        c++
      p.players = sinon.fake.returns([1, 2])
      p._round_end = sinon.spy()
      p._progress_pot = sinon.spy()
      player1.action_require = sinon.fake.returns(false)
      player2.action_require = sinon.fake.returns(false)
      player3.action_require = sinon.fake.returns(false)

    it 'action required', ->
      player3.action_require = sinon.fake.returns(true)
      p._progress_pot = sinon.spy()
      p.progress(->)
      assert.equal(1, player2.action_require.callCount)
      assert.equal(5, player2.action_require.getCall(0).args[0])
      assert.equal(1, player3.action_require.callCount)
      assert.equal(0, player1.action_require.callCount)
      assert.equal(1, p._emit_ask.callCount)
      assert.equal(2, p._emit_ask.getCall(0).args[0])
      assert.equal(0, p._progress_pot.callCount)
      assert.equal(0, p._round_end.callCount)

    it 'action required (showdown)', ->
      p._showdown_call = true
      p.progress(->)
      assert.equal(0, player2.action_require.callCount)

    it 'pot', ->
      p._progress_pot = sinon.spy()
      p.progress(->)
      assert.equal(1, p._progress_pot.callCount)

    it 'pot (max bet zero)', ->
      p._progress_pot = sinon.spy()
      p._board.bet_max = -> 0
      p.progress(->)
      assert.equal(0, p._progress_pot.callCount)

    it 'one left', ->
      p.players = sinon.fake.returns([1])
      p._round_end = sinon.fake.returns('re')
      assert.equal('re', p.progress())
      assert.equal(1, p._round_end.callCount)
      assert.equal(1, p.players.callCount)
      assert.deepEqual({folded: false}, p.players.getCall(0).args[0])

    it 'one left with chips', ->
      p.players = sinon.stub()
      p.players.withArgs({folded: false}).returns([1, 2])
      p.players.withArgs({folded: false, all_in: false}).returns([])
      p._showdown = sinon.spy()
      p.progress(->)
      assert.equal(1, p._showdown.callCount)
      assert.equal(true, p._showdown_call)

    it 'showdown', ->
      p._progress = 3
      p._round_end = sinon.fake.returns('sd')
      assert.equal('sd', p.progress())
      assert.equal(1, p._round_end.callCount)

    it 'flop', ->
      p._progress = 0
      p.progress(->)
      assert.equal(1, p._progress)
      assert.equal(4, p._cards.pop.callCount)
      assert.equal(1, p._board.cards.callCount)
      assert.deepEqual([1, 2, 3], p._board.cards.getCall(0).args[0])

    it 'flop (waiting)', ->
      p._dealer = 5
      p.progress(spy)
      assert.equal(5, p._waiting)
      assert.equal(1, spy.callCount)
      assert.deepEqual(spy, spy.getCall(0).args[0])

    it 'turn/river', ->
      p._progress = 1
      p.progress(->)
      assert.equal(2, p._cards.pop.callCount)
      assert.equal(1, p._board.cards.callCount)
      assert.deepEqual([1], p._board.cards.getCall(0).args[0])


  describe 'pot', ->
    pot = null
    beforeEach ->
      p._players = [player1, null, player2, null]
      p._board.pot = pot = sinon.spy()
      player1.progress = sinon.fake.returns(9)
      player1.position = 0
      player2.progress = sinon.fake.returns(10)
      player2.position = 2

    it 'default', ->
      p._progress_pot()
      assert.equal(1, player1.progress.callCount)
      assert.equal(1, player2.progress.callCount)
      assert.equal(1, pot.callCount)
      assert.deepEqual([{position: 0, bet: 9}, {position: 2, bet: 10}], pot.getCall(0).args[0])

    it 'zero bets', ->
      player2.progress = sinon.fake.returns(0)
      p._progress_pot()
      assert.deepEqual([{bet: 9, position: 0}], pot.getCall(0).args[0])


  describe 'round end', ->
    pot_devide = null
    compare = null
    beforeEach ->
      p._board.pot_devide = pot_devide = sinon.fake.returns([
        {pot: 15, positions: [2, 4, 5], winners: [2, 4], winners_pot: [1, 1], showdown: [5, 2, 4]}
      ])
      Rank::compare = compare = sinon.fake.returns([ [1], [0] ])
      player1.rank = sinon.fake.returns({rank: 'r1'})
      player1.position = 2
      player1.win = sinon.spy()
      player2.rank = sinon.fake.returns({rank: 'r2'})
      player2.position = 4
      player2.win = sinon.spy()
      player3.position = 5
      player3.win = sinon.spy()
      p._players = [null, null, player1, null, player2, player3]
      p.players = sinon.stub()
      p.players.withArgs({folded: false}).returns([player1, player2])
      p.players.withArgs().returns([player2, player3])
      p.on 'end', spy

    it 'default', ->
      p._round_end()
      assert.equal(1, player1.rank.callCount)
      assert.equal(1, compare.callCount)
      assert.deepEqual(['r1', 'r2'], compare.getCall(0).args[0])
      assert.equal(1, pot_devide.callCount)
      assert.deepEqual([ [4], [2] ], pot_devide.getCall(0).args[0])
      assert.equal(0, spy.callCount)

    it 'one player', ->
      p.players = sinon.fake.returns([player1])
      p._round_end()
      assert.equal(0, compare.callCount)
      assert.equal(1, pot_devide.callCount)
      assert.deepEqual([ [2] ], pot_devide.getCall(0).args[0])

    it 'calculate pot winners', ->
      p._board.pot_devide = sinon.fake.returns([
        {pot: 11, positions: [2, 4, 5], winners: [2, 4], winners_pot: [5, 6], showdown: []}
      ])
      player1.win = sinon.spy()
      p._round_end()
      assert.equal(1, player1.win.callCount)
      assert.equal(1, player2.win.callCount)
      assert.equal(5, player1.win.getCall(0).args[0])
      assert.equal(6, player2.win.getCall(0).args[0])

    it 'emit', ->
      p.on 'round:end', spy
      p._round_end()
      assert.equal(1, spy.callCount)
      assert.deepEqual([ {position: 5, cards: ['3', '33']}, {position: 2, cards: ['1', '11']}, {position: 4, cards: ['2', '22']} ], spy.getCall(0).args[0].pots[0].showdown)

    it 'remove loosers', ->
      player1.chips = 0
      player2.chips = 0
      player3.chips = 0
      p._player_remove = sinon.spy()
      p._round_end()
      assert.equal(2, p._player_remove.callCount)
      assert.equal(2, p._player_remove.getCall(0).args[0].id)
      assert.equal(3, p._player_remove.getCall(1).args[0].id)

    it 'one player left', ->
      p.players.withArgs().returns([player1])
      p._round_end()
      assert.equal(1, spy.callCount)
