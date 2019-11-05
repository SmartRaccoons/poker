events = require('events')
Rank = require('./rank').PokerRank
cloneDeep = require('lodash').cloneDeep



module.exports.Poker = class Poker extends events.EventEmitter
  Player: require('./poker.player').PokerPlayer
  Board: require('./poker.board').PokerBoard
  Cards: require('./cards').Cards

  _options_default:
    players: [2, 9]
    timeout: 10
    delay_progress: 1000
    delay_round: 3000
    blinds: [1, 2]
    autostart: false
    rounds_out_max: 0 #0 - unlimited
    rake: false
      # percent: 3.5
      # progress: 1
      # cap: 30 # [[2, 20], [3, 40], []]; []
    # cap: [2, 2, 3, 3]

  constructor: (options = {})-> #{blinds, buy_in}
    super()
    @options = Object.assign cloneDeep(@_options_default), options
    @_players = [0...@options.players[1]].map -> null
    @_players_ids = {}
    @_dealer = -1
    @_blinds = @options.blinds.slice(0)
    @_chips_start = options.chips
    @_cards = new (@Cards)()
    @_board = new (@Board)()
    @_board.on 'pot:return', ({pot, position})=>
      @_players[position].bet_return({bet: pot})
    @_board.on 'pot:update', (pot)=> @emit 'pot', pot
    @_board.on 'change:cards', =>
      @players().forEach (p)=>
        p.options_update {cards_board: @_board.options.cards}, true
    @on 'progress', (params)=>
      @_board.progress(params)
      @players().forEach (p)-> p.progress()
    if options.users
      options.users.forEach (user)=> @player_add(user)
    @_round_count = 0

  _activity_clear: ->
    clearTimeout @_timeout_activity_callback
    @_timeout_activity_callback = null

  _activity: (timeout = @options.timeout * 1000)->
    @_timeout_activity_timeout = timeout
    @_timeout_activity_timeout_start = new Date().getTime()
    @_timeout_activity_callback = setTimeout =>
      @turn()
    , timeout + 1000

  _activity_timeout_left: ->
    seconds = Math.round ( @_timeout_activity_timeout - (new Date().getTime() - @_timeout_activity_timeout_start) ) / 1000
    if seconds <= 1 then 1 else seconds

  _player_position_next: (position, max = @_players.length)->
    for i in [0...@_players.length]
      position = if position + 1 is max then 0 else position + 1
      if @_players[position]
        return position

  _player_position_free: ->
    positions = @_players
    .map (p, i)-> if p is null then i else null
    .filter (p)-> p isnt null
    if positions.length is 0
      return -1
    positions[Math.floor(Math.random() * positions.length)]

  is_full: -> @_players.filter( (p)-> p is null ).length is 0

  player_add: (data)->
    position = @_player_position_free()
    if position is -1
      return false
    player = new (@Player)(Object.assign({position, chips: @_chips_start, command: 'fold'}, data))
    player.on 'bet', ({bet})=> @_board.bet({position, bet, command: player.options.command})
    ['turn', 'win', 'out', 'last', 'bet_return', 'readd'].forEach (ev)=>
      player.on ev, (params)=> @emit "#{ev}", Object.assign({position}, params)
    player.on 'remove_safe', => @emit 'player:remove_safe', @_player_remove_options(player)
    player.on 'rounds_out', ({rounds_out})=>
      if @options.rounds_out_max and rounds_out > @options.rounds_out_max
        @last {user_id: player.options.id, last: true}
    @_players[position] = player
    @_players_ids[data.id] = position
    @emit 'player:add', player.toJSON(), {[player.options.id]: player.toJSON(player.options.id)}
    if !@_started and @options.autostart and @players().length is @options.players[0]
      @start()
    return true

  _player_remove_options: (player)->
    return ['id', 'rounds', 'position', 'chips_last', 'chips_start'].reduce( (acc, v)->
      Object.assign acc, {[v]: player.options[v]}
    , {chips: player.budget()} )

  _player_remove: (p)->
    player = @_players[p.options.position]
    @emit 'player:remove', @_player_remove_options(player)
    @_players[p.options.position] = null
    delete @_players_ids[p.options.id]

  player_remove: (id)-> @_player_remove(@player_get(id))

  player_get: (id)-> @players({id})[0]

  players: (filter)->
    @_players.filter (p)-> if filter then p and p.filter(filter) else p

  _emit_start_params: -> []

  start: ->
    @_started = true
    @emit.apply @, ['start'].concat(@_emit_start_params())
    @round()

  _rake_calc: (players_count)->
    if !@options.rake
      return false
    if Array.isArray(@options.rake.cap)
      for cap in @options.rake.cap.slice(0).reverse()
        if cap[0] <= players_count
          return Object.assign {}, @options.rake, {cap: cap[1]}
    return @options.rake

  round: ->
    @_round_count++
    if @_blinds_next
      @_blinds = @_blinds_next.slice(0)
      @_blinds_next = null
    @_cards.shuffle()
    @_showdown_call = false
    @_progress_round = 0
    players = @players()
    players.forEach (p)=> p.round(@_round_player_addon(p))
    @_dealer = @_player_position_next(@_dealer)
    @_blinds_position = [@_dealer]
    if players.length > 2
      @_blinds_position[0] = @_player_position_next(@_dealer)
    @_waiting = @_blinds_position[1] = @_player_position_next(@_blinds_position[0])
    @_board.round({blinds: @_blinds.slice(0), show_first: @_player_position_next(@_dealer)})
    [0, 1].forEach (id)=> @_players[@_blinds_position[id]].bet({bet: @_blinds[id], command: 'blind'})
    @_rake = @_rake_calc(players.length)
    @emit.apply @, ['round'].concat(@_emit_round_params())
    @_progress()

  _round_player_addon: -> { cards: @_cards.deal(2) }

  _emit_round_params: ->
    players = @_players.map (p)->
      if !p
        return null
      {cards: ['', '']}
    [
      Object.assign({
        dealer: @_dealer
        blinds: @_blinds_position.map (position)=> {position, bet: @_players[position].options.bet, command: @_players[position].options.command}
        players
      }, if @_rake then {rake: @_rake})
      @players().reduce( (acc, p)->
        players_clone = cloneDeep(players)
        players_clone[p.options.position].cards = p.options.cards
        Object.assign acc, {[p.options.id]: {players: players_clone}}
      , {})
    ]

  blinds: (@_blinds_next)->

  _showdown: ->
    @emit 'showdown', @players({fold: false}).map (p)->
      {position: p.options.position, cards: p.showdown()}

  _round_end: ->
    players = @players({fold: false})
      .map (p)-> {rank: p.rank().rank, position: p.options.position}
    if players.length > 1
      players_ranked = Rank::compare(players.map (p)-> p.rank)
      .map (winners)-> winners.map (i)-> players[i].position
    else
      players_ranked = [ [players[0].position] ]
    pots = @_board.pot_devide(players_ranked, if @_rake and @_rake.progress <= @_progress_round then @_rake else false)
    pots.forEach (pot)=>
      pot.winners.forEach ({position, win})=>
        @_players[position].win({win}, true)
    players_remove = => @players().filter (p)-> p.budget() is 0 or p.options.last
    @emit 'round_end', {
      pots: pots.map (p)=>
        Object.assign(p, {
          showdown: p.showdown.map (position)=>
            { 'cards': @_players[position].showdown(), position }
        })
      players_remove: players_remove().map (p)-> {id: p.options.id, position: p.options.position, chips_last: p.options.chips_last, chips: p.budget()}
    }
    setTimeout =>
      players_remove().forEach (p)=> @_player_remove(p)
      if @players().length >= @options.players[0]
        @round()
        return
      @_started = false
      @emit 'end'
    , @options.delay_round

  _progress_pot: ->
    players = @players().map (player)-> { bet: player.bet_pot(), fold: player.fold(), position: player.options.position}
    if players.filter( (p)-> p.bet > 0 ).length is 0
      return
    @_board.pot players

  _progress_action: ->
    if @_showdown_call or @players({fold: false}).length < 2
      return false
    last = @_waiting
    while true
      last = @_player_position_next(last)
      if @_waiting is last
        break
      if @_players[last].action_require(@_board.bet_max())
        @_emit_ask(last)
        return true
    return false

  _progress: (callback = @_progress)->
    # ['deal', 'flop', 'turn', 'river', 'showdown']
    if @_progress_action()
      return
    if @options.delay_progress and @_progress_last and (=>
      delay = @_progress_last.getTime() + @options.delay_progress - new Date().getTime()
      if delay <= 0
        return false
      setTimeout (=> @_progress(callback) ), delay
      return true
    )()
      return
    @_progress_last = new Date()
    @_progress_pot()
    if @players({fold: false}).length < 2
      return @_round_end()
    if !@_showdown_call and @players({fold: false, all_in: false}).length < 2
      @_showdown()
      @_showdown_call = true
      return @_progress(callback)
    @_progress_round++
    if @_progress_round is 4
      return @_round_end()
    @emit 'progress', {
      cards: @_cards.deal(if 1 is @_progress_round then 3 else 1)
    }
    @_waiting = @_dealer
    callback.bind(this)(callback)

  _get_ask: ->
    if !@_timeout_activity_callback
      return null
    [{
      position: @_waiting
      timeout: @_activity_timeout_left()
    }, { [@_players[@_waiting].options.id]: @_waiting_commands() }]

  _emit_ask: (player)->
    @_waiting = player
    commands = @_waiting_commands().commands
    if commands.length is 1
      return @turn(commands[0])
    if @_players[@_waiting].options.out
      return @turn()
    @_activity()
    @emit.apply(@, ['ask'].concat(@_get_ask()))

  _waiting_commands: ->
    {
      commands: @_players[@_waiting].commands({
        bet_max: @_board.bet_max()
        bet_raise: @_board.bet_raise()
        bet_raise_count: @_board.bet_raise_count()
        stacks: @players({fold: false, all_in: false}).length
        blind: @_blinds[1]
        pot: @_board.pot_total()
        bet_total: @_players.reduce (acc, v)->
          acc + if v then v.options.bet else 0
        , 0
        progress: @_progress_round
        cap: if @options.cap then @options.cap[@_progress_round] * @_blinds[1] else null
      })
    }

  turn: (command)->
    commands = @_waiting_commands().commands
    if command
      params = do =>
        more = commands.filter (c)-> c[0] is command[0]
        if more.length > 1
          more2 = more.find (c)-> c[1] is command[1]
          if more2
            return more2
        return more[0]
    if !params
      command = params = commands[0]
      if @_progress_round is 0 and command[0] is 'check' and @_players[@_waiting].options.out
        command = ['fold']
      @_players[@_waiting].out({out: true})
    @_players[@_waiting].turn(params, command)
    @_activity_clear()
    @_progress()

  out: ({user_id, out})->
    @_players[@_players_ids[user_id]].out({out})
    if @_started and out and @waiting() is user_id
      @turn()

  last: ({user_id, last})->
    if @_round_last
      return
    if !@_started
      return @_player_remove(@_players[@_players_ids[user_id]])
    @_players[@_players_ids[user_id]].last({last})

  round_last: ->
    Object.keys(@_players_ids).forEach (user_id)=> @last({user_id, last: true})
    @_round_last = true

  waiting: ->
    if !@_timeout_activity_callback
      return null
    @_players[@_waiting].options.id

  toJSON: (user_id = null)->
    json =
      players: @_players.map (p)-> p and p.toJSON(user_id)
      board: @_board.toJSON()
      dealer: @_dealer
      progress: @_progress_round
      blinds: @_blinds
    ask = @_get_ask()
    if ask
      json.ask = Object.assign {}, ask[0], ask[1][user_id]
    json
