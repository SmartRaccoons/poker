assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')
_cloneDeep = require('lodash').cloneDeep
EventEmitter = require('events').EventEmitter


PokerOFCRank_calculate = ->
PokerOFCRank_automove_fantasyland = ->
class PokerOFCRank
  calculate: -> PokerOFCRank_calculate.apply(@, arguments)
  automove_fantasyland: -> PokerOFCRank_automove_fantasyland.apply(@, arguments)


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
      assert.deepEqual [], PokerPineappleOFCPlayer::options_default.hand
      assert.equal false, PokerPineappleOFCPlayer::options_default.hand_full
      assert.equal 0, PokerPineappleOFCPlayer::options_default.hand_length
      assert.deepEqual [], PokerPineappleOFCPlayer::options_default.fold
      assert.equal false, PokerPineappleOFCPlayer::options_default.out
      assert.equal 0, PokerPineappleOFCPlayer::options_default.rounds
      assert.equal 0, PokerPineappleOFCPlayer::options_default.turns_out
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

    it '_turns_out_limit', ->
      o.options.turns_out = 3
      assert.equal true, o._turns_out_limit()
      o.options.turns_out = 2
      assert.equal false, o._turns_out_limit()

    it '_rank_calculate', ->
      o.options.fantasyland = 'ft'
      PokerOFCRank_calculate = sinon.fake.returns 'calc'
      assert.equal 'calc', o._rank_calculate([{l: 0, card: 'Qc'}, {l: 1, card: 'Kc'}, {l: 2, card: 'Ac'}, {l: 0, card: 'Tc'}])
      assert.deepEqual [['Qc', 'Tc'], ['Kc'], ['Ac'] ], PokerOFCRank_calculate.getCall(0).args[0]
      assert.equal 'ft', PokerOFCRank_calculate.getCall(0).args[1]


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
      o._turns_out_limit = sinon.fake.returns true
      o.options.waiting = true
      o.turn = sinon.spy()

    it 'default', ->
      o.action_fantasyland()
      assert.equal 1, o.turn.callCount
      assert.equal 1, o._turns_out_limit.callCount

    it 'turns out limit', ->
      o._turns_out_limit = -> false
      o.action_fantasyland()
      assert.equal 0, o.turn.callCount

    it 'waiting false', ->
      o.options.waiting = false
      o.action_fantasyland()
      assert.equal 0, o.turn.callCount


  describe 'options_bind (hand)', ->
    fn = null
    beforeEach ->
      fn = PokerPineappleOFCPlayer::options_bind['hand'].bind(o)
      o._rank_calculate = sinon.fake.returns 'clc'

    it 'rank update', ->
      o.options.hand = 'hnd'
      fn()
      assert.equal 1, up.callCount
      assert.deepEqual {rank: 'clc' }, up.getCall(0).args[0]
      assert.equal 1, o._rank_calculate.callCount
      assert.equal 'hnd', o._rank_calculate.getCall(0).args[0]


  describe 'options_bind (turns_out)', ->
    fn = null
    beforeEach ->
      fn = PokerPineappleOFCPlayer::options_bind['turns_out'].bind(o)
      o._turns_out_limit = sinon.fake.returns false

    it 'default', ->
      fn()
      assert.equal 0, up.callCount
      assert.equal 1, o._turns_out_limit.callCount

    it 'out', ->
      o._turns_out_limit = -> true
      fn()
      assert.equal 1, up.callCount
      assert.deepEqual {out: true}, up.getCall(0).args[0]


  describe 'options_bind (out)', ->
    fn = null
    beforeEach ->
      fn = PokerPineappleOFCPlayer::options_bind['out'].bind(o)
      o.options.out = true
      o.options.turns_out = 1
      o.on 'out', spy

    it 'default', ->
      fn()
      assert.equal(0, up.callCount)
      assert.equal 1, spy.callCount
      assert.deepEqual {out: true}, spy.getCall(0).args[0]

    it 'reset', ->
      o.options.out = false
      fn()
      assert.equal(1, up.callCount)
      assert.deepEqual({turns_out: 0}, up.getCall(0).args[0])


  describe 'round', ->
    beforeEach ->
      o.ask = sinon.spy()
      o.options.rounds = 2
      o.options.timebank = 5
      o.options.timeout_fantasyland = 15
      o.options.hand = 'hand'

    it 'default', ->
      o.round({})
      assert.equal 1, up.callCount
      assert.deepEqual [], up.getCall(0).args[0].hand
      assert.deepEqual [], up.getCall(0).args[0].cards
      assert.equal true, up.getCall(0).args[0].playing
      assert.equal 3, up.getCall(0).args[0].rounds
      assert.equal true, !('timebank' of up.getCall(0).args[0])
      assert.equal 0, o.ask.callCount

    it 'timebank', ->
      o.round({timebank: 3})
      assert.equal 8, up.getCall(0).args[0].timebank

  it 'out', ->
    o.out {out: true}
    assert.equal 1, up.callCount
    assert.deepEqual {out: true}, up.getCall(0).args[0]


  describe '_turn_automove_fantasyland', ->
    beforeEach ->
      PokerOFCRank_automove_fantasyland = sinon.fake.returns {
        hand: [
          [ 'Qc', 'Qh' ]
          [ 'Tc', 'Th' ]
          [ 'Ac', 'Ah' ]
        ]
        fold: ['2c']
      }
      o.options.cards = [
        {i: 1, card: 'Qc', l: 2, r: 4}
        {i: 2, card: 'Qh', l: 2, r: 4}
        {i: 3, card: 'Tc', l: 2, r: 4}
        {i: 4, card: 'Th', l: 2, r: 4}
        {i: 5, card: 'Ac', l: 2, r: 4}
        {i: 6, card: 'Ah', l: 2, r: 4}
        {i: 7, card: '2c', l: 2, r: 4}
      ]

    it '_turn_automove_fantasyland', ->
      assert.deepEqual {
        cards: [
          {i: 1, card: 'Qc', l: 0, r: 0}
          {i: 2, card: 'Qh', l: 0, r: 1}
          {i: 3, card: 'Tc', l: 1, r: 0}
          {i: 4, card: 'Th', l: 1, r: 1}
          {i: 5, card: 'Ac', l: 2, r: 0}
          {i: 6, card: 'Ah', l: 2, r: 1}
        ]
        fold: [
          {i: 7, card: '2c'}
        ]
      }, o._turn_automove_fantasyland()
      assert.equal 1, PokerOFCRank_automove_fantasyland.callCount
      assert.deepEqual ['Qc', 'Qh', 'Tc', 'Th', 'Ac', 'Ah', '2c'], PokerOFCRank_automove_fantasyland.getCall(0).args[0]


  describe '_turn_cards_temp', ->
    cards = null
    beforeEach ->
      cards = [ {i: 1, card: 'Ah', l: 3}, {i: 2, card: 'Ac', l: 3}, {i: 3, card: 'Ad', l: 3} ]
      o.options.cards = _cloneDeep(cards)
      o.options.hand = [ {i: 5, card: 'Th', l: 0}, {i: 6, card: 'Tc', l: 1}, {i: 7, card: 'Td', l: 2} ]

    it 'default', ->
      assert.deepEqual {slots_completed: [1, 1, 1], slots_free: [2, 4, 4], place: 2, cards}, o._turn_cards_temp([])

    it '5 cards', ->
      o.options.cards = cards.concat [ {i: 10, card: '2h'},  {i: 11, card: '3h'} ]
      assert.equal 5, o._turn_cards_temp([]).place

    it 'no i for card', ->
      result = o._turn_cards_temp [ {} ]
      assert.deepEqual {slots_completed: [1, 1, 1], slots_free: [2, 4, 4], place: 2, cards}, o._turn_cards_temp [  ]

    it 'turn_cards', ->
      result = o._turn_cards_temp [ {i: 1, l: 1} ]
      cards[0].l = 1
      assert.deepEqual cards, result.cards
      assert.equal 1, result.place
      assert.deepEqual [2, 3, 4], result.slots_free

    it 'turn_cards (no index)', ->
      result = o._turn_cards_temp [ {l: 1} ]
      assert.deepEqual cards, result.cards

    it 'turn_cards (not exist)', ->
      result = o._turn_cards_temp [ {i: 6, l: 1} ]
      assert.deepEqual cards, result.cards

    it 'turn_cards (not array)', ->
      result = o._turn_cards_temp {}
      assert.deepEqual cards, result.cards
      assert.deepEqual 2, result.place

    it 'turn_cards (line 3)', ->
      result = o._turn_cards_temp [ {i: 1, l: 3} ]
      assert.equal 2, result.place
      assert.deepEqual [2, 4, 4], result.slots_free

    it 'cards not exist', ->
      result = o._turn_cards_temp [ {i: 1} ]
      assert.deepEqual cards, result.cards

    it 'cards not in', ->
      result = o._turn_cards_temp [ {i: 1, l: -1} ]
      assert.deepEqual cards, result.cards

    it 'no free slots', ->
      o.options.hand[1].l = 0
      o.options.hand[2].l = 0
      result = o._turn_cards_temp [ {i: 1, l: 0} ]
      assert.deepEqual cards, result.cards

    it 'no places', ->
      result = o._turn_cards_temp [ {i: 1, l: 1}, {i: 2, l: 1}, {i: 3, l: 1} ]
      cards[0].l = 1
      cards[1].l = 1
      cards[2].l = 3
      assert.deepEqual cards, result.cards

    it 'row', ->
      result = o._turn_cards_temp [ {i: 1, l: 3, r: 13} ]
      cards[0].r = 13
      assert.deepEqual cards, result.cards

    it 'row (minus)', ->
      result = o._turn_cards_temp [ {i: 1, l: 3, r: -1} ]
      assert.deepEqual cards, result.cards

    it 'row (max)', ->
      result = o._turn_cards_temp [ {i: 1, l: 3, r: 14} ]
      assert.deepEqual cards, result.cards


  describe '_turn_cards_check', ->
    cards_temp = null
    beforeEach ->
      cards_temp =
        slots_completed: [1, 2, 1]
        slots_free: [1, 1, 4]
        place: 2
        cards: [ {i: 11, l: 3}, {i: 12, l: 3}, {i: 13, l: 3} ]
      o._turn_cards_temp = sinon.fake.returns cards_temp

    it 'default', ->
      assert.deepEqual {
        cards: [ {i: 11, l: 0, r: 1}, {i: 12, l: 1, r: 2} ]
        fold: [ {i: 13, l: 3} ]
        automove: true
      }, o._turn_cards_check 'pr'
      assert.equal 1, o._turn_cards_temp.callCount
      assert.equal 'pr', o._turn_cards_temp.getCall(0).args[0]

    it 'next line', ->
      cards_temp.place = 3
      result = o._turn_cards_check()
      assert.deepEqual [ {i: 11, l: 0, r: 1}, {i: 12, l: 1, r: 2}, {i: 13, l: 2, r: 1} ], result.cards
      assert.deepEqual [ ], result.fold

    it 'automove false', ->
      cards_temp.place = 0
      cards_temp.cards[0].l = 1
      result = o._turn_cards_check()
      assert.deepEqual [ {i: 11, l: 1, r: 2} ], result.cards
      assert.deepEqual [ {i: 12, l: 3}, {i: 13, l: 3} ], result.fold

    it 'sort', ->
      cards_temp.place = 0
      cards_temp.cards[0].r = 3
      cards_temp.cards[0].l = 1
      cards_temp.cards[1].r = 1
      cards_temp.cards[1].l = 1
      assert.deepEqual [12, 11], o._turn_cards_check('pr').cards.map (c)-> c.i

    it 'sort (no r)', ->
      cards_temp.place = 0
      delete cards_temp.cards[0].r
      cards_temp.cards[0].l = 1
      cards_temp.cards[1].r = 0
      cards_temp.cards[1].l = 1
      assert.deepEqual [12, 11], o._turn_cards_check('pr').cards.map (c)-> c.i

    it 'sort (place 1 in the last)', ->
      cards_temp.place = 1
      cards_temp.cards[0].r = 2
      cards_temp.cards[0].l = 3
      cards_temp.cards[1].r = 0
      cards_temp.cards[1].l = 1
      assert.deepEqual [12, 11], o._turn_cards_check('pr').cards.map (c)-> c.i


  describe '_turn_cards', ->
    validate = null
    beforeEach ->
      o._turn_automove_fantasyland = sinon.fake.returns {cards: ['c2'], fold: [{i: 1, card: 'c2', r: 2, l: 3}]}
      o._turn_cards_check = sinon.fake.returns {cards: ['c'], fold: [{i: 1, card: 'c', r: 2, l: 3}], automove: true}
      o.options.fold = [1]
      o.options.hand = [2]
      o.options.hand_length = 4

    it 'default', ->
      assert.deepEqual {cards: ['c'], fold: [ {i: 1, card: 'c'} ]}, o._turn_cards {cards: 'cu'}
      assert.equal 1, o._turn_cards_check.callCount
      assert.equal 'cu', o._turn_cards_check.getCall(0).args[0]
      assert.equal 1, up.callCount
      assert.deepEqual {hand: [2, 'c'], cards: [], fold: [1, {i: 1, card: 'c'}], hand_length: 5}, up.getCall(0).args[0]
      assert.equal 0, o._turn_automove_fantasyland.callCount


    describe 'automove fantasyland', ->
      beforeEach ->
        o.options.cards = [1, 2, 3, 4, 5, 6]
        o._rank_calculate = sinon.fake.returns {valid: true}

      it 'default', ->
        assert.deepEqual {cards: ['c2'], fold: [ {i: 1, card: 'c2'} ]}, o._turn_cards {cards: 'cu'}
        assert.equal 1, o._turn_automove_fantasyland.callCount
        assert.equal 0, o._rank_calculate.callCount

      it 'no automove', ->
        o._turn_cards_check = sinon.fake.returns {cards: ['c'], fold: [], automove: false}
        o._turn_cards {cards: 'cu'}
        assert.equal 0, o._turn_automove_fantasyland.callCount
        assert.equal 1, o._rank_calculate.callCount
        assert.deepEqual ['c'], o._rank_calculate.getCall(0).args[0]

      it 'no automove and invalid', ->
        o._rank_calculate = sinon.fake.returns {valid: false}
        o._turn_cards_check = sinon.fake.returns {cards: ['c'], fold: [], automove: false}
        o._turn_cards {cards: 'cu'}
        assert.equal 1, o._turn_automove_fantasyland.callCount
        assert.equal 1, o._rank_calculate.callCount



    it 'no fold', ->
      o._turn_cards_check = sinon.fake.returns {cards: ['c'], fold: [], automove: true}
      assert.deepEqual [], o._turn_cards( {cards: ['cu']} ).fold
      assert.equal false, 'fold' of up.getCall(0).args[0]

    it 'hand full', ->
      o.options.hand_length = 12
      o._turn_cards( {cards: ['cu']} )
      assert.equal true, up.getCall(0).args[0].hand_full


  describe 'turn_temp', ->
    beforeEach ->
      o.on 'turn_temp', spy
      o.options.position = 1
      o._turn_cards_temp = sinon.fake.returns {cards: [ {i: 11, card: 'Qs', l: 3, r: 5},  {i: 12, card: 'As', l: 4, r: 6} ]}

    it 'default', ->
      o.turn_temp {cards: 'c'}
      assert.equal 1, up.callCount
      assert.deepEqual {cards: [ {i: 11, card: 'Qs', l: 3, r: 5},  {i: 12, card: 'As', l: 4, r: 6} ], turns_out: 0}, up.getCall(0).args[0]
      assert.equal 1, o._turn_cards_temp.callCount
      assert.equal 'c', o._turn_cards_temp.getCall(0).args[0]
      assert.equal 1, spy.callCount
      assert.deepEqual {position: 1, turn: { cards: [ {i: 11, l: 3, r: 5},  {i: 12, l: 4, r: 6} ] } }, spy.getCall(0).args[0]

    it 'no params', ->
      o.turn_temp()
      assert.equal undefined, o._turn_cards_temp.getCall(0).args[0]


  describe 'turn', ->
    beforeEach ->
      o._turn_cards = sinon.fake.returns {cards: 'c', fold: 'f'}
      o.on 'turn', spy
      o.options.waiting = true
      o.options.turns_out = 1
      o._activity_clear = sinon.spy()
      o._ask_date = new Date()

    it 'default', ->
      o.turn {cards: 'c'}
      assert.equal 1, o._activity_clear.callCount
      assert.equal 2, up.callCount
      assert.deepEqual {waiting: false}, up.getCall(0).args[0]
      assert.deepEqual {turns_out: 0}, up.getCall(1).args[0]
      assert.equal 1, spy.callCount
      assert.deepEqual {cards: 'c', fold: 'f'}, spy.getCall(0).args[0]

    it 'auto turn', ->
      o.options.waiting = false
      o.turn()
      assert.equal 1, up.callCount
      assert.deepEqual {turns_out: 2}, up.getCall(0).args[0]
      assert.equal 0, o._activity_clear.callCount

    it 'delay', ->
      o.options.delay_player_turn = 100
      o._ask_date = new Date()
      o.turn()
      assert.equal 0, spy.callCount
      clock.tick(200)
      assert.equal 1, spy.callCount


  describe '_get_turn', ->
    turn = null
    beforeEach ->
      turn =
        cards: [ {i: 5, card: 'Qd'} ]
        fold: [ {i: 6, card: '2d'} ]
      o.options.id = 5
      o.options.position = 2
      o.options.fantasyland = false

    it 'default', ->
      result = o._get_turn turn, [], 'pla'
      assert.deepEqual {position: 2, turn: { cards: [ {i: 5, card: 'Qd'} ], fold: [ {i: 6} ] }}, result[0]
      assert.deepEqual {5: { turn: _cloneDeep(turn) }}, result[1]

    it 'some in fantasyland', ->
      result = o._get_turn turn, [2], 'pla'
      assert.deepEqual [ {i: 5} ], result[0].turn.cards
      assert.deepEqual {cards: [ {i: 5, card: 'Qd'} ], fold: [ {i: 6} ]}, result[1][2].turn

    it 'turn fantasyland', ->
      o.options.fantasyland = true
      result = o._get_turn turn, [], 'pla'
      assert.deepEqual [ {i: 5} ], result[0].turn.cards
      assert.equal 'pla', result[0].players
      assert.equal false, 'players' in Object.keys(result[1][5])

    it 'turn fantasyland (some in)', ->
      o.options.fantasyland = true
      result = o._get_turn turn, [2], 'pla'
      assert.equal false, 'players' in Object.keys(result[0])
      assert.deepEqual ['5'], Object.keys(result[1])
      assert.equal 'pla', result[1][5].players


  describe 'ask', ->
    beforeEach ->
      o.turn = sinon.spy()
      o._activity = sinon.spy()
      o.options.hand_length = 1
      o.options.timeout = 3
      o.options.timeout_first = 5
      o.options.timeout_fantasyland = 15
      o._turns_out_limit = sinon.fake.returns false
      o.on 'ask', spy

    it 'default', ->
      o.ask {cards: [ {i: 1, card: 'Q'}, {i: 2, card: 'K'} ] }
      assert.deepEqual new Date(), o._ask_date
      assert.equal 1, up.callCount
      assert.deepEqual {cards: [ {i: 1, card: 'Q', l: 3, r: 0}, {i: 2, card: 'K', l: 3, r: 1} ], waiting: true}, up.getCall(0).args[0]
      assert.equal 0, o.turn.callCount
      assert.equal 1, o._activity.callCount
      assert.equal 3, o._activity.getCall(0).args[0]
      assert.equal 1, spy.callCount
      assert.equal 1, o._turns_out_limit.callCount

    it 'out', ->
      o._turns_out_limit = -> true
      o.ask({cards: [{i: 1}]})
      assert.deepEqual {cards: [{i: 1, l: 3, r: 0}]}, up.getCall(0).args[0]
      assert.equal 1, o.turn.callCount
      assert.equal 0, o._activity.callCount
      assert.equal 0, spy.callCount

    it 'out fantasyland', ->
      o.options.out = true
      o.options.fantasyland = true
      o.ask({cards: []})
      assert.equal 0, o.turn.callCount
      assert.equal 1, o._activity.callCount

    it 'first ask', ->
      o.options.hand_length = 0
      o.ask({cards: []})
      assert.equal 5, o._activity.getCall(0).args[0]

    it 'fantasyland', ->
      o.options.fantasyland = true
      o.options.hand_length = 0
      o.ask({cards: []})
      assert.equal 15, o._activity.getCall(0).args[0]


  describe '_get_ask', ->
    beforeEach ->
      o.options.waiting = true
      o.options.position = 2
      o.options.cards = [ {i: 1, card: 'a'}, {i: 2, card: 'b'}, {i: 3, card: 'c'} ]
      o.options.timebank = 4
      o.options.id = 5
      o._activity_timeout_left = sinon.fake.returns 10

    it 'default', ->
      assert.deepEqual {turn: {cards: [ {i: 1}, {i: 2}, {i: 3} ]}, position: 2, timeout: 10, timebank: 4, timebank_active: false}, o._get_ask()[0]
      assert.deepEqual {5: {turn: {cards: [ {i: 1, card: 'a'}, {i: 2, card: 'b'}, {i: 3, card: 'c'} ]}} }, o._get_ask()[1]

    it 'not_fantasyland', ->
      assert.deepEqual [ {i: 1}, {i: 2}, {i: 3} ], o._get_ask([1])[0].turn.cards
      assert.deepEqual {
        5: {turn: {cards: [ {i: 1, card: 'a'}, {i: 2, card: 'b'}, {i: 3, card: 'c'} ]}}
      }, o._get_ask([1])[1]

    it '5 cards', ->
      o.options.cards = cards = [ {i: 1, card: 'a'}, {i: 2, card: 'b'}, {i: 3, card: 'c'}, {i: 4, card: 'd'}, {i: 5, card: 'e'} ]
      assert.deepEqual cards, o._get_ask()[0].turn.cards
      assert.deepEqual {}, o._get_ask()[1]

    it '5 cards (not_fantasyland)', ->
      o.options.cards = cards = [ {i: 1, card: 'a'}, {i: 2, card: 'b'}, {i: 3, card: 'c'}, {i: 4, card: 'd'}, {i: 5, card: 'e'} ]
      assert.deepEqual [ {i: 1}, {i: 2}, {i: 3}, {i: 4}, {i: 5} ], o._get_ask([1])[0].turn.cards
      assert.deepEqual {
        5: {turn: {cards}}
        1: {turn: {cards}}
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
      o._turns_out_limit = -> false

    it 'default', ->
      o._activity 10
      assert.equal o._activity_timeout, 10000
      assert.equal o._activity_timeout_start, new Date().getTime()
      clock.tick 1000 * 10
      assert.equal 0, o.turn.callCount
      clock.tick 1000
      assert.equal 1, o.turn.callCount

    it '_activity (clear)', ->
      o._activity(1)
      o._activity_clear()
      clock.tick(1000 * 11)
      assert.equal(0, o.turn.callCount)

    describe 'timebank', ->
      beforeEach ->
        o.options.timebank = 5
        o._turns_out_limit = sinon.fake.returns false
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
        assert.equal 1, o._turns_out_limit.callCount

      it 'out', ->
        o._turns_out_limit = -> true
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
        hand: [{i: 1, card: 'Qc'}, {i: 2, card: 'Kc'}]
        fold: [{i: 3, card: '2c'}]
        out: true
        timebank: 12
        fantasyland: true
        playing: true

      o._get_ask = sinon.fake.returns [{a: 'll', s: 'o'}, {5: {s: 'z', e: 'd'}}]

    it 'default', ->
      assert.deepEqual {
        id: 1
        position: 0
        chips: 5
        hand: [{i: 1}, {i: 2}]
        fold: [{i: 3}]
        out: true
        timebank: 12
        fantasyland: true
        playing: true
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
      assert.deepEqual [{i: 3}], json.fold

    it 'no fantasyland', ->
      json = o.toJSON(2, [])
      assert.deepEqual o.options.hand, json.hand
      assert.deepEqual [{i: 3}], json.fold

    it 'no fantasyland (null)', ->
      json = o.toJSON(2)
      assert.deepEqual o.options.hand, json.hand
