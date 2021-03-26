_pick = require('lodash').pick
_omit = require('lodash').omit
_cloneDeep = require('lodash').cloneDeep

Default = require('../poker/default').Default
Cards = require('../poker/cards').Cards
Rank = require('./rank').PokerOFCRank


module.exports.PokerPineappleOFC = class PokerPineappleOFC extends Default
  Player: require('./player').PokerPineappleOFCPlayer

  options_default:
    bet: 0
    rake: null # {cap: 1, percent: 3.5}
    timeout: 10
    timeout_first: 20
    timeout_fantasyland: 60
    # timeout_card: null
    # timeout_card_first: null
    # timeout_card_fantasyland: null
    # timeout_bid: null
    # timeout_card_first: null
    # timeout_bid_first: null
    delay_round: 2000
    delay_round_prepare: 10
    delay_player_turn: 200
    timebank_rounds: [] # [ [0, 10], [3, 5] ]
    autostart: true
    rounds_out_max: 0 #0 - unlimited

    dealer: 0
    running: false

  constructor: (options = {})->
    super _omit(options, ['players', 'users'])
    @_players = [0...3].map -> null
    @_players_id = {}
    @_cards = new Cards()
    (options.players or options.users or []).forEach @player_add.bind(@)

  _player_position_next: (position)->
    max = @_players.length
    for i in [0...@_players.length]
      position = if position + 1 is max then 0 else position + 1
      if @_players[position]
        return position

  _player_position_next_action: (position)->
    for i in [0...@_players.length]
      position = @_player_position_next(position)
      if @_players[position].action_require()
        return position
    return null

  _player_position_free: ->
    positions = @_players
    .map (p, i)-> if p is null then i else null
    .filter (p)-> p isnt null
    if positions.length is 0
      return -1
    positions[Math.floor(Math.random() * positions.length)]

  player_add: (data)->
    position = @_player_position_free()
    if position is -1
      return false
    player = new (@Player)(Object.assign( _pick(@options, ['timeout', 'timeout_first', 'timeout_fantasyland', 'delay_player_turn']), {position}, data))
    @_players[position] = player
    @_players_id[data.id] = position
    ['out', 'timebank'].forEach (ev)=>
      player.on ev, (params)=>
        @emit "#{ev}", Object.assign({position}, params)
    player.on 'ask', => @emit.apply(@, ['ask'].concat( player._get_ask(@_players_not_fantasyland()) ) )
    player.on 'turn', ({turn})=>
      not_fantasyland = @_players_not_fantasyland()
      turn_fold = _cloneDeep(turn)
      turn_fold.fold = turn_fold.fold.map -> null
      turn_closed = _cloneDeep(turn_fold)
      turn_closed.cards = turn_closed.cards.map (line)-> line.map -> null
      players = @players({playing: true, fantasyland: false}).map (p)-> _pick p.options, ['hand', 'position']
      @emit 'turn', Object.assign(
        {position}
        { turn: if not_fantasyland.length > 0 or player.options.fantasyland then turn_closed else turn_fold }
        if player.options.fantasyland and not_fantasyland.length is 0 then { players }
      ), Object.assign(
        {}
        if not_fantasyland.length > 0 and !player.options.fantasyland then not_fantasyland.reduce( (acc, user_id)->
          Object.assign acc, {[user_id]: {turn: turn_fold}}
        )
        { [player.options.id]: Object.assign(
          { turn }
          if player.options.fantasyland and not_fantasyland.length > 0 then {players}
        )}
      )
      if player.options.fantasyland then @_progress_check() else @_progress()
    @emit 'player:add', player.toJSON(), {[player.options.id]: player.toJSON(player.options.id)}
    if !@options.running and @options.autostart and !@_round_prepare_timeout and @players().length >= 2
      @start()
    return true

  _player_remove: (player)->
    @_players[player.options.position] = null
    delete @_players_id[player.options.id]
    @emit 'player:remove', _pick(player.options, ['id', 'chips', 'rounds'])
    if @players().length < 2
      @_round_prepare_cancel()

  players: (filter)->
    @_players.filter (p)-> if filter then p and p.filter(filter) else p

  _players_not_fantasyland: ->
    players = @players({playing: true})
    not_fantasyland = players
    .filter (p)-> !( p.options.fantasyland and !p.options.hand_full )
    .map (p)-> p.options.id
    if not_fantasyland.length is players.length
      return []
    return not_fantasyland

  start: ->
    if @options.delay_round_prepare
      return @_round_prepare()
    @_round()

  _round_prepare: ->
    if !@options.delay_round_prepare
      return @_round()
    @emit 'round_prepare', {delay: @options.delay_round_prepare}
    @_round_prepare_timeout = setTimeout =>
      @_round_prepare_timeout = null
      @_round()
    , @options.delay_round_prepare * 1000

  _round_prepare_cancel: ->
    clearTimeout @_round_prepare_timeout
    @_round_prepare_timeout = null

  _round: ->
    @_cards.shuffle()
    @options_update
      dealer: @_player_position_next(@options.dealer)
      playing: true
    @players().forEach (p)=>
      p.round Object.assign(
        {}
        do =>
          rounds = p.options.rounds
          match = @options.timebank_rounds
          .slice()
          .reverse()
          .find (v)->
            if rounds is 0 then v[0] is 0 else rounds % v[0] is 0
          if match then {timebank: match[1]} else null
      )
    @emit 'round', {
      dealer: @options.dealer
      players: @players({playing: true}).map (p)-> _pick p.options, ['timebank', 'position']
    }
    @players({playing: true}).forEach (p)=>
      cards_require = p.cards_require(true)
      if cards_require > 0
        p.ask { cards: @_cards.deal(cards_require) }
    @_progress(@options.dealer)

  _progress_check: ->
    if @players({playing: true}).length is @players({playing: true, hand_full: true}).length
      @_round_end()
      return false
    fantasyland_out = @players({playing: true, hand_full: false, fantasyland: true, out: true})
    if @players({playing: true, hand_full: false}).length is fantasyland_out.length
      fantasyland_out.forEach (p)-> p.action_fantasyland()
    return true

  _progress: (position)->
    if !@_progress_check()
      return
    position = @_player_position_next_action(position)
    if position is null
      return
    @_players[position].ask { cards: @_cards.deal( @_players[position].cards_require() )}

  turn: ({user_id, turn})->
    if !@_players[@_players_id[user_id]].options.waiting
      return
    @_players[@_players_id[user_id]].turn(turn)

  _calculate_pot: (players)->
    bet = @options.bet
    pot_total = 0
    points_total = 0
    players.forEach (p)->
      if p.points_change > 0
        points_total += p.points_change
        return
      p.chips_change = p.points_change * bet
      if p.chips < -p.chips_change
        p.chips_change = -p.chips
      pot_total += -p.chips_change
    rake = 0
    if @options.rake
      rake = Math.floor(pot_total * @options.rake.percent/100)
      if rake > @options.rake.cap
        rake = @options.rake.cap
    pot = pot_total - rake
    pot_new = 0
    pot_winner_max_position = 0
    pot_winner_max_chips = 0
    players.forEach (p, position)->
      if p.points_change > 0
        p.chips_change = Math.floor( pot * p.points_change / points_total )
        pot_new += p.chips_change
        if pot_winner_max_chips < p.chips_change
          pot_winner_max_chips = p.chips_change
          pot_winner_max_position = position
    players[pot_winner_max_position].chips_change += pot - pot_new
    return Object.assign( {players}, if rake then {rake} )

  _round_end: ->
    {rake, players} = @_calculate_pot Rank::compare @players({playing: true}).map (p)-> _pick p.options, ['chips', 'rank', 'position']
    players_remove = players
    .filter (p)=>
      (p.chips + p.chips_change) is 0 or ( @options.rounds_out_max and @options.rounds_out_max <= @_players[p.position].options.rounds_out )
    .map (p)=>
      @_players[p.position]
    players.forEach (p)=>
      @_players[p.position].round_end _pick(p, ['chips_change', 'points_change']), players.length - players_remove.length >= 2

    @emit 'round_end', Object.assign(
      {
        players: players.map (p)=>
          Object.assign {}, p, _pick(@_players[p.position].options, ['fantasyland', 'hand', 'chips'])
      }
      if rake then {rake}
    )
    setTimeout =>
      players_remove.forEach (p)=> @_player_remove(p)
      @options_update {running: false}
      if @_round_last
        @players().forEach (p)=>
          @_player_remove p
        return
      if @players().length >= 2
        @_round_prepare()
    , @options.delay_round

  out: ({user_id, out})->
    @_players[@_players_id[user_id]].out({out})

  last: ({user_id})->
    if @options.running
      return
    player = @_players[@_players_id[user_id]]
    @_player_remove player

  round_last: ->
    @_round_last = true

  toJSON: (user_id = null)->
    # json = Object.assign _pick(@options, [ 'bet', 'dealer', 'running', 'type' ]), {
    #   players: @_players.map (p)-> p and p.toJSON(user_id)
    #   board: @_board.toJSON()
    # }, do =>
    #   ask = @_get_ask()
    #   if !ask
    #     return null
    #   {ask: Object.assign {}, ask[0], ask[1][user_id]}