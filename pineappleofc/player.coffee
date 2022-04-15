_cloneDeep = require('lodash').cloneDeep
_pick = require('lodash').pick
_omit = require('lodash').omit

Default = require('../poker/default').Default
Rank = require('./rank').PokerOFCRank

_omit_cards = (card)-> _omit(card, ['card'])

module.exports.PokerPineappleOFCPlayer = class PokerPineappleOFCPlayer extends Default
  options_default:
    id: null
    position: null
    chips: 0
    chips_start: 0
    chips_change: 0
    points_change: 0
    hand: []
    hand_full: false
    hand_length: 0
    fold: []
    out: false
    rounds: 0
    turns_out: 0
    fantasyland: false
    cards: []
    timebank: 0
    timeout: 0
    timeout_first: 0
    timeout_fantasyland: 0
    delay_player_turn: 0
    turns_out_limit: 3

    playing: false
    waiting: false

  options_bind:
    'hand': ->
      @options_update
        rank: @_rank_calculate(@options.hand)
    turns_out: ->
      if @_turns_out_limit()
        @options_update {out: true}
    out: ->
      @emit 'out', {out: @options.out}
      if !@options.out
        @options_update {turns_out: 0}

  options_round_reset: ['chips_change', 'points_change', 'hand', 'hand_full', 'hand_length', 'fold', 'cards', 'waiting']

  filter: (params)->
    for k, v of params
      if @options[k] != v
        return false
    return true

  round: ({timebank})->
    @options_update Object.assign(
      _cloneDeep _pick(@options_default, @options_round_reset)
      {playing: true, rounds: @options.rounds + 1}
      if timebank then {timebank: @options.timebank + timebank}
    )

  _rank_calculate: (cards)->
    Rank::calculate(
      do =>
        [0..2].map (line)=>
          cards
            .filter ({l})-> l is line
            .map ({card})-> card
      , @options.fantasyland)

  _turn_automove_fantasyland: ->
    cards_clone = _cloneDeep(@options.cards)
    cards = []
    {hand, fold} = Rank::automove_fantasyland(@options.cards.map (c)-> c.card)
    hand.forEach (line, l)=>
      line.forEach (c, r)=>
        card_index = cards_clone.findIndex (card)-> card.card is c
        card = cards_clone.splice(card_index, 1)[0]
        cards.push {l, r, card: card.card, i: card.i}
    { cards, fold: cards_clone.map (card)-> {card: card.card, i: card.i} }

  _turn_cards_temp: (turn_cards)->
    cards_length = @options.cards.length
    place = cards_length - (if cards_length is 5 then 0 else 1)
    slots_completed = [0..2].map (line)=> @options.hand.filter( ({l})-> l is line ).length
    slots_free = slots_completed.map (placed, i)-> (if i is 0 then 3 else 5) - placed
    cards_clone = _cloneDeep @options.cards
    cards = []
    if !( turn_cards and Array.isArray(turn_cards) )
      turn_cards = _cloneDeep(@options.cards)
    for ___ in [0..50]
      if turn_cards.length is 0
        break
      turn_card = turn_cards.shift()
      if !turn_card.i?
        continue
      card_index = cards_clone.findIndex ({i})-> i is turn_card.i
      if card_index < 0
        continue
      card = Object.assign(
        {}
        cards_clone.splice(card_index, 1)[0]
        { l: if turn_card.l? and turn_card.l in [0, 1, 2] and slots_free[turn_card.l] > 0 and place > 0 then turn_card.l else 3 }
        if (turn_card.r? and turn_card.r in [0..13]) then {r: turn_card.r}
      )
      cards.push card
      if card.l < 3
        slots_free[card.l]--
        place--
    {
      slots_completed, slots_free, place,
      cards: cards.concat cards_clone.map (card)-> Object.assign {}, card, {l: 3}
    }

  _turn_cards_check: (turn_cards)->
    {slots_completed, slots_free, place, cards} = @_turn_cards_temp turn_cards
    for ___ in [0...place]
      card = cards.find (c)-> c.l is 3
      card.l = slots_free.findIndex (free)-> free > 0
      delete card.r
      slots_free[card.l]--
    cards
    .sort (c1, c2)->
      (if !c1.r? then 15 else c1.r) - (if !c2.r? then 15 else c2.r)
    .forEach (card)->
      if card.l < 3
        card.r = slots_completed[card.l]
        slots_completed[card.l]++
    {
      automove: place > 0
      cards: cards.filter (c)-> c.l < 3
      fold: cards.filter (c)-> c.l is 3
    }

  _turn_cards: ({cards})->
    {cards, fold, automove} = @_turn_cards_check cards
    if @options.cards.length > 5 and ( automove or !@_rank_calculate(cards).valid )
      {cards, fold} = @_turn_automove_fantasyland()
    hand_length = @options.hand_length + cards.length
    fold = fold.map (card)->
      _omit card, ['l', 'r']
    @options_update Object.assign(
      {hand: @options.hand.concat(cards), hand_length, cards: []}
      if hand_length is 13 then {hand_full: true}
      if fold.length > 0 then { fold: @options.fold.concat( fold ) }
    )
    return {cards, fold}

  turn_temp: (params)->
    {cards} = @_turn_cards_temp if params then params.cards
    @options_update {cards, turns_out: 0}
    @emit 'turn_temp', {
      position: @options.position
      turn:
        cards: cards.map (card)-> _pick(card, ['i', 'l', 'r'])
    }

  turn: (params)->
    if @options.waiting
      @_activity_clear()
      @options_update {waiting: false}
    @options_update
      turns_out: if !params then @options.turns_out + 1 else 0
    turn = @_turn_cards {cards: if params then params.cards}
    exe = => @emit 'turn', turn
    delay = @options.delay_player_turn + @_ask_date.getTime() - new Date().getTime()
    if delay <= 0
      return exe()
    setTimeout exe, delay

  _get_turn: (turn, not_fantasyland = [], players = [])->
    turn_fold = _cloneDeep(turn)
    turn_fold.fold.forEach (card)-> delete card.card
    turn_closed = _cloneDeep(turn_fold)
    turn_closed.cards.forEach (card)-> delete card.card
    [
      Object.assign(
        { position: @options.position }
        { turn: if not_fantasyland.length > 0 or @options.fantasyland then turn_closed else turn_fold}
        if not_fantasyland.length is 0 and @options.fantasyland then { players }
      )
      Object.assign(
        {}
        if !@options.fantasyland then not_fantasyland.reduce (acc, user_id)->
          Object.assign acc, {[user_id]: {turn: turn_fold}}
        , {}
        { [@options.id]: Object.assign(
            {}
            { turn }
            if @options.fantasyland and not_fantasyland.length > 0 then {players}
          )
        }
      )
    ]

  _turns_out_limit: -> @options.turns_out >= @options.turns_out_limit

  ask: ({cards})->
    @_ask_date = new Date()
    waiting = !@options.out or @options.fantasyland
    @options_update Object.assign(
      {cards: cards.map (card, r)-> Object.assign({}, card, {r, l: 3}) }
      if waiting then {waiting}
    )
    if !waiting
      return @turn()
    @_activity if @options.fantasyland then @options.timeout_fantasyland else\
      if @options.hand_length is 0 then @options.timeout_first else @options.timeout
    @emit 'ask'

  _get_ask: (not_fantasyland = [])->
    if !@options.waiting
      return null
    hide = !( @options.cards.length is 5 and not_fantasyland.length is 0 )
    [
      {
        turn:
          cards: do =>
            if hide
              return @options.cards.map _omit_cards
            return @options.cards
            if @options.cards.length is 5 and not_fantasyland.length is 0
              return @options.cards
            @options.cards.map _omit_cards
        timeout: @_activity_timeout_left()
        timebank: @options.timebank
        timebank_active: !!@_activity_timebank
        position: @options.position
      }
      Object.assign({},
        if not_fantasyland.length > 0 and @options.cards.length is 5 then not_fantasyland.reduce( (acc, user_id)=>
          Object.assign acc, { [user_id]: {turn: {cards: @options.cards}} }
        , {} )
        if hide then {[@options.id]: {turn: {cards: @options.cards}}}
      )
    ]

  cards_require: (before_start = false)->
    if before_start
      if @options.fantasyland
        return 14
      return 0
    if @options.hand_length > 0
      return 3
    return 5

  action_require: ->
    return @options.playing and !@options.fantasyland and !@options.hand_full

  action_fantasyland: ->
    if @options.waiting and @options.out
      @turn()

  round_end: ({chips_change, points_change}, players_enough)->
    @options_update {
      chips_change, points_change
      chips: @options.chips + chips_change
      fantasyland: do =>
        if !players_enough or @options.chips + chips_change <= 0
          return false
        return @options.rank.fantasyland
    }

  _activity_clear: ->
    if @_activity_timebank
      @options_update
        timebank: do =>
          timebank = @options.timebank - Math.floor (new Date().getTime() - @_activity_timeout_start) / 1000
          return if timebank > 0 then timebank else 0
    clearTimeout @_activity_callback
    @_activity_callback = null
    @_activity_timebank = null

  _activity: (timeout)->
    @_activity_timeout = timeout * 1000
    @_activity_timeout_start = new Date().getTime()
    @_activity_callback = setTimeout =>
      if @options.out or @_activity_timebank or !(@options.timebank > 0)
        return @turn()
      @emit 'timebank', {timeout: @options.timebank}
      @_activity_timebank = true
      @_activity @options.timebank
    , @_activity_timeout + 400

  _activity_timeout_left: ->
    seconds = Math.round ( @_activity_timeout - (new Date().getTime() - @_activity_timeout_start) ) / 1000
    if seconds > 0 then seconds else 0

  out: ({out})->
    @options_update {out: !!out}

  toJSON: (user_id, not_fantasyland)->
    hero = user_id is @options.id
    ask = @_get_ask(not_fantasyland)
    Object.assign(
      _pick @options, ['id', 'position', 'chips', 'out', 'timebank', 'fantasyland', 'playing', 'hand', 'fold']
      if hero then {hero}
      if !hero then {
        fold: @options.fold.map _omit_cards
      }
      if !hero and not_fantasyland and not_fantasyland.length > 0 and !( user_id in not_fantasyland ) then {
        hand: @options.hand.map _omit_cards
      }
      if ask then {
        ask: Object.assign(
          {}
          ask[0]
          if user_id then ask[1][user_id]
        )
      }
    )
