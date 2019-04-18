Default = require('./default').Default
cloneDeep = require('lodash').cloneDeep
_pick = require('lodash').pick


module.exports.PokerPlayer = class Player extends Default
  Rank: require('./rank').PokerRank
  options_default:
    id: null
    position: null
    chips: 0
    chips_start: 0
    talked: false
    command: ''
    showdown: false
    cards: []
    cards_board: []
    bet: 0
    win: 0
    turn_history: [[]]
    out: false
    last: false
    rounds: 0
    rounds_out: 0
  options_round_reset: ['talked', 'command', 'showdown', 'cards', 'cards_board', 'bet', 'win', 'turn_history']

  options_bind:
    'cards,cards_board': ->
      cards = @options.cards_board.concat(@options.cards)
      rank = null
      if cards.length isnt 0
        r = new (@Rank)(cards)
        rank = {rank: r._hand_rank, message: r._hand_message}
      @options_update {rank}
    'out': ->
      @emit 'out', {out: @options.out}
      if !@options.out and @options.rounds_out > 0
        @options_update {rounds_out: 0}
    'last': ->
      if !@_remove_safe()
        @emit 'last', {last: @options.last}
    'bet': -> @emit 'bet', {bet: @options.bet}
    'rounds_out': -> @emit 'rounds_out', {rounds_out: @options.rounds_out}

  constructor: (options)->
    super Object.assign({chips_start: options.chips}, options)

  _remove_safe: ->
    if @options.last and (@fold() or @options.cards.length is 0)
      @emit 'remove_safe'
      return true
    return false

  budget: -> @options.chips + @options.win

  round: (params)->
    chips = @options.chips + @options.win
    @options_update Object.assign(
      cloneDeep(_pick(@options_default, @options_round_reset))
      params
      {
        rounds: @options.rounds + 1
        chips_last: chips
        chips
      }, if @options.out then {rounds_out: @options.rounds_out + 1})

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

  progress: ->
    @options.turn_history.push([])
    @options_update Object.assign({
      turn_history: @options.turn_history
      talked: false
    }, if ['fold', 'all_in'].indexOf(@options.command) < 0 then {command: null})

  action_require: (bet_max)-> @options.cards.length is 2 and !@fold() and !@all_in() and (!@options.talked or @options.bet < bet_max)

  out: ({out})-> @options_update {out}

  last: ({last})-> @options_update {last}

  turn: (params, command)->
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

  commands: ({bet_max, bet_raise, cap, stacks})->
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
    cap = if cap and cap <= @options.chips then cap else @options.chips
    commands.push [if bet_max is 0 then 'bet' else 'raise'].concat( if raise >= cap then [cap] else [raise, cap] )
    return commands

  readd: ({chips})->
    @options_update {chips, last: false}
    @emit 'readd', {chips, last: false}

  toJSON: (user_id)->
    Object.assign(
      _pick @options, Object.keys(@options_default).filter( (k)-> ['cards_board'].indexOf(k) is -1 )
      if user_id is @options.id then {hero: true}
      if user_id isnt @options.id and !@options.showdown then { cards: @options.cards.map (c)-> ''  }
    )
