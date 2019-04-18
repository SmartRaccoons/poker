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

Player = PokerAction::Player


describe 'PokerAction', ->
  clock = null
  spy = null
  p = null
  action = null
  beforeEach ->
    spy = sinon.spy()
    clock = sinon.useFakeTimers()
    Poker::toJSON = sinon.fake.returns {t: 'json'}
    p = new PokerAction({})
    action = sinon.spy()
    p.on 'actions', action

  afterEach ->
    clock.restore()


  describe 'default', ->
    it 'options', ->
      assert.equal(5, p._options_default.timeout_action)

    it 'deal', ->
      p._action_active_emit = sinon.spy()
      p._cards.emit 'deal'
      assert.equal 1, p._action_active_emit.callCount
      assert.equal 'deal', p._action_active_emit.getCall(0).args[0]

    it '_activity_action', ->
      p._activity_timeout_left = sinon.fake.returns 5
      p._activity_clear = sinon.spy()
      p.options.timeout_action = 3
      p._activity = sinon.spy()
      p._activity_action()
      assert.equal 1, p._activity.callCount
      assert.equal 8000, p._activity.getCall(0).args[0]
      assert.equal 1, p._activity_clear.callCount

    it '_opponents', ->
      p._waiting = 2
      p.players = sinon.fake.returns [{options: {position: 2}}, {options: {position: 4}}]
      assert.deepEqual([{options: {position: 4}}], p._opponents())
      assert.equal 1, p.players.callCount
      assert.deepEqual {fold: false}, p.players.getCall(0).args[0]

    it '_opponents (positions)', ->
      p.players = sinon.fake.returns [{options: {position: 2}}, {options: {position: 4}}]
      assert.deepEqual([2, 4], p._opponents(true))

    it '_round_player_addon', ->
      Poker::_round_player_addon = sinon.fake.returns {cards: [1, 2]}
      p._round_count = 1
      p._action_deal = sinon.fake.returns [5, 6]
      assert.deepEqual {actions: [5, 6], cards: [1, 2]}, p._round_player_addon({
        options: {actions: ['a'], actions_available: ['a', 'b'], actions_max: 3, actions_start: 2}
      })
      assert.equal(1, p._action_deal.callCount)
      assert.deepEqual(['a', 'b'], p._action_deal.getCall(0).args[0])
      assert.deepEqual(['a'], p._action_deal.getCall(0).args[1])
      assert.equal(2, p._action_deal.getCall(0).args[2])
      assert.equal(3, p._action_deal.getCall(0).args[3])

    it '_round_player_addon (next rounds)', ->
      p._round_count = 2
      p._action_deal = sinon.fake.returns [5, 6]
      p._round_player_addon({options: {actions: ['a']}})
      assert.equal(1, p._action_deal.getCall(0).args[2])

    it 'toJSON', ->
      p._action_active = sinon.fake.returns [{b: {z: 1}}, {1: {b: {d: 2}}}]
      assert.equal 'json', p.toJSON().t
      assert.equal 1, Poker::toJSON.callCount
      assert.deepEqual {b: {z: 1}}, p.toJSON().actions
      assert.deepEqual {b: {z: 1, d: 2}}, p.toJSON(1).actions

    it 'toJSON (without user_id)', ->
      p._action_active = sinon.fake.returns [{b: {z: 1}}, null]
      assert.equal 'json', p.toJSON().t
      assert.equal 1, Poker::toJSON.callCount
      assert.deepEqual {b: {z: 1}}, p.toJSON().actions
      assert.deepEqual {b: {z: 1}}, p.toJSON(1).actions

    it 'toJSON (without actions)', ->
      p._action_active = sinon.fake.returns null
      assert.equal false, 'actions' in Object.keys(p.toJSON())


  describe '_emit_round_params', ->
    beforeEach ->
      Poker::_emit_round_params = sinon.fake.returns [
        {
          p: '1'
          players: [null, {cards: ''}, {cards: ''}]
        }
        {
          3: {
            players: [null, {cards: 'c1'}, {cards: ''} ]
          }
        }
      ]
      p.players = sinon.fake.returns [{options: {id: 3, position: 1, energy_added: 2, actions_added: ['a']}}, {options: {id: 4, position: 2, energy_added: 3, actions_added: ['d', 'e']}}]

    it 'params for all', ->
      assert.deepEqual {
        p: '1', players: [
          null
          {energy_added: 2, actions_added: [''], cards: ''}
          {energy_added: 3, actions_added: ['', ''], cards: ''}
        ]
      }, p._emit_round_params()[0]

    it 'specific', ->
      assert.deepEqual [3, 4], Object.keys(p._emit_round_params()[1])
      assert.deepEqual {
        players:
          [
            null
            {energy_added: 2, actions_added: ['a'], cards: 'c1'}
            {energy_added: 3, actions_added: ['', ''], cards: ''}
          ]
      }, p._emit_round_params()[1][3]
      assert.deepEqual {
        players:
          [
            null
            {energy_added: 2, actions_added: [''], cards: ''}
            {energy_added: 3, actions_added: ['d', 'e'], cards: ''}
          ]
      }, p._emit_round_params()[1][4]


  describe '_waiting_commands', ->
    beforeEach ->
      p._actions_get = sinon.fake.returns [{action: 'a', params: ['p', 'a']}, {action: 'z'}]

    it 'default', ->
      Poker::_waiting_commands = sinon.fake.returns({commands: [1, 3]})
      assert.deepEqual({commands: [1, 3], actions: [ ['a', ['p', 'a'] ], ['z'] ]}, p._waiting_commands())

    it 'action required', ->
      p._action_required = {action: 'a', callback: 2, params: 'pr'}
      assert.deepEqual({action_required: ['a', 2, 'pr']}, p._waiting_commands())


  describe '_action_active', ->
    beforeEach ->
      p._actions = {
        'a':
          active_on: ['deal']
          active: sinon.fake.returns [null, {3: {'a': 'd'}}]
        'b':
          active_on: ['turn']
          active: sinon.fake.returns ['bc']
        'c':
          callbacks: []
      }

    it 'default', ->
      assert.deepEqual [{b: 'bc'}, {3: {a: {'a': 'd'}} }], p._action_active()

    it 'no values', ->
      p._actions['a'].active = -> null
      p._actions['b'].active = -> null
      assert.equal null, p._action_active()

    it 'filter', ->
      assert.deepEqual [null, {3: {a: {'a': 'd'} }}], p._action_active('deal')
      assert.deepEqual [ {'b': 'bc'}, null], p._action_active('turn')

    it 'filter (action_on missing)', ->
      p._actions['a'].active_on = null
      assert.equal null, p._action_active('deal')

    it 'merge', ->
      p._actions['b'].active = sinon.fake.returns [null, {3: {b: 'e'}}]
      assert.deepEqual [null, {3: {a: {a: 'd'}, b: {b: 'e'}}}], p._action_active()

    it 'combine common and user', ->
      p._actions['a'].active = sinon.fake.returns [{p1: 1, p2: 2}, {3: {p1: 2}}]
      p._actions['b'].active = sinon.fake.returns false
      assert.deepEqual [{a: {p1: 1, p2: 2}}, {3: {a: {p1: 2, p2: 2} } }], p._action_active()

    it '_action_active_emit', ->
      p._action_active = sinon.fake.returns ['p1', 'p2']
      p._action_active_emit('deal')
      assert.equal 1, p._action_active.callCount
      assert.deepEqual 'deal', p._action_active.getCall(0).args[0]
      assert.equal 1, action.callCount
      assert.equal 'p1', action.getCall(0).args[0]
      assert.equal 'p2', action.getCall(0).args[1]

    it 'deal trigger (no args)', ->
      p._action_active = sinon.fake.returns null
      p._action_active_emit('deal')
      assert.equal 1, p._action_active.callCount
      assert.equal 0, action.callCount


  describe '_action_deal', ->
    it 'default', ->
      el = p._action_deal(['a', 'b'])
      assert.equal 1, el.length
      assert.ok el[0] in ['a', 'b']

    it 'count', ->
      el = p._action_deal(['a', 'b', 'c'], [], 2, 3)
      assert.equal 2, el.length
      assert.ok el[0] isnt el[1]

    it 'max', ->
      assert.equal 1, p._action_deal(['a', 'b'], [], 2, 1).length
      assert.equal 0, p._action_deal(['a', 'b'], ['a'], 2, 1).length

    it 'predefined', ->
      assert.deepEqual ['c'], p._action_deal(['a', 'b', 'c'], ['b', 'a'], 1, 3)


  describe '_actions_get', ->
    beforeEach ->
      p._waiting = 1
      p._actions =
        a:
          energy: 4
          callbacks: [
            null
          ]
        b:
          energy: 5
          callbacks: [
            sinon.fake.returns ['p', 'r']
          ]
      p._players = [null, {options: {actions: ['a', 'b'], energy: 5}}]

    it 'default', ->
      assert.deepEqual [{action: 'a'}, {action: 'b', params: ['p', 'r']}], p._actions_get()
      assert.equal 1, p._actions['b'].callbacks[0].callCount

    it 'callback false', ->
      p._actions['b'].callbacks[0] = => false
      assert.deepEqual [{action: 'a'}], p._actions_get()

    it 'energy not enough', ->
      p._actions['b'].energy = 6
      assert.deepEqual [{action: 'a'}], p._actions_get()

    it 'turn', ->
      p._action_required_check = sinon.fake.returns false
      Poker::turn = spy
      p.turn()
      assert.equal 1, p._action_required_check.callCount
      assert.equal 1, spy.callCount

    it 'turn (check action)', ->
      p._action_required_check = sinon.fake.returns true
      Poker::turn = spy
      p.turn()
      assert.equal 0, spy.callCount


  describe 'turn_action', ->
    beforeEach ->
      p._action_required_check = sinon.fake.returns false
      p._actions_get = sinon.fake.returns [
        {action: 'a', params: [1, 2]}
        {action: 'b'}
      ]
      p._actions =
        'a':
          energy: 4
      p._board =
        turn_action: sinon.spy()
      p._waiting = 1
      p._players = [null, {turn_action: sinon.spy(), energy: 5}]

    it 'default', ->
      p.turn_action({action: 'a', param: 1})
      assert.deepEqual({callback: 1, action: 'a', params: [1, 2]}, p._action_required)
      assert.equal 2, p._action_required_check.callCount
      assert.equal 1, p._action_required_check.getCall(0).args[0]
      assert.equal 1, p._action_required_check.getCall(1).args[0]
      assert.equal 1, p._board.turn_action.callCount
      assert.deepEqual {action: 'a', position: 1}, p._board.turn_action.getCall(0).args[0]
      assert.equal 1, p._players[1].turn_action.callCount
      assert.deepEqual {energy: 4, action: 'a'}, p._players[1].turn_action.getCall(0).args[0]

    it 'action require', ->
      p._action_required_check = sinon.fake.returns true
      p.turn_action({action: 'a', param: 1})
      assert.equal 1, p._action_required_check.callCount
      assert.equal 0, p._actions_get.callCount

    it 'action error', ->
      p.turn_action({action: 'c'})
      assert.equal 1, p._action_required_check.callCount
      assert.equal null, p._action_required


  describe '_action_required_check', ->
    ask = null
    beforeEach ->
      ask = sinon.spy()
      p._activity_action = sinon.spy()
      p._action_required = {callback: 1, action: 'a', params: [4, 2, 0, 1]}
      p._actions =
        'a':
          callbacks: [
            null
            sinon.fake.returns [1, null, 'rr', 0]
            sinon.fake.returns [11]
          ]
      p._waiting = 1
      p._players = [{options: {id: 4}}, {options: {id: 5}}]
      p._activity_timeout_left = sinon.fake.returns 5
      p._get_ask = sinon.fake.returns ['as']
      p.on 'turn_action', spy
      p.on 'ask', ask

    it 'default', ->
      assert.equal true, p._action_required_check(1)
      assert.equal 1, p._activity_action.callCount
      assert.equal 1, p._actions['a'].callbacks[1].callCount
      assert.equal 2, p._actions['a'].callbacks[1].getCall(0).args[0]
      assert.equal 1, spy.callCount
      assert.deepEqual {position: 1, action: 'a', callback: 1, param: 1}, spy.getCall(0).args[0]

    it 'one param', ->
      p._actions['a'].callbacks[1] = sinon.fake.returns 'par'
      p._action_required_check(2)
      assert.equal 'par', spy.getCall(0).args[0].param
      assert.equal null, spy.getCall(0).args[1]

    it 'without callback params', ->
      p._actions['a'].callbacks[1] = sinon.fake.returns null
      p._action_required_check(2)
      assert.ok !('param' in Object.keys(spy.getCall(0).args[0]))

    it 'set def param', ->
      p._action_required_check()
      assert.equal 1, p._actions['a'].callbacks[1].getCall(0).args[0]

    it 'set 0 param', ->
      p._action_required_check(2)
      assert.equal 0, p._actions['a'].callbacks[1].getCall(0).args[0]

    it 'set def param (params null)', ->
      p._action_required.params = null
      p._action_required_check('supa')
      assert.equal 'supa', p._actions['a'].callbacks[1].getCall(0).args[0]

    it 'action_required missing', ->
      p._action_required = null
      assert.equal false, p._action_required_check()
      assert.equal 0, p._activity_action.callCount

    it 'individual', ->
      p._actions['a'].callbacks[1] = sinon.fake.returns [{a: '1', b: '2'}, [ [0, {a: '3'}], [1, {b: '4'}] ] ]
      p._action_required_check(2)
      assert.deepEqual {'4': {param: {a: '3', b: '2'} }, '5': { param: {a: '1', b: '4'} } }, spy.getCall(0).args[1]

    it 'individual (null)', ->
      p._actions['a'].callbacks[1] = sinon.fake.returns [null, [ [null, {a: '3'}] ] ]
      p._action_required_check(2)
      assert.deepEqual {'5': { param: {a: '3'} } }, spy.getCall(0).args[1]

    it 'individual (only one param)', ->
      p._actions['a'].callbacks[1] = sinon.fake.returns [null, {a: '3'} ]
      p._action_required_check(2)
      assert.deepEqual {'5': { param: {a: '3'} } }, spy.getCall(0).args[1]

    it 'next callback', ->
      assert.equal true, p._action_required_check(2)
      assert.equal 'rr', p._action_required.params
      assert.equal 1, p._get_ask.callCount
      assert.equal 1, ask.callCount
      assert.equal 'as', ask.getCall(0).args[0]

    it 'next callback (unexist)', ->
      p._action_required.callback = 2
      assert.equal true, p._action_required_check(2)
      assert.equal null, p._action_required
      assert.equal 1, ask.callCount
