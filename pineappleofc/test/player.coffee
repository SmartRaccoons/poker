assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')
EventEmitter = require('events').EventEmitter


PokerOFCRank_calculate = ->
class PokerOFCRank
  calculate: -> PokerOFCRank_calculate.apply(@, arguments)


PokerPineappleOFCPlayer =  proxyquire('../player', {
  './rank':
    PokerOFCRank: PokerOFCRank
}).PokerPineappleOFCPlayer


describe 'PokerPineappleOFCPlayer', ->
  o = null
  spy = null
  up = null
  clock = null
  player1 = null
  beforeEach ->
    spy = sinon.spy()
    o = new PokerPineappleOFCPlayer()
    o.options_update = up = sinon.spy()
    clock = sinon.useFakeTimers()

  afterEach ->
    clock.restore()


  describe 'default', ->
    it 'options', ->
      assert.equal null, PokerPineappleOFCPlayer::options_default.id
      assert.equal null, PokerPineappleOFCPlayer::options_default.position
      assert.equal 0, PokerPineappleOFCPlayer::options_default.chips
      assert.equal 0, PokerPineappleOFCPlayer::options_default.chips_start
      assert.equal 0, PokerPineappleOFCPlayer::options_default.chips_change
      assert.equal 0, PokerPineappleOFCPlayer::options_default.points_change
      assert.deepEqual [[], [], []], PokerPineappleOFCPlayer::options_default.hand
      assert.equal false, PokerPineappleOFCPlayer::options_default.hand_full
      assert.equal 0, PokerPineappleOFCPlayer::options_default.hand_length
      assert.deepEqual [], PokerPineappleOFCPlayer::options_default.fold
      assert.equal false, PokerPineappleOFCPlayer::options_default.out
      assert.equal 0, PokerPineappleOFCPlayer::options_default.rounds
      assert.equal 0, PokerPineappleOFCPlayer::options_default.rounds_out
      assert.equal false, PokerPineappleOFCPlayer::options_default.fantasyland
      assert.deepEqual [], PokerPineappleOFCPlayer::options_default.cards
      assert.equal 0, PokerPineappleOFCPlayer::options_default.timebank
      assert.equal 0, PokerPineappleOFCPlayer::options_default.timeout
      assert.equal 0, PokerPineappleOFCPlayer::options_default.timeout_first
      assert.equal 0, PokerPineappleOFCPlayer::options_default.timeout_fantasyland
      assert.equal 0, PokerPineappleOFCPlayer::options_default.delay_player_turn
      assert.equal false, PokerPineappleOFCPlayer::options_default.playing
      assert.equal false, PokerPineappleOFCPlayer::options_default.waiting

    it 'options_round_reset', ->
      assert.deepEqual ['chips_change', 'points_change', 'hand', 'hand_full', 'hand_length', 'fold', 'cards', 'waiting'], PokerPineappleOFCPlayer::options_round_reset

    it 'filter', ->
      o.options.out = true
      o.options.fantasyland = true
      o.options.hand_full = false
      assert.equal true, o.filter({fantasyland: true, out: true})
      assert.equal false, o.filter({fantasyland: true, out: true, hand_full: true})


  describe 'cards_require', ->
    beforeEach ->
      o.options.playing = true
      o.options.fantasyland = false
      o.options.hand_full = false
      o.options.hand_length = 0
      o.options.fantasyland = false

    it 'default', ->
      assert.equal 5, o.cards_require()
      o.options.hand_length = 5
      assert.equal 3, o.cards_require()

    it 'before_start', ->
      assert.equal 0, o.cards_require(true)
      o.options.fantasyland = true
      assert.equal 14, o.cards_require(true)


  describe 'action_require', ->
    beforeEach ->
      o.options.playing = true
      o.options.fantasyland = false
      o.options.hand_full = false

    it 'default', ->
      assert.equal true, o.action_require()

    it 'not playing', ->
      o.options.playing = false
      assert.equal false, o.action_require()

    it 'fantasyland', ->
      o.options.fantasyland = true
      assert.equal false, o.action_require()

    it 'hand_full', ->
      o.options.hand_full = true
      assert.equal false, o.action_require()


  describe 'action_fantasyland', ->
    beforeEach ->
      o.options.rounds_out = 1
      o.options.waiting = true
      o.turn = sinon.spy()

    it 'default', ->
      o.action_fantasyland()
      assert.equal 1, o.turn.callCount
      assert.deepEqual {}, o.turn.getCall(0).args[0]

    it 'rounds_out 0', ->
      o.options.rounds_out = 0
      o.action_fantasyland()
      assert.equal 0, o.turn.callCount

    it 'waiting false', ->
      o.options.waiting = false
      o.action_fantasyland()
      assert.equal 0, o.turn.callCount


  describe 'options_bind (cards)', ->
    fn = null
    beforeEach ->
      fn = PokerPineappleOFCPlayer::options_bind['hand'].bind(o)
      PokerOFCRank_calculate = sinon.fake.returns 'calc'

    it 'rank update', ->
      o.options.hand_length = 5
      o.options.hand = [[1, 2], [3], [4]]
      o.options.fantasyland = 'ft'
      fn()
      assert.equal 1, up.callCount
      assert.deepEqual {rank: 'calc' }, up.getCall(0).args[0]
      assert.equal 1, PokerOFCRank_calculate.callCount
      assert.deepEqual [[1, 2], [3], [4] ], PokerOFCRank_calculate.getCall(0).args[0]
      assert.equal 'ft', PokerOFCRank_calculate.getCall(0).args[1]


  describe 'options_bind (out)', ->
    fn = null
    beforeEach ->
      fn = PokerPineappleOFCPlayer::options_bind['out'].bind(o)
      o.options.out = true
      o.options.rounds_out = 1
      o.on 'out', spy

    it 'default', ->
      fn()
      assert.equal(0, up.callCount)
      assert.equal 1, spy.callCount
      assert.deepEqual {out: true}, spy.getCall(0).args[0]

    it 'rounds_out reset', ->
      o.options.out = false
      fn()
      assert.equal(1, up.callCount)
      assert.deepEqual({rounds_out: 0}, up.getCall(0).args[0])

    it 'rounds_out reset no rounds', ->
      o.options.rounds_out = 0
      o.options.out = false
      fn()
      assert.equal(0, up.callCount)


  describe 'round', ->
    beforeEach ->
      o.ask = sinon.spy()
      o.options.rounds = 2
      o.options.rounds_out = 1
      o.options.timebank = 5
      o.options.timeout_fantasyland = 15
      o.options.hand = 'hand'

    it 'default', ->
      o.round({})
      assert.equal 1, up.callCount
      assert.deepEqual [[], [], []], up.getCall(0).args[0].hand
      assert.deepEqual [], up.getCall(0).args[0].cards
      assert.equal true, up.getCall(0).args[0].playing
      assert.equal 3, up.getCall(0).args[0].rounds
      assert.equal true, !('rounds_out' of up.getCall(0).args[0])
      assert.equal true, !('timebank' of up.getCall(0).args[0])
      assert.equal 0, o.ask.callCount

    it 'rounds_out', ->
      o.options.out = true
      o.round({})
      assert.equal 2, up.getCall(0).args[0].rounds_out

    it 'timebank', ->
      o.round({timebank: 3})
      assert.equal 8, up.getCall(0).args[0].timebank


  describe '_turn_cards_validate', ->
    beforeEach ->
      o.options.cards = ['Ah', 'Ac', 'Ad']
      o.options.hand = [ [1], [1, 2, 3], [1, 2, 3] ]

    it 'default', ->
      assert.deepEqual {hand: [ [1, 'Ah', 'Ac'], [1, 2, 3], [1, 2, 3] ], fold: ['Ad']}, o._turn_cards_validate [ ['Ah', 'Ac'], [], [] ]

    it 'errors', ->
      assert.equal null, o._turn_cards_validate [ ['Ah', 'Ac'], [] ]
      assert.equal null, o._turn_cards_validate 'hac'
      assert.equal null, o._turn_cards_validate [ ['Ah', 'Ac'], [], {} ]
      assert.equal null, o._turn_cards_validate [ ['Ah', 'Kc'], [], [] ]
      assert.equal null, o._turn_cards_validate [ ['Ah', 'Ah'], [], [] ]
      assert.equal null, o._turn_cards_validate [ ['Ah'], [], [] ]

    it '3 cards errors', ->
      assert.equal null, o._turn_cards_validate [ ['Ah', 'Ac'], ['Ad'], [] ]

    it 'hand errors', ->
      o.options.hand[0].push 5
      o.options.hand[1].push 5
      assert.equal null, o._turn_cards_validate [ ['Ah', 'Ac'], [], [] ]
      assert.equal null, o._turn_cards_validate [ [], ['Ah', 'Ac'], [] ]

    describe '5 cards', ->
      beforeEach ->
        o.options.cards = ['Ah', 'Ac', 'Ad', 'As', 'Kh']
        o.options.hand = [ [], [], [] ]

      it 'default', ->
        assert.equal true, !!o._turn_cards_validate [ [], [], ['Ah', 'Ac', 'Ad', 'As', 'Kh'] ]

      it 'errors', ->
        assert.equal null, o._turn_cards_validate [ ['Ah', 'Ac'], ['Ad', 'As'], [] ]

    describe '14 cards', ->
      beforeEach ->
        o.options.cards = ['Ah', 'Ac', 'Ad', 'As', 'Kh', 'Kc', 'Kd', 'Ks', 'Dh', 'Dc', 'Dd', 'Ds', 'Jh', 'Jc']
        o.options.hand = [ [], [], [] ]

      it 'default', ->
        assert.equal true, !!o._turn_cards_validate [ ['Ah', 'Ac', 'Ad'], ['As', 'Kh', 'Kc', 'Kd', 'Ks'], ['Dh', 'Dc', 'Dd', 'Ds', 'Jh'] ]

      it 'errors', ->
        assert.equal null, o._turn_cards_validate [ ['Ah', 'Ac'], ['Ad', 'As'], [] ]


  describe '_turn_cards_default', ->
    it '3 cards', ->
      o.options.cards = ['Ah', 'Ac', 'Ad']
      o.options.hand = [ [1, 2], [1, 2, 3, 4], [1, 2, 3, 4] ]
      assert.deepEqual [ [], ['Ac'], ['Ah'] ], o._turn_cards_default()
      o.options.hand = [ [1, 2], [1, 2, 3], [1, 2, 3, 4, 5] ]
      assert.deepEqual [ [], ['Ah', 'Ac'], [] ], o._turn_cards_default()
      o.options.hand = [ [1], [1, 2, 3, 4, 5], [1, 2, 3, 4, 5] ]
      assert.deepEqual [ ['Ah', 'Ac'], [], [] ], o._turn_cards_default()

    it '5 cards', ->
      o.options.cards = ['Ah', 'Ac', 'Ad', 'As', 'Kh']
      o.options.hand = [ [], [], [] ]
      assert.deepEqual [ [], [], ['Ah', 'Ac', 'Ad', 'As', 'Kh'] ], o._turn_cards_default()


  describe '_turn_cards', ->
    validate = null
    beforeEach ->
      o._turn_cards_default = sinon.fake.returns 'def'
      o._turn_cards_validate = sinon.fake.returns {fold: ['f'], hand: 'h'}
      o.options.fold = [1]
      o.options.hand_length = 4

    it 'default', ->
      assert.deepEqual {cards: [1, 2], fold: ['f']}, o._turn_cards {cards: [1, 2]}
      assert.equal 1, o._turn_cards_validate.callCount
      assert.deepEqual [1, 2], o._turn_cards_validate.getCall(0).args[0]
      assert.equal 0, o._turn_cards_default.callCount
      assert.equal 1, up.callCount
      assert.deepEqual {fold: [1, 'f'], hand: 'h', hand_length: 6, cards: []}, up.getCall(0).args[0]

    it 'hand full', ->
      o.options.hand_length = 11
      o._turn_cards {cards: [1, 2]}
      assert.equal true, up.getCall(0).args[0].hand_full

    it 'no fold', ->
      o._turn_cards_validate = sinon.fake.returns {fold: [], hand: 'h'}
      assert.deepEqual [], o._turn_cards( {cards: 'c'} ).fold
      assert.equal false, 'fold' of up.getCall(0).args[0]

    it 'error', ->
      o._turn_cards_validate = sinon.fake (cards)->
        if cards is 'def'
          return {fold: [], hand: 'h2'}
        return null
      assert.deepEqual {cards: 'def', fold: []}, o._turn_cards( {cards: 'c'} )
      assert.equal 1, o._turn_cards_default.callCount
      assert.equal 2, o._turn_cards_validate.callCount
      assert.equal 'def', o._turn_cards_validate.getCall(1).args[0]
      assert.equal 2, up.callCount
      assert.deepEqual {out: true}, up.getCall(0).args[0]


  describe 'turn', ->
    beforeEach ->
      o._turn_cards = sinon.fake.returns {cards: 'c', fold: 'f'}
      o.on 'turn', spy
      o.options.waiting = true
      o._activity_clear = sinon.spy()
      o._ask_date = new Date()

    it 'default', ->
      o.turn {cards: 'c'}
      assert.equal 1, o._activity_clear.callCount
      assert.equal 1, up.callCount
      assert.deepEqual {waiting: false}, up.getCall(0).args[0]
      assert.equal 1, spy.callCount
      assert.deepEqual {turn: {cards: 'c', fold: 'f'}}, spy.getCall(0).args[0]

    it 'auto turn', ->
      o.options.waiting = false
      o.turn {}
      assert.equal 0, up.callCount
      assert.equal 0, o._activity_clear.callCount

    it 'delay', ->
      o.options.delay_player_turn = 100
      o._ask_date = new Date()
      o.turn {}
      assert.equal 0, spy.callCount
      clock.tick(200)
      assert.equal 1, spy.callCount


  describe 'ask', ->
    beforeEach ->
      o.turn = sinon.spy()
      o._activity = sinon.spy()
      o.options.hand_length = 1
      o.options.timeout = 3
      o.options.timeout_first = 5
      o.options.timeout_fantasyland = 15
      o.on 'ask', spy

    it 'default', ->
      o.ask({cards: 'ca'})
      assert.deepEqual new Date(), o._ask_date
      assert.equal 1, up.callCount
      assert.deepEqual {cards: 'ca', waiting: true}, up.getCall(0).args[0]
      assert.equal 0, o.turn.callCount
      assert.equal 1, o._activity.callCount
      assert.equal 3, o._activity.getCall(0).args[0]
      assert.equal 1, spy.callCount

    it 'out', ->
      o.options.out = true
      o.ask({cards: 'ca'})
      assert.deepEqual {cards: 'ca'}, up.getCall(0).args[0]
      assert.equal 1, o.turn.callCount
      assert.deepEqual {}, o.turn.getCall(0).args[0]
      assert.equal 0, o._activity.callCount
      assert.equal 0, spy.callCount

    it 'out fantasyland', ->
      o.options.out = true
      o.options.fantasyland = true
      o.ask({cards: 'ca'})
      assert.equal 0, o.turn.callCount
      assert.equal 1, o._activity.callCount

    it 'first ask', ->
      o.options.hand_length = 0
      o.ask({cards: 'ca'})
      assert.equal 5, o._activity.getCall(0).args[0]

    it 'fantasyland', ->
      o.options.fantasyland = true
      o.options.hand_length = 0
      o.ask({cards: 'ca'})
      assert.equal 15, o._activity.getCall(0).args[0]


  describe '_get_ask', ->
    beforeEach ->
      o.options.waiting = true
      o.options.position = 2
      o.options.cards = [1, 2, 3]
      o.options.timebank = 4
      o.options.id = 5
      o._activity_timeout_left = sinon.fake.returns 10

    it 'default', ->
      assert.deepEqual {turn: {cards: [null, null, null]}, position: 2, timeout: 10, timebank: 4, timebank_active: false}, o._get_ask()[0]
      assert.deepEqual {5: {turn: {cards: [1, 2, 3]}} }, o._get_ask()[1]

    it 'not_fantasyland', ->
      assert.deepEqual [null, null, null], o._get_ask([1])[0].turn.cards
      assert.deepEqual {
        5: {turn: {cards: [1, 2, 3]}}
      }, o._get_ask([1])[1]

    it '5 cards', ->
      o.options.cards = [1, 2, 3, 4, 5]
      assert.deepEqual [1, 2, 3, 4, 5], o._get_ask()[0].turn.cards
      assert.deepEqual {}, o._get_ask()[1]

    it '5 cards (not_fantasyland)', ->
      o.options.cards = [1, 2, 3, 4, 5]
      assert.deepEqual [null, null, null, null, null], o._get_ask([1])[0].turn.cards
      assert.deepEqual {
        5: {turn: {cards: [1, 2, 3, 4, 5]}}
        1: {turn: {cards: [1, 2, 3, 4, 5]}}
      }, o._get_ask([1])[1]

    it 'timebank', ->
      o._activity_timebank = true
      assert.equal true, o._get_ask()[0].timebank_active

    it 'not waiting', ->
      o.options.waiting = false
      assert.equal null, o._get_ask()


  describe '_activity', ->
    beforeEach ->
      o.turn = sinon.spy()
      o.options.timebank = 0

    it 'default', ->
      o._activity 10
      assert.equal o._activity_timeout, 10000
      assert.equal o._activity_timeout_start, new Date().getTime()
      clock.tick 1000 * 10
      assert.equal 0, o.turn.callCount
      clock.tick 1000
      assert.equal 1, o.turn.callCount
      assert.deepEqual {}, o.turn.getCall(0).args[0]

    it '_activity (clear)', ->
      o._activity(1)
      o._activity_clear()
      clock.tick(1000 * 11)
      assert.equal(0, o.turn.callCount)

    describe 'timebank', ->
      beforeEach ->
        o.options.timebank = 5
        o.options.out = false
        o._activity(10)
        o._activity = sinon.spy()
        o.on 'timebank', spy

      it 'default', ->
        clock.tick 1000 * 11
        assert.equal(0, o.turn.callCount)
        assert.equal(1, o._activity.callCount)
        assert.equal(5, o._activity.getCall(0).args[0])
        assert.equal true, o._activity_timebank
        assert.equal 1, spy.callCount
        assert.deepEqual {timeout: 5}, spy.getCall(0).args[0]

      it 'out', ->
        o.options.out = true
        clock.tick 1000 * 11
        assert.equal(1, o.turn.callCount)
        assert.equal(0, o._activity.callCount)

      it 'already timebank active', ->
        o._activity_timebank = true
        clock.tick 1000 * 11
        assert.equal(1, o.turn.callCount)
        assert.equal(0, o._activity.callCount)

    describe '_activity_clear', ->
      beforeEach ->
        o._activity_callback = 111
        o.options.timebank = 32
        o._activity_timeout_start = new Date().getTime()
        clock.tick 1000 * 5 + 789

      it 'default', ->
        o._activity_clear()
        assert.equal null, o._activity_callback
        assert.equal 0, up.callCount

      it 'timebank', ->
        o._activity_timebank = true
        o._activity_clear()
        assert.equal null, o._activity_timebank
        assert.equal 1, up.callCount
        assert.deepEqual {timebank: 27}, up.getCall(0).args[0]

      it 'timebank (0)', ->
        o._activity_timebank = true
        clock.tick 100000
        o._activity_clear()
        assert.equal 0, up.getCall(0).args[0].timebank

    it '_activity_timeout_left', ->
      o._activity_timeout = 10 * 1000
      o._activity_timeout_start = new Date()
      assert.equal(10, o._activity_timeout_left())
      clock.tick(1000 * 5 + 400)
      assert.equal(5, o._activity_timeout_left())
      clock.tick(200)
      assert.equal(4, o._activity_timeout_left())
      clock.tick(1000 * 6)
      assert.equal(0, o._activity_timeout_left())


  describe 'round_end', ->
    beforeEach ->
      o.options.chips = 50
      o.options.rank = {fantasyland: true}

    it 'default', ->
      o.round_end({chips_change: 5, points_change: 2}, true)
      assert.equal 1, up.callCount
      assert.deepEqual {chips_change: 5, points_change: 2, chips: 55, fantasyland: true}, up.getCall(0).args[0]

    it 'not enough', ->
      o.round_end({chips_change: 5, points_change: 2}, false)
      assert.equal false, up.getCall(0).args[0].fantasyland

    it 'chips not enough fantasyland', ->
      o.round_end({chips_change: -50, points_change: 2}, true)
      assert.equal false, up.getCall(0).args[0].fantasyland


  describe 'toJSON', ->
    beforeEach ->
      o.options =
        id: 1
        position: 0
        chips: 5
        chips_change: -3
        hand: [[1, 2], [3], [4, 5]]
        fold: [1, 2]
        out: true
        timebank: 12
        fantasyland: true

      o._get_ask = sinon.fake.returns [{a: 'll', s: 'o'}, {5: {s: 'z', e: 'd'}}]

    it 'default', ->
      assert.deepEqual {
        id: 1
        position: 0
        chips: 5
        chips_change: -3
        hand: [[null, null], [null], [null, null]]
        fold: [null, null]
        out: true
        timebank: 12
        fantasyland: true
        ask: {a: 'll', s: 'o'}
      }, o.toJSON(100, [101])
      assert.equal 1, o._get_ask.callCount
      assert.deepEqual [101], o._get_ask.getCall(0).args[0]

    it 'get_ask missing', ->
      o._get_ask = -> null
      assert.equal false, 'ask' of o.toJSON(100, [101])

    it 'user_id match', ->
      json = o.toJSON(1, [101])
      assert.equal true, json.hero
      assert.deepEqual o.options.hand, json.hand
      assert.deepEqual o.options.fold, json.fold

    it 'ask match', ->
      assert.deepEqual {a: 'll', s: 'z', e: 'd'}, o.toJSON(5, [101]).ask

    it 'user_id missing', ->
      assert.deepEqual {a: 'll', s: 'o'}, o.toJSON(null, null).ask

    it 'not in fantasyland', ->
      json = o.toJSON(2, [2])
      assert.deepEqual o.options.hand, json.hand
      assert.deepEqual [null, null], json.fold

    it 'no fantasyland', ->
      json = o.toJSON(2, [])
      assert.deepEqual o.options.hand, json.hand
      assert.deepEqual [null, null], json.fold

    it 'no fantasyland (null)', ->
      json = o.toJSON(2)
      assert.deepEqual o.options.hand, json.hand
