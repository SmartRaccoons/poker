assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')


class Cards
  round: ->


Poker = proxyquire('../poker', {
  './cards':
    Cards: Cards
}).Poker

Player = Poker::player


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
    player1 = new Player({id: 1, chips: 20})
    player1.bet = sinon.spy()
    player1.round = sinon.spy()
    player1.cards_add = sinon.spy()
    player2 = new Player({id: 2, chips: 15})
    player2.bet = sinon.spy()
    player2.round = sinon.spy()
    player2.cards_add = sinon.spy()
    player3 = new Player({id: 3, chips: 10})
    player3.bet = sinon.spy()
    player3.round = sinon.spy()
    player3.cards_add = sinon.spy()


  afterEach ->
    clock.restore()


  describe 'default', ->
    it 'constructor', ->
      assert.deepEqual([null, null, null], p._players)

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

    it 'players', ->
      p._players = [null, 'p']
      assert.deepEqual(['p'], p.players())

    it 'start (event)', ->
      p._dealer_next = -> true
      p.on 'start', spy
      p.start()
      assert.equal(1, spy.callCount)

    it 'round', ->
      p._dealer = 0
      p._players = [player1, player2, player3]
      p.round()
      assert.equal(1, p._cards.shuffle.callCount)
      assert.equal(1, player3.bet.callCount)
      assert.equal(1, player3.bet.getCall(0).args[0])
      assert.equal(1, player1.bet.callCount)
      assert.equal(2, player1.bet.getCall(0).args[0])
      assert.equal(0, player2.bet.callCount)
      assert.equal(1, p._dealer)
      assert.equal(1, p._waiting)
      assert.deepEqual([], p._board)
      assert.equal(0, p._progress)

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


  describe 'User', ->
    u = null
    beforeEach ->
      u = new Player({id: 2, chips: 50, position: 2})

    it 'init', ->
      assert.equal(2, u.id)
      assert.equal(50, u.chips)
      assert.equal(2, u.position)

    it 'round', ->
      u.folded = true
      u.talked = true
      u.all_in = true
      u.cards = [1, 2]
      u.round()
      assert.equal(false, u.folded)
      assert.equal(false, u.talked)
      assert.equal(false, u.all_in)
      assert.deepEqual([], u.cards)

    it 'toJSON', ->
      u.round()
      assert.deepEqual({id: 2, chips: 50, position: 2, folded: false, talked: false, all_in: false}, u.toJSON())
