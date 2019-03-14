Rank = require('./rank').PokerRank
events = require('events')

class Default extends events.EventEmitter
  constructor: (options)-> #({id, chips, position})->
    super()
    @options = Object.assign @_options_default(), options
    @_options_bind_parsed = Object.keys(@_options_bind).reduce (acc, v)=>
      acc.concat { events: v.split(','), fn: @_options_bind[v].bind(@) }
    , []

  options_update: (options)->
    updated = Object.keys(options)
    Object.assign @options, options
    @_options_bind_parsed
    .filter (v)->
      updated.filter( (up)-> v.events.indexOf(up) >= 0 ).length > 0
    .forEach (v)->
      v.fn()


module.exports.PokerPlayer = class Player extends Default
  _options_default: ->
    talked: false
    command: ''
    showdown: false
    cards: []
    cards_board: []
    bet: 0
    win: 0
    turn_history: [[]]

  _options_bind:
    'cards,cards_board': ->
      cards = @options.cards_board.concat(@options.cards)
      rank = null
      if cards.length isnt 0
        r = new Rank(cards)
        rank = {rank: r._hand_rank, message: r._hand_message}
      @options_update {rank}
    'out': -> @emit 'out', {out: @options.out}
    'last': ->
      if !@_remove_safe()
        @emit 'last', {last: @options.last}
    'bet': -> @emit 'bet', {bet: @options.bet}

  constructor: (options)->
    super(Object.assign {chips_start: options.chips, rounds: 0}, options)

  _remove_safe: ->
    if @options.last and (@fold() or @options.cards.length is 0)
      @emit 'remove_safe'
      return true
    return false

  budget: -> @options.chips + @options.win

  round: (cards)->
    chips = @options.chips + @options.win
    @options_update Object.assign(@_options_default(), {
      rounds: @options.rounds + 1
      chips_last: chips
      chips
      cards
    })

  rank: -> @options.rank

  showdown: ->
    @options_update {showdown: true}
    @options.cards.slice(0)

  filter: (params)->
    for k, v of params
      if @[k]() != v
        return false
    return true

  all_in: -> @options.command is 'all_in'

  fold: -> @options.command is 'fold'

  id: -> @options.id

  bet: ({bet, command})->
    bet = if bet >= @options.chips then @options.chips else bet
    @options_update Object.assign({
      command: if bet is @options.chips then 'all_in' else command
      bet: @options.bet + bet
      chips: @options.chips - bet
    }, if command isnt 'blind' then {talked: true} )
    bet

  bet_return: ({bet})->
    @options_update
      bet: @options.bet - bet
      chips: @options.chips + bet
    @emit 'bet_return', {bet}

  bet_pot: ->
    bet = @options.bet
    @options_update {bet: 0}
    bet

  win: ({win}, silent)->
    @options_update {win: @options.win + win}
    if not silent
      @emit 'win', {win}

  progress: ({cards})->
    @options.turn_history.push([])
    @options_update Object.assign({
      cards_board: @options.cards_board.concat(cards)
      turn_history: @options.turn_history
      talked: false
    }, if ['fold', 'all_in'].indexOf(@options.command) < 0 then {command: null})

  action_require: (bet_max)-> @options.cards.length is 2 and !@fold() and !@all_in() and (!@options.talked or @options.bet < bet_max)

  out: ({out})-> @options_update {out}

  last: ({last})-> @options_update {last}

  turn: (bets, command)->
    if !command
      return false
    params = @commands(bets).filter( (c)-> c[0] is command[0] )[0]
    if !params
      return false
    bet = {
      fold: -> 0
      check: -> 0
      call: -> params[1]
      raise: ->
        bet = parseInt(command[1])
        if params.length is 3 and bet and (params[1] <= bet <= params[2])
          return bet
        return params[1]
    }[if command[0] is 'bet' then 'raise' else command[0]]()
    @options.turn_history[@options.turn_history.length - 1].push(
      if command[0] is 'check' then 'x' else command[0].substr(0, 1)
    )
    bet_change = @bet({bet, command: command[0]})
    @emit 'turn', {command: @options.command, bet: bet_change}
    @_remove_safe()
    return true

  commands: ({bet_max, bet_raise, stacks})->
    commands = []
    commands.push(if @options.bet >= bet_max then ['check'] else ['fold'])
    if stacks is 1 and @options.bet >= bet_max
      return commands
    call = bet_max - @options.bet
    if @options.bet < bet_max
      commands.push(['call', if call > @options.chips then @options.chips else call])
    if stacks is 1 or call >= @options.chips
      return commands
    raise = call + bet_raise
    commands.push [if bet_max is 0 then 'bet' else 'raise'].concat( if raise >= @options.chips then [@options.chips] else [raise, @options.chips] )
    return commands

  readd: ({chips})->
    @options_update {chips, last: false}
    @emit 'readd', {chips, last: false}

  toJSON: ->
    params = Object.keys(@_options_default())
      .filter (k)-> ['cards_board'].indexOf(k) is -1
      .concat(['id', 'position', 'chips'])
      .reduce (acc, v)=>
        acc[v] = @options[v]
        acc
      , {out: !!@options.out, last: !!@options.last}

    Object.assign params, if !@options.showdown then { cards: @options.cards.map (c)-> ''  }
