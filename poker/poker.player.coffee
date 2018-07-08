Rank = require('./rank').Rank


module.exports.PokerPlayer = class Player
  constructor: ({id, chips, position})->
    @id = id
    @chips = chips
    @position = position

  round: (cards)->
    @reset()
    @cards = cards
    @_rank_calculate()

  board_cards: (cards)->
    @cards_board = @cards_board.concat(cards)
    @_rank_calculate()

  _rank_calculate: ->
    @_rank = new Rank(@cards.concat(@cards_board))

  rank: -> { rank: @_rank._hand_rank, message: @_rank._hand_message }

  reset: ->
    @folded = false
    @talked = false
    @all_in = false
    @cards = []
    @cards_board = []
    @_bet = 0

  filter: (params)->
    for k, v of params
      if @[k] != v
        return false
    return true

  bet: (params)->
    if not params.silent
      @talked = true
    bet = if params.bet >= @chips then @chips else params.bet
    @_bet += bet
    @chips -= bet
    if @chips is 0
      @all_in = true

  win: (chips)->
    @chips += chips

  progress: ->
    bet = @_bet
    @_bet = 0
    return bet

  action_require: (bet_max)-> !@folded and !@all_in and (!@talked or @_bet < bet_max)

  fold: -> @folded = true

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
      commands.push ['raise'].concat( if raise > @chips then [@chips] else [raise, @chips] )
    return commands

  toJSON: ->
    {id: @id, chips: @chips, bet: @_bet, position: @position, folded: @folded, talked: @talked, all_in: @all_in}
