Rank = require('./rank').PokerRank
events = require('events')


module.exports.PokerPlayer = class Player extends events.EventEmitter
  constructor: ({id, chips, position})->
    super()
    @id = id
    @chips = chips
    @position = position
    @reset()

  budget: -> @chips + @_win

  round: (cards)->
    @chips = @chips_last = @chips + @_win
    @reset()
    @cards = cards
    @_rank_calculate()

  _rank_calculate: ->
    @_rank = new Rank(@cards.concat(@cards_board))

  rank: -> { rank: @_rank._hand_rank, message: @_rank._hand_message }

  showdown: ->
    @_showdown = true
    @cards.slice(0)

  reset: ->
    @fold = false
    @talked = false
    @all_in = false
    @_showdown = false
    @cards = []
    @cards_board = []
    @_bet = 0
    @_win = 0
    @_turn_history = [[]]

  filter: (params)->
    for k, v of params
      if @[k] != v
        return false
    return true

  bet: (params)->
    if not params.blind
      @talked = true
    bet = if params.bet >= @chips then @chips else params.bet
    @_bet += bet
    @chips -= bet
    if @chips is 0
      @all_in = true
    @emit 'bet', {bet: @_bet}
    return bet

  bet_return: ({bet})->
    @all_in = false
    @_bet -= bet
    @chips += bet
    @emit 'bet_return', {bet}

  bet_pot: ->
    bet = @_bet
    @_bet = 0
    return bet

  win: ({win}, silent)->
    @_win += win
    if not silent
      @emit 'win', {win}

  progress: ({cards})->
    @talked = false
    @cards_board = @cards_board.concat(cards)
    @_rank_calculate()
    @_turn_history.push([])

  action_require: (bet_max)-> !@fold and !@all_in and (!@talked or @_bet < bet_max)

  sit: ({out})->
    if @sitout isnt out
      @emit 'sit', {out}
    @sitout = out

  turn: (bets, command)->
    if !command
      return false
    params = @commands(bets).filter( (c)-> c[0] is command[0] )[0]
    if !params
      return false
    bet_change = 0
    {
      fold: => @fold = true
      check: => @bet({bet: 0})
      call: => bet_change = @bet({bet: params[1]})
      raise: =>
        bet = parseInt(command[1])
        if !(params.length is 3 and bet and (params[1] <= bet <= params[2]))
          bet = params[1]
        bet_change = @bet({bet})
    }[if command[0] is 'bet' then 'raise' else command[0]]()
    do =>
      if @all_in
        letter = 'a'
      else if command[0] is 'check'
        letter = 'x'
      else
        letter = command[0].substr(0, 1)
      @_turn_history[@_turn_history.length - 1].push letter
    @emit 'turn', Object.assign({
      command: if @all_in then 'all_in' else command[0]
      }, if ['call', 'raise', 'bet'].indexOf(command[0]) >= 0 then {bet: bet_change})
    return true

  commands: ({bet_max, bet_raise})->
    commands = []
    commands.push(if @_bet >= bet_max then ['check'] else ['fold'])
    call = bet_max - @_bet
    if @_bet < bet_max
      commands.push(['call', if call > @chips then @chips else call])
    if call < @chips
      if call < 0
        call = 0
      raise = call + bet_raise
      commands.push [if bet_max is 0 then 'bet' else 'raise'].concat( if raise > @chips then [@chips] else [raise, @chips] )
    return commands

  toJSON: ->
    {
      id: @id
      chips: @chips
      bet: @_bet
      win: @_win
      position: @position
      fold: @fold
      talked: @talked
      all_in: @all_in
      sitout: !!@sitout
      cards: if @_showdown then @cards else @cards.map (c)-> ''
      turn_history: @_turn_history
    }
