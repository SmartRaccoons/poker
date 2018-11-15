events = require('events')
Cards = require('./cards').Cards
Rank = require('./rank').PokerRank


module.exports.Poker = class Poker extends events.EventEmitter
  player: require('./poker.player').PokerPlayer
  board: require('./poker.board').PokerBoard

  _options_default:
    players: [2, 9]
    timeout: 10
    delay_progress: 1000
    delay_round: 3000
    blinds: [1, 2]
    autostart: false

  constructor: (options = {})-> #{blinds, buy_in}
    super()
    @options = Object.assign {}, @_options_default, options
    @_players = [0...@options.players[1]].map -> null
    @_players_ids = {}
    @_dealer = -1
    @_blinds = @options.blinds.slice(0)
    @_chips_start = options.chips
    @_cards = new Cards()
    @_board = new (@board)()
    @_board.on 'pot:return', ({pot, position})=>
      @_players[position].bet_return({bet: pot})
    @_board.on 'pot:update', (pot)=> @emit 'pot', pot
    @on 'progress', (params)=>
      @_board.progress(params)
      @players().forEach (p)-> p.progress(params)
    if options.users
      options.users.forEach (id)=> @player_add({ id })

  _activity_clear: ->
    clearTimeout @_timeout_activity_callback
    @_timeout_activity_callback = null

  _activity: ->
    @_timeout_activity_timeout_start = new Date().getTime()
    @_timeout_activity_callback = setTimeout =>
      @turn()
    , @options.timeout * 1000 + 1000

  _activity_timeout_left: ->
    seconds = Math.round ( @options.timeout * 1000 - (new Date().getTime() - @_timeout_activity_timeout_start) ) / 1000
    if seconds <= 1 then 1 else seconds

  _player_position_next: (position, max = @_players.length)->
    for i in [0...@_players.length]
      position = if position + 1 is max then 0 else position + 1
      if @_players[position]
        return position

  _player_free_position: ->
    @_players.indexOf(null)

  player_add: (data)->
    position = @_player_free_position()
    player = new (@player)(Object.assign({position, chips: @_chips_start}, data))
    player.on 'bet', ({bet, blind})=> @_board.bet({position, bet})
    ['turn', 'win', 'sit', 'bet_return'].forEach (ev)=>
      player.on ev, (params)=> @emit "#{ev}", Object.assign({position}, params)
    @_players[position] = player
    @_players_ids[data.id] = position
    @emit 'player:add', player.toJSON()
    if !@_started and @options.autostart and @players().length is @options.players[0]
      @start()

  _player_remove: (p)->
    player = @_players[p.position]
    @emit 'player:remove', {id: p.id, chips_last: player.chips_last, position: p.position}
    @_players[p.position] = null
    delete @_players_ids[p.id]

  player_remove: (id)-> @_player_remove(@player_get(id))

  player_get: (id)-> @players({id})[0]

  players: (filter)->
    @_players.filter (p)-> if filter then p and p.filter(filter) else p

  start: ->
    @_started = true
    @emit 'start'

  round: ->
    if @_blinds_next
      @_blinds = @_blinds_next
      @_blinds_next = null
    @_cards.shuffle()
    @_showdown_call = false
    @_progress_round = 0
    @players().forEach (p)=> p.round([@_cards.pop(), @_cards.pop()])
    @_dealer = @_player_position_next(@_dealer)
    @_blinds_position = [@_dealer]
    if @players().length > 2
      @_blinds_position[0] = @_player_position_next(@_dealer)
    @_waiting = @_blinds_position[1] = @_player_position_next(@_blinds_position[0])
    @_board.reset({blinds: @_blinds.slice(0), show_first: @_player_position_next(@_dealer)})
    [0, 1].forEach (id)=> @_players[@_blinds_position[id]].bet({bet: @_blinds[id], blind: true})
    @emit 'round', {
      dealer: @_dealer
      blinds: @_blinds_position.map (position)=> {position, bet: @_players[position]._bet}
    }, {
      cards: @players().reduce( (acc, p)->
        acc[p.id] = p.cards
        return acc
      , {})
    }
    @_progress()

  blinds: (@_blinds_next)->

  _showdown: ->
    @emit 'showdown', @players({fold: false}).map (p)->
      {position: p.position, cards: p.showdown()}

  _round_end: ->
    players = @players({fold: false})
      .map (p)-> {rank: p.rank().rank, position: p.position}
    if players.length > 1
      players_ranked = Rank::compare(players.map (p)-> p.rank)
      .map (winners)-> winners.map (i)-> players[i].position
    else
      players_ranked = [ [players[0].position] ]
    pots = @_board.pot_devide(players_ranked)
    pots.forEach (pot)=>
      pot.winners.forEach ({position, win})=>
        @_players[position].win({win}, true)
    players_remove = @players().filter (p)-> p.budget() is 0
    @emit 'round_end', {
      pots: pots.map (p)=>
        Object.assign(p, {
          showdown: p.showdown.map (position)=>
            { 'cards': @_players[position].showdown(), position }
        })
      players_remove: players_remove.map (p)-> {id: p.id, position: p.position, chips_last: p.chips_last}
    }
    setTimeout =>
      players_remove.forEach (p)=> @_player_remove(p)
      if @players().length >= 2
        @round()
        return
      @emit 'end'
    , @options.delay_round

  _progress_pot: ->
    @_board.pot(
      @players().map (player)-> { bet: player.bet_pot(), fold: player.fold, position: player.position}
    )

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
    @_cards.pop()
    @emit 'progress', {
      cards: if 1 is @_progress_round then [@_cards.pop(), @_cards.pop(), @_cards.pop()] else [@_cards.pop()]
    }
    @_waiting = @_dealer
    callback.bind(this)(callback)

  _get_ask: ->
    if !@_timeout_activity_callback
      return null
    [{
      position: @_waiting
      timeout: @_activity_timeout_left()
    }, {
      id: @_players[@_waiting].id
      commands: @_waiting_commands()
    }]

  _emit_ask: (player)->
    @_waiting = player
    if @_players[@_waiting].sitout
      return @turn()
    @_activity()
    @emit.apply(@, ['ask'].concat(@_get_ask()))

  _waiting_commands: ->
    @_players[@_waiting].commands({
      bet_max: @_board.bet_max()
      bet_raise: @_board.bet_raise()
    })

  turn: (command)->
    if !command
      command = @_waiting_commands()[0]
      @_players[@_waiting].sit({out: true})
    if !@_players[@_waiting].turn({
      bet_max: @_board.bet_max()
      bet_raise: @_board.bet_raise()
      }, command)
      return
    @_activity_clear()
    @_progress()

  sit: ({user_id, out})->
    @_players[@_players_ids[user_id]].sit({out})

  waiting: -> @_players[@_waiting].id

  toJSON: ->
    json =
      players: @_players.map (p)-> p and p.toJSON()
      board: @_board.toJSON()
      dealer: @_dealer
      progress: @_progress_round
      blinds: @_blinds
    ask = @_get_ask()
    if ask
      json.ask = ask
    json
