assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')


class PokerPlayer
  options_round_reset: ['b']
  constructor: (@options)->
  toJSON: -> {j: 's', actions: ['5']}

class PokerRank

PokerActionPlayer = proxyquire('../poker.player', {
  '../poker/poker.player': { PokerPlayer }
  './cards.action': {PokerActionCards: {'h': 'hunter', 'w': 'wizard'}}
  './rank': {PokerActionRank: PokerRank}
}).PokerActionPlayer


describe 'PokerActionPlayer', ->
  spy = null
  p = null
  beforeEach ->
    spy = sinon.spy()
    p = new PokerActionPlayer({})

  it 'default', ->
    assert.deepEqual PokerRank, PokerActionPlayer::Rank
    assert.equal 10, p.options_default.energy
    assert.equal 15, p.options_default.energy_max
    assert.equal 2, p.options_default.energy_increase
    assert.equal 3, p.options_default.energy_increase_win
    assert.deepEqual [], p.options_default.actions
    assert.equal 1, p.options_default.actions_start
    assert.equal 3, p.options_default.actions_max
    assert.deepEqual [], p.options_default.actions_active
    assert.deepEqual ['h', 'w'], p.options_default.actions_available
    assert.deepEqual ['b', 'actions_active'], p.options_round_reset

  it 'toJSON', ->
    p.options.id = 7
    p.options.actions = ['5', '6']
    assert.equal('s', p.toJSON().j)
    assert.deepEqual(['', ''], p.toJSON().actions)

  it 'toJSON (self)', ->
    p.options.id = 8
    assert.deepEqual(['5'], p.toJSON(8).actions)


  describe 'round', ->
    beforeEach ->
      PokerPlayer::round = spy = sinon.spy()
      p.options.rounds = 2
      p.options.actions = ['5']
      p.options.energy = 10
      p.options.energy_max = 15
      p.options.energy_increase = 2
      p.options.energy_increase_win = 3

    it 'default', ->
      p.round({cards: 'c', actions: ['1', '2']})
      assert.equal(1, spy.callCount)
      assert.deepEqual({cards: 'c', actions: ['5', '1', '2'], actions_added: ['1', '2'], energy: 12, energy_added: 2}, spy.getCall(0).args[0])

    it 'winner', ->
      p.options.win = 2
      p.round({cards: 'c', actions: ['1', '2']})
      assert.equal(3, spy.getCall(0).args[0].energy_added)

    it 'max energy', ->
      p.options.energy = 14
      p.round({cards: 'c', actions: ['1', '2']})
      assert.equal(1, spy.getCall(0).args[0].energy_added)

    it 'first round', ->
      p.options.rounds = 0
      p.round({cards: 'c', actions: ['1', '2']})
      assert.equal(0, spy.getCall(0).args[0].energy_added)


  describe 'commands', ->
    params = null
    beforeEach ->
      params = {blind: 2, progress: 0, bet_raise: 5, bet_raise_count: 0, pot: 10, bet_total: 10}
      p.options.bet = 0
      PokerPlayer::commands = spy = sinon.fake.returns [['fold'], ['call', 20], ['raise', 5, 50]]

    it 'default', ->
      p.commands(params)
      assert.equal 1, spy.callCount
      assert.deepEqual params, spy.getCall(0).args[0]

    it 'discard last param', ->
      assert.deepEqual [['fold'], ['call', 20], ['raise', 5]], p.commands(params)

    it 'only 1 command', ->
      PokerPlayer::commands = spy = sinon.fake.returns [['fold']]
      assert.deepEqual [['fold']], p.commands(params)

    it '3rd raise', ->
      assert.deepEqual [['fold'], ['call', 20]], p.commands(Object.assign {}, params, {bet_raise_count: 3})

    it 'blind raise', ->
      p.commands Object.assign {}, params, {blind: 11}
      assert.equal 16, spy.getCall(0).args[0].bet_raise

    it 'pot raise', ->
      p.commands Object.assign {}, params, {blind: 8, pot: 45}
      assert.equal 18, spy.getCall(0).args[0].bet_raise

    it 'add 3rd command', ->
      PokerPlayer::commands = spy = sinon.fake.returns [['fold'], ['raise', 10, 50]]
      assert.deepEqual [['fold'], ['raise', 10], ['raise', 20]], p.commands(params)

    it 'add 3rd command (blinds raise)', ->
      PokerPlayer::commands = spy = sinon.fake.returns [['fold'], ['raise', 5, 50]]
      assert.deepEqual [['fold'], ['raise', 5], ['raise', 15]], p.commands(Object.assign({}, params, {blind: 5}))

    it 'add 3rd command (big raise)', ->
      PokerPlayer::commands = spy = sinon.fake.returns [['fold'], ['raise', 26, 50]]
      assert.deepEqual [['fold'], ['raise', 26], ['raise', 50]], p.commands(params)

    it 'add 3rd command (no raise)', ->
      PokerPlayer::commands = spy = sinon.fake.returns [['fold'], ['raise', 50]]
      assert.deepEqual [['fold'], ['raise', 50]], p.commands(params)


  describe 'turn_action', ->
    beforeEach ->
      p.options.actions = ['a', 'b', 'c']
      p.options.energy = 5
      p.options_update = sinon.spy()

    it 'default', ->
      p.turn_action({action: 'b', energy: 3})
      assert.equal 1, p.options_update.callCount
      assert.deepEqual {actions: ['a', 'c'], energy: 2}, p.options_update.getCall(0).args[0]
