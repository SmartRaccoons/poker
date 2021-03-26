_cloneDeep = require('lodash').cloneDeep
_pick = require('lodash').pick

Default = require('../poker/default').Default
Rank = require('./rank').PokerOFCRank

module.exports.PokerPineappleOFCPlayer = class PokerPineappleOFCPlayer extends Default
  options_default:
    id: null
    position: null
    chips: 0
    chips_start: 0
    chips_change: 0
    points_change: 0
    hand: [[], [], []]
    hand_full: false
    hand_length: 0
    fold: []
    out: false
    rounds: 0
    rounds_out: 0
    fantasyland: false
    cards: []
    timebank: 0
    timeout: 0
    timeout_first: 0
    timeout_fantasyland: 0
    delay_player_turn: 0

    playing: false
    waiting: false

  options_bind:
    'hand': ->
      @options_update
        rank: Rank::calculate(@options.hand, @options.fantasyland)
    out: ->
      @emit 'out', {out: @options.out}
      if !@options.out and @options.rounds_out > 0
        @options_update {rounds_out: 0}

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
      if @options.out then {rounds_out: @options.rounds_out + 1}
      if timebank then {timebank: @options.timebank + timebank}
    )

  _turn_cards_validate: (turn_cards)->
    if !turn_cards or !Array.isArray(turn_cards) or \
       turn_cards.length isnt 3 or turn_cards.find( (line)-> !Array.isArray(line) )
      return null
    fold = _cloneDeep @options.cards
    fold_length = if fold.length is 5 then 0 else 1
    hand = _cloneDeep @options.hand
    for line_cards, line in turn_cards
      for card in line_cards
        if !(card in fold)
          return null
        fold.splice(fold.indexOf(card), 1)
        hand[line].push card
      if hand[line].length > (if line is 0 then 3 else 5)
        return null
    if fold.length isnt fold_length
      return null
    return {fold, hand}

  _turn_cards_default: ->
    fold = _cloneDeep @options.cards
    fold_length = if fold.length is 5 then 0 else 1
    cards = [[], [], []]
    for line in [2, 1, 0]
      slots = 5 - @options.hand[line].length
      for slot in [0...slots]
        cards[line].push fold.shift()
        if fold_length is fold.length
          return cards

  _turn_cards: ({cards})->
    params = @_turn_cards_validate cards
    if !params
      @options_update {out: true}
      cards = @_turn_cards_default()
      params = @_turn_cards_validate cards
    hand_length = @options.hand_length + cards.length
    @options_update Object.assign(
      {hand: params.hand, hand_length, cards: []}
      if hand_length is 13 then {hand_full: true}
      if params.fold.length > 0 then {fold: @options.fold.concat(params.fold)}
    )
    return {cards, fold: params.fold}

  turn: ({cards})->
    if @options.waiting
      @_activity_clear()
      @options_update {waiting: false}
    turn = @_turn_cards {cards}
    exe = => @emit 'turn', {turn}
    delay = @options.delay_player_turn + @_ask_date.getTime() - new Date().getTime()
    if delay <= 0
      return exe()
    setTimeout exe, delay

  ask: ({cards})->
    @_ask_date = new Date()
    waiting = !( @options.out and !@options.fantasyland )
    @options_update Object.assign( {cards}, if waiting then {waiting} )
    if !waiting
      return @turn {}
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
              return @options.cards.map -> null
            return @options.cards
            if @options.cards.length is 5 and not_fantasyland.length is 0
              return @options.cards
            @options.cards.map -> null
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
    if @options.waiting and @options.rounds_out > 0
      @turn {}

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
        return @turn({})
      @emit 'timebank', {timeout: @options.timebank}
      @_activity_timebank = true
      @_activity @options.timebank
    , @_activity_timeout + 400

  _activity_timeout_left: ->
    seconds = Math.round ( @_activity_timeout - (new Date().getTime() - @_activity_timeout_start) ) / 1000
    if seconds > 0 then seconds else 0

  toJSON: (user_id, not_fantasyland)->
    hero = user_id is @options.id
    Object.assign(
      _pick @options, ['id', 'position', 'chips', 'chips_change', 'out', 'timebank', 'fantasyland', 'hand', 'fold']
      if hero then {hero}
      if !hero then { fold: @options.fold.map ()-> null }
      if !hero and not_fantasyland and not_fantasyland.length > 0 and !( user_id in not_fantasyland ) then { hand: @options.hand.map (line)-> line.map -> null }
    )
