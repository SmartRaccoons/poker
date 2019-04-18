events = require('events')
assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')


class Cards extends events.EventEmitter

class Poker extends events.EventEmitter
  constructor: (options)->
    super()
    @options = options
    @_cards = new Cards()

PokerAction = proxyquire('../poker', {
  '../poker/poker': { Poker }
}).PokerAction


describe 'PokerAction _actions', ->
  spy = null
  p = null
  callbacks = null
  beforeEach ->
    spy = sinon.spy()
    p = new PokerAction({})
    p._waiting = 1
    p._players = [null, {options: {actions: ['a', 'b'], actions_active: ['z'], energy: 5, cards: [1, 2], id: 3, position: 1}, options_update: sinon.spy()}, {options: {actions: ['d', 'e'], actions_active: [], energy: 4, id: 4, position: 2}, options_update: sinon.spy()}]
    p._board =
      options: {}
      options_update: sinon.spy()


  describe 'pirate', ->
    active = null
    beforeEach ->
      callbacks = p._actions['p'].callbacks
      p._board.options.cards = [{check: sinon.fake.returns(false)}, {check: sinon.fake.returns(true)}, {check: sinon.fake.returns(false)}]

    it 'params', ->
      assert.deepEqual [0, 2], callbacks[0].bind(p)()
      assert.equal 1, p._board.options.cards[0].check.callCount
      assert.deepEqual ['p', 'k', 'i'], p._board.options.cards[0].check.getCall(0).args[0]

    it 'params no cards', ->
      p._board.options.cards[0].check = -> true
      p._board.options.cards[2].check = -> true
      assert.equal null, callbacks[0].bind(p)()

    it 'turn', ->
      p._board.options_update = sinon.spy()
      p._board.options.cards = [null, {mark: spy}]
      assert.deepEqual {index: 1}, callbacks[1].bind(p)(1)
      assert.equal 1, spy.callCount
      assert.equal 'p', spy.getCall(0).args[0]
      assert.equal 1, p._board.options_update.callCount
      assert.deepEqual {cards: p._board.options.cards}, p._board.options_update.getCall(0).args[0]
      assert.equal true, p._board.options_update.getCall(0).args[1]


  describe 'wizard', ->
    active = null
    card = null
    beforeEach ->
      callbacks = p._actions['w'].callbacks
      class Card extends String
        toString: -> 'c'
        mark: -> spy.apply(null, arguments)
      card = new Card()
      p._cards =
        deal: sinon.fake.returns [card]
      p._board.options.cards = ['1']

    it 'params', ->
      assert.equal null, callbacks[0]

    it 'turn', ->
      assert.deepEqual {card}, callbacks[1].bind(p)()
      assert.equal 1, p._cards.deal.callCount
      assert.equal 1, p._board.options_update.callCount
      assert.deepEqual {cards: ['1', card]}, p._board.options_update.getCall(0).args[0]
      assert.equal 1, spy.callCount
      assert.equal 'w', spy.getCall(0).args[0]


  describe 'hunter', ->
    active = null
    card1 = null
    beforeEach ->
      callbacks = p._actions['h'].callbacks
      p._board.options.cards = [{check: sinon.fake.returns(false)}]
      card1 = p._board.options.cards[0]

    it 'params', ->
      assert.deepEqual [0, 1], callbacks[0].bind(p)()
      assert.equal 1, card1.check.callCount
      assert.deepEqual ['p', 'k'], card1.check.getCall(0).args[0]

    it 'params (false)', ->
      p._board.options.cards.push {check: sinon.fake.returns(true)}
      assert.equal false, callbacks[0].bind(p)()

    it 'params (no cards)', ->
      p._board.options.cards = []
      assert.equal false, callbacks[0].bind(p)()

    it 'turn', ->
      p._board.options.cards = [5, 6, {mark: spy}]
      assert.deepEqual [null, {index: 1}], callbacks[1].bind(p)(1)
      assert.equal 1, p._players[1].options_update.callCount
      assert.deepEqual {cards: [1, {mark: spy}]}, p._players[1].options_update.getCall(0).args[0]
      assert.equal 1, spy.callCount
      assert.equal 'h', spy.getCall(0).args[0]
      assert.equal 1, p._board.options_update.callCount
      assert.deepEqual {cards: [5, 6]}, p._board.options_update.getCall(0).args[0]


  describe 'seer', ->
    active = null
    beforeEach ->
      callbacks = p._actions['s'].callbacks
      active = p._actions['s'].active
      p._cards.next = sinon.fake.returns 'c'
      p.players = sinon.fake.returns [p._players[1], p._players[2]]

    it 'params', ->
      assert.equal null, callbacks[0]

    it 'turn', ->
      assert.deepEqual [null, {card: 'c'}], callbacks[1].bind(p)()
      assert.equal 1, p._cards.next.callCount
      assert.equal 1, p._players[1].options_update.callCount
      assert.deepEqual {actions_active: ['z', 's']}, p._players[1].options_update.getCall(0).args[0]

    it 'active on', ->
      assert.deepEqual ['deal'], p._actions['s'].active_on

    it 'active', ->
      p._players[1].options.actions_active = ['s']
      p._players[2].options.actions_active = ['s']
      assert.deepEqual [positions: [1, 2], {3: {card: 'c'}, 4: {card: 'c'}}], active.bind(p)()

    it 'active (none)', ->
      assert.equal null, active.bind(p)()


  describe 'frankenstein', ->
    beforeEach ->
      callbacks = p._actions['f'].callbacks
      p._cards =
        deal: sinon.fake.returns ['c']

    it 'params', ->
      assert.equal null, callbacks[0]

    it 'turn', ->
      assert.deepEqual [null, {card: 'c'}, [0, 1, 2]], callbacks[1].bind(p)()
      assert.equal 1, p._cards.deal.callCount
      assert.equal 1, p._players[1].options_update.callCount
      assert.deepEqual {cards: [1, 2, 'c']}, p._players[1].options_update.getCall(0).args[0]

    it 'turn 2', ->
      p._players[1].options.cards = [1, 2, 3]
      assert.deepEqual [null, {index: 1}], callbacks[2].bind(p)(1)
      assert.equal 1, p._players[1].options_update.callCount
      assert.deepEqual {cards: [1, 3]}, p._players[1].options_update.getCall(0).args[0]


  describe 'knight', ->
    card1 = null
    card3 = null
    beforeEach ->
      callbacks = p._actions['k'].callbacks
      p._board.options.cards = [
        {check: sinon.fake.returns(false), mark: sinon.spy()}
        {check: sinon.fake.returns(true)}
        {check: sinon.fake.returns(true), mark: sinon.spy()}
      ]
      card1 = p._board.options.cards[0]
      card3 = p._board.options.cards[2]

    it 'params', ->
      assert.equal true, callbacks[0].bind(p)()
      assert.equal 1, card1.check.callCount
      assert.deepEqual ['p', 'k'], card1.check.getCall(0).args[0]

    it 'params (no check)', ->
      p._board.options.cards[0].check = -> true
      assert.equal false, callbacks[0].bind(p)()

    it 'turn', ->
      card3.check = -> false
      assert.deepEqual [0, 2], callbacks[1].bind(p)(2)
      assert.equal 1, card1.check.callCount
      assert.deepEqual ['p', 'k'], card1.check.getCall(0).args[0]
      assert.equal 1, card1.mark.callCount
      assert.equal 'k', card1.mark.getCall(0).args[0]


  describe 'vampire', ->
    beforeEach ->
      callbacks = p._actions['v'].callbacks
      p._opponents = sinon.fake.returns [{options: {energy: 2, position: 1}}, {options: {energy: 0, position: 3}}]

    it 'params', ->
      assert.deepEqual [1], callbacks[0].bind(p)()

    it 'params (no actions)', ->
      p._opponents = sinon.fake.returns []
      assert.equal false, callbacks[0].bind(p)()

    it 'turn', ->
      assert.deepEqual {position: 2, energy: 3}, callbacks[1].bind(p)(2)
      assert.equal 1, p._players[1].options_update.callCount
      assert.deepEqual {energy: 8}, p._players[1].options_update.getCall(0).args[0]
      assert.equal 1, p._players[2].options_update.callCount
      assert.deepEqual {energy: 1}, p._players[2].options_update.getCall(0).args[0]

    it 'turn (less energy)', ->
      p._players[2].options.energy = 2
      assert.deepEqual {position: 2, energy: 2}, callbacks[1].bind(p)(2)
      assert.deepEqual {energy: 7}, p._players[1].options_update.getCall(0).args[0]
      assert.deepEqual {energy: 0}, p._players[2].options_update.getCall(0).args[0]


  describe 'doctor', ->
    beforeEach ->
      callbacks = p._actions['d'].callbacks
      p._board.options.actions = [{action: 'd'}, {doctor: 0, action: 'b'}, {action: 'z'}, {action: 'h'}]

    it 'params', ->
      assert.equal true, callbacks[0].bind(p)()

    it 'params (other cards)', ->
      p._board.options.actions = [{action: 'd'}, {doctor: 0, action: 'b'}]
      assert.equal false, callbacks[0].bind(p)()

    it 'turn', ->
      assert.deepEqual {action: 'h'}, callbacks[1].bind(p)()
      assert.equal 1, p._board.options_update.callCount
      assert.deepEqual {actions: [{action: 'd'}, {doctor: 0, action: 'b'}, {action: 'z'}, {doctor: 1, action: 'h'}]}, p._board.options_update.getCall(0).args[0]
      assert.equal 1, p._players[1].options_update.callCount
      assert.deepEqual {actions: ['a', 'b', 'h']}, p._players[1].options_update.getCall(0).args[0]


  describe 'thief', ->
    beforeEach ->
      callbacks = p._actions['t'].callbacks
      p._opponents = sinon.fake.returns [{options: {actions: [1], position: 1}}, {options: {actions: [], position: 3}}]

    it 'params', ->
      assert.deepEqual [1], callbacks[0].bind(p)()

    it 'params (no actions)', ->
      p._opponents = sinon.fake.returns []
      assert.equal false, callbacks[0].bind(p)()

    it 'turn', ->
      callbacks[1].bind(p)(2)
      assert.equal 1, p._players[1].options_update.callCount
      assert.equal 3, p._players[1].options_update.getCall(0).args[0].actions.length
      assert.equal 1, p._players[2].options_update.callCount
      assert.equal 1, p._players[2].options_update.getCall(0).args[0].actions.length

    it 'turn (variables)', ->
      p._players[2] = {options: {actions: ['d']}, options_update: sinon.spy()}
      assert.deepEqual [{position: 2}, [ [1, {action: 'd'}], [2, {action: 'd'}] ] ], callbacks[1].bind(p)(2)
