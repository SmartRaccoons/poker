_pick = require('lodash').pick
_omit = require('lodash').omit
_cloneDeep = require('lodash').cloneDeep

Default = require('../poker/default').Default
Cards = require('./cards').CardsId
Rank = require('./rank').PokerOFCRank


module.exports.PokerPineappleOFC = class PokerPineappleOFC extends Default
  Player: require('./player').PokerPineappleOFCPlayer

  options_default:
    bet: 0
    rake: null # {cap: 1, percent: 3.5}
    timeout: 10
    timeout_first: 20
    timeout_fantasyland: 60
    delay_round: 2000
    delay_round_prepare: 10
    delay_player_turn: 200
    delay_player_ask: 200
    timebank_rounds: [] # [ [0, 10], [3, 5] ]
    autostart: true
    turns_out_max: 0 #0 - unlimited
    turns_out_limit: 3
    fantasyland_only: false

    dealer: 0
    running: false
    showdown: false
    fantasyland: false

  constructor: (options = {})->
    super _omit(options, ['players', 'users'])
    @_players = [0...3].map -> null
    @_players_id = {}
    @_cards = new Cards()
    (options.players or options.users or []).forEach @player_add.bind(@)

  _player_position_next: (position)->
    max = @_players.length
    for i in [0...max]
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
    player = new (@Player)(Object.assign( _pick(@options, ['timeout', 'timeout_first', 'timeout_fantasyland', 'delay_player_turn', 'turns_out_limit', 'fantasyland_only']), {position}, data))
    @_players[position] = player
    @_players_id[data.id] = position
    ['out', 'timebank'].forEach (ev)=>
      player.on ev, (params)=>
        @emit "#{ev}", Object.assign({position}, params)
    player.on 'ask', =>
      @emit.apply @, ['ask'].concat( player._get_ask(@_players_not_fantasyland()) )
    player.on 'turn_temp', (turn)=>
      if player.options.fantasyland
        return
      @emit 'turn_temp', turn
    player.on 'turn', (turn)=>
      players = @players({playing: true, fantasyland: false}).map (p)-> _pick p.options, ['hand', 'position']
      @emit.apply @, ['turn'].concat( player._get_turn(turn, @_players_not_fantasyland(), players) )
      if player.options.fantasyland then @_progress_check() else @_progress(player.options.position)
    @emit 'player:add', @_player_toJSON(player), {[player.options.id]: @_player_toJSON(player, player.options.id)}
    if !@options.running and @options.autostart and !@_round_prepare_timeout and @players().length >= 2
      @start()
    else if @_round_prepare_timeout
      @_round_prepare_emit()
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
    # if array empty - no users in the fantasyland with not finished hand
    players = @players({playing: true})
    not_fantasyland = players
    .filter (p)->
      return !p.options.fantasyland or p.options.hand_full
    .map (p)-> p.options.id
    if not_fantasyland.length is players.length
      return []
    return not_fantasyland

  start: (params)->
    if params
      if 'players' of params
        params.players.forEach ({id, timebank})=>
          @_players[@_players_id[id]].options_update {timebank}
      if 'bet' of params
        @options_update {bet: params.bet}
    if @options.delay_round_prepare
      return @_round_prepare()
    @_round()

  _round_prepare: ->
    if !@options.delay_round_prepare
      return @_round()
    @_round_prepare_start = new Date()
    @_round_prepare_timeout = setTimeout =>
      @_round_prepare_timeout = null
      @_round()
    , @options.delay_round_prepare * 1000 + 500
    @_round_prepare_emit()

  _round_prepare_emit: ->
    delay = Math.floor( @options.delay_round_prepare - (new Date().getTime() - @_round_prepare_start.getTime() ) / 1000 )
    @emit 'round_prepare', Object.assign(
      {delay: ( if delay <= 0 then 0 else delay ) }
      if !@options.fantasyland_only then {fantasyland: @options.fantasyland}
    )

  _round_prepare_cancel: ->
    clearTimeout @_round_prepare_timeout
    @_round_prepare_timeout = null
    @emit 'round_cancel'

  _round: ->
    @_cards.shuffle()
    dealer = @options.dealer
    if !@options.fantasyland
      dealer = @_player_position_next(dealer)
      @options_update {dealer, running: true}
    @players( if @options.fantasyland then {playing: true} ).forEach (p)=>
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
      dealer
      players: @players({playing: true}).map (p)-> _pick p.options, ['timebank', 'position', 'rounds']
    }
    @players({playing: true}).forEach (p)=>
      cards_require = p.cards_require(true)
      if cards_require > 0
        p.ask { cards: @_cards.deal(cards_require) }
    @_progress(dealer)

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
    setTimeout =>
      @_players[position].ask { cards: @_cards.deal( @_players[position].cards_require() )}
    , @options.delay_player_ask

  turn: ({user_id, turn})->
    if !@_players[@_players_id[user_id]].options.waiting
      return
    @_players[@_players_id[user_id]].turn(turn)

  turn_temp: ({user_id, turn})->
    if !@_players[@_players_id[user_id]].options.waiting
      return
    @_players[@_players_id[user_id]].turn_temp turn

  _calculate_pot: (players)->
    chips_factor = players.length - 1
    points_total = players.reduce (acc, p)->
      acc + (if p.points_change > 0 then p.points_change else 0)
    , 0
    change = players.map -> 0
    change_chips = (i, chips_change)->
      chips_change_value = do ->
        for [mod, factor] in [[-1, 1], [1, chips_factor]]
          if mod * chips_change > 0
            if mod * (change[i] + chips_change) > factor * players[i].chips
              return mod * factor * players[i].chips - change[i]
        return chips_change
      change[i] += chips_change_value
      return chips_change_value
    players.forEach (p, i)=>
      change_chips(i, p.points_change * @options.bet)
    chips_total = do =>
      Math.min.apply null, players.reduce( (acc, p, i)->
        if p.points_change < 0
          acc[0] += -change[i]
        else
          acc[1] += change[i]
        acc
      , [0, 0] )
    rake = 0
    if @options.rake
      rake = Math.floor(chips_total * @options.rake.percent/100)
      if rake > @options.rake.cap
        rake = @options.rake.cap
    do =>
      change = players.map -> 0
      for [mod, factor] in [[-1, 1], [1, chips_factor]]
        chips_left = if mod > 0 then chips_total - rake else chips_total
        while chips_left > 0
          chips_changed = 0
          players.forEach ({chips, points_change}, i)->
            if mod * points_change > 0 and mod * change[i] < chips * factor
              chips_new = Math.ceil( (mod * points_change / points_total) * chips_left )
              if chips_new + chips_changed > chips_left
                chips_new = chips_left - chips_changed
              chips_new_actual = change_chips i, mod * chips_new
              chips_changed += mod * chips_new_actual
          chips_left -= chips_changed
    players.forEach (p, i)-> p.chips_change = change[i]
    Object.assign( {players}, if rake then {rake} )

  _round_end: ->
    {rake, players} = @_calculate_pot Rank::compare @players({playing: true}).map (p)-> _pick p.options, ['chips', 'rank', 'position']
    players_remove = players.filter (p)=> (p.chips + p.chips_change) <= 0
    players.forEach (p)=>
      @_players[p.position].round_end _pick(p, ['chips_change', 'points_change']), players.length - players_remove.length >= 2
    fantasyland = !@options.fantasyland_only and !!( players.find (p)=> @_players[p.position].options.fantasyland )
    if !fantasyland
      players_remove = players.filter (p)=>
        (p.chips + p.chips_change) is 0 or ( @options.turns_out_max and @options.turns_out_max <= @_players[p.position].options.turns_out )
    players_remove = players_remove.map (p)=> @_players[p.position]
    @options_update {showdown: true}
    _pick_options = ['hand', 'chips', 'timebank'].concat if !@options.fantasyland_only then ['fantasyland'] else []
    @emit 'round_end', Object.assign(
      {
        players: players.map (p)=>
          Object.assign {}, p, _pick(@_players[p.position].options, _pick_options)
      }
      if fantasyland then {fantasyland}
      if rake then {rake}
    )

    setTimeout =>
      @options_update Object.assign( {fantasyland, showdown: false}, if !fantasyland then { running: false } )
      players_remove.forEach (p)=> @_player_remove(p)
      @emit 'round_end_timeout', Object.assign(
        {players_remove: players_remove.map (p)-> p.options.id}
        if fantasyland then {fantasyland}
      )
      if @_round_last
        @players().forEach (p)=>
          @_player_remove p
        return
      if @options.autostart and @players().length >= 2
        @_round_prepare()
    , @options.delay_round

  out: ({user_id, out})->
    @_players[@_players_id[user_id]].out({out})

  last: ({user_id})->
    if @options.running and @_players[@_players_id[user_id]].options.playing
      return
    player = @_players[@_players_id[user_id]]
    @_player_remove player

  round_last: ->
    @_round_last = true

  _player_toJSON: (player, user_id)->
    player.toJSON user_id, @_players_not_fantasyland(), @options.running and !@options.showdown

  toJSON: (user_id = null)->
    Object.assign(
      _pick @options, ['bet', 'dealer', 'running'].concat( if !@options.fantasyland_only then ['fantasyland'] else [] )
      {
        players: @_players.map (p)=>
          p and @_player_toJSON(p, user_id)
      }
    )
