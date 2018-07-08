events = require('events')
Cards = require('./cards').Cards
Rank = require('./rank').Rank


module.exports.Poker = class Poker extends events.EventEmitter
  player: require('./poker.player').PokerPlayer
  board: require('./poker.board').PokerBoard

  constructor: (@options)-> #{blinds, buy_in}
    @_players = [0...@options.players[1]].map -> null
    @_dealer = -1
    @_blinds = @options.blinds.slice(0)
    @_cards = new Cards()
    @_board = new (@board)()
    @_board.on 'pot:return', ({pot, position})=>
    @_board.on 'card', (cards)=> @players().forEach (p)-> p.board_cards(cards)

  _activity_clear: ->
    clearTimeout @_timeout_activity_callback

  _activity: ->
    @_timeout_activity_callback = setTimeout =>
      @player_turn(@_waiting_commands()[0])
    , @options.timeout * 1000 + 1000

  _player_position_next: (position, max = @_players.length)->
    for i in [0...@_players.length]
      position = if position + 1 is max then 0 else position + 1
      if @_players[position]
        return position

  _player_free_position: ->
    @_players.indexOf(null)

  player_add: (data)->
    position = @_player_free_position()
    player = new (@player)(Object.assign({position}, data))
    @_players[position] = player
    @emit 'player:add'
    if @players().length is @options.players[0]
      @start()

  _player_remove: (p)->
    @_players[p.position] = null
    @emit 'player:remove', {id: p.id}

  players: (filter)->
    @_players.filter (p)-> if filter then p and p.filter(filter) else p

  start: ->
    @emit 'start'

  round: ->
    @_cards.shuffle()
    @_showdown_call = false
    @_progress = 0
    @players().forEach (p)=> p.round([@_cards.pop(), @_cards.pop()])
    @_dealer = @_player_position_next(@_dealer)
    @_blinds_position = [@_dealer]
    if @players().length > 2
      @_blinds_position[0] = @_player_position_next(@_dealer)
    @_waiting = @_blinds_position[1] = @_player_position_next(@_blinds_position[0])
    @_board.reset({blinds: @_blinds.slice(0), show_first: @_player_position_next(@_dealer)})
    [0, 1].forEach (id)=> @_player_bet({bet: @_blinds[id], silent: true}, @_blinds_position[id])
    @emit 'round', {
      dealer: @_dealer
      blinds: @_blinds_position.map (position)=> {position, bet: @_players[position]._bet}
    }
    @progress()

  _showdown: ->
    @emit 'showdown', @players({folded: false}).map (p)->
      {position: p.position, cards: p.cards}

  _round_end: ->
    players = @players({folded: false})
      .map (p)-> {rank: p.rank().rank, position: p.position}
    if players.length > 1
      players_ranked = Rank::compare(players.map (p)-> p.rank)
      .map (winners)-> winners.map (i)-> players[i].position
    else
      players_ranked = [ [players[0].position] ]
    pots = @_board.pot_devide(players_ranked)
    pots.forEach (pot)=>
      pot.winners.forEach (position, i)=>
        @_players[position].win(pot.winners_pot[i])
    @emit 'round:end', {
      pots: pots.map (p)=>
        p.showdown = p.showdown.map (position)=>
          { 'cards': @_players[position].cards.slice(0), position }
        p
    }
    @players().forEach (p)=>
      if p.chips is 0
        @_player_remove(p)
    if @players().length <= 1
      @emit 'end'

  _progress_pot: ->
    @_board.pot(
      @players().map (player)-> { bet: player.progress(), position: player.position}
      .filter (params)-> params.bet > 0
    )

  progress: (callback = @progress)->
    # ['deal', 'flop', 'turn', 'river', 'showdown']
    if !@_showdown_call
      last = @_waiting
      while true
        last = @_player_position_next(last)
        if @_waiting is last
          break
        if @_players[last].action_require(@_board.bet_max())
          return @_emit_ask(last)
    if @_board.bet_max() > 0
      @_progress_pot()
    if @players({folded: false}).length < 2
      return @_round_end()
    if @players({folded: false, all_in: false}).length < 2
      @_showdown()
      @_showdown_call = true
    @_progress++
    if @_progress is 4
      return @_round_end()
    @_cards.pop()
    if 1 is @_progress
      @_board.cards([@_cards.pop(), @_cards.pop(), @_cards.pop()])
    else
      @_board.cards([@_cards.pop()])
    @_waiting = @_dealer
    callback.bind(this)(callback)

  _emit_ask: (player)->
    @_waiting = player
    @emit 'player:ask', {
      user: @_players[player].id
      commands: @_waiting_commands()
    }
    @_activity()
    #{id: 5, commands: [['fold'/'check'], ['call', 233], ['raise', 555, 300]]}

  _waiting_commands: ->
    @_players[@_waiting].commands({
      bet_max: @_board.bet_max()
      bet_raise: @_board.bet_raise()
    })

  player_turn: (command)->
    if !command
      return
    params = @_waiting_commands().filter( (c)-> c[0] is command[0] )[0]
    if !params
      return
    @_activity_clear()
    {
      fold: => @_players[@_waiting].fold()
      check: => @_player_bet({bet: 0})
      call: => @_player_bet({bet: params[1]})
      raise: =>
        bet = parseInt(command[1])
        if !(params.length is 3 and bet and (params[1] <= bet <= params[2]))
          bet = params[1]
        @_player_bet({bet})
    }[command[0]]()
    @progress()

  _player_bet: (params, position=@_waiting)->
    @_players[position].bet( Object.assign({progress: @_progress}, params) )
    @_board.bet( Object.assign({position, progress: @_progress}, params) )

  # action: -> ({command}) #['bet', 333], #['fold']
