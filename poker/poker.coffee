events = require('events')
Cards = require('./cards').Cards


class Player
  constructor: ({id, chips, position})->
    @id = id
    @chips = chips
    @position = position

  round: ->
    @folded = false
    @talked = false
    @all_in = false
    @cards = []

  toJSON: ->
    {id: @id, chips: @chips, position: @position, folded: @folded, talked: @talked, all_in: @all_in}


module.exports.Poker = class Poker extends events.EventEmitter
  player: Player

  constructor: (@options)-> #{blinds, buy_in}
    @_players = [0...@options.players[1]].map -> null
    @_dealer = -1
    @_cards = new Cards()

  # _activity_clear: ->
  #   clearTimeout @_timeout_callback
  #   clearTimeout @_timeout_activity_callback
  #   @_timeout_callback = null
  #   @_timeout_activity_callback = null
  #
  # _activity: ->
  #   @_last_activity = new Date().getTime()
  #   @_activity_clear()
  #   @_timeout_activity_callback = setTimeout =>
  #     @trigger 'game:noactivity', {user: @waiting()}
  #   , @_timeout * 1000 + 1000
  #
  # wait: ->
  #   if @_timeout_callback or new Date().getTime() - @_timeout * 1000 < @_last_activity
  #     return
  #   @trigger 'game:wait', {user: @waiting(), time: @_timeout}
  #   @_timeout_callback = setTimeout =>
  #     @trigger 'game:timeout', @waiting()
  #   , @_timeout * 1000 + 2000

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

  players: -> @_players.filter (p)-> !!p

  start: ->
    @emit 'start'

  round: ->
    @_cards.shuffle()
    @_board = []
    @_progress = 0

    @players().forEach (p)=> p.round([@_cards.pop(), @_cards.pop()])

    @_dealer = @_player_position_next(@_dealer)
    blind_small = @_player_position_next(@_dealer)
    blind_big = @_player_position_next(blind_small)
    @_waiting = @_player_position_next(blind_big)
    @_players[blind_small].bet(@options.blinds[0])
    @_players[blind_big].bet(@options.blinds[1])

  progress: ->
    # ['deal', 'flop', 'turn', 'river']


  # move: ->
