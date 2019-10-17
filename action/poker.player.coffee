PokerPlayer = require('../poker/poker.player').PokerPlayer
PokerActionCards = require('./cards.action').PokerActionCards


module.exports.PokerActionPlayer = class PokerActionPlayer extends PokerPlayer
  Rank: require('./rank').PokerActionRank
  options_default: Object.assign {}, PokerPlayer::options_default, {
    energy: 10
    energy_max: 15
    energy_increase: 2
    energy_increase_win: 3
    actions: []
    actions_available: Object.keys(PokerActionCards)
    actions_start: 1
    actions_max: 3
    actions_active: []
  }
  options_round_reset: PokerPlayer::options_round_reset.concat(['actions_active'])

  round: (params)->
    energy_added = 0
    if @options.rounds > 0
      energy_added = if @options.win > 0 then @options.energy_increase_win else @options.energy_increase
      if energy_added + @options.energy > @options.energy_max
        energy_added = @options.energy_max - @options.energy
    super Object.assign({}, params, {
      actions: @options.actions.concat(params.actions)
      actions_added: params.actions
      energy: @options.energy + energy_added
      energy_added
    })

  commands: (params)->
    raise = Math.floor(if params.progress > 0 then (params.pot + params.bet_total) * 0.4 else params.blind * 1.5)
    if raise > params.bet_raise
      params.bet_raise = raise
    commands = super(params)
    if commands.length < 2
      return commands
    if commands.length > 2 and @options.bet > params.blind
      commands = [commands[0], commands[1]]
    commands.map (c)-> c.slice(0, 2)


  turn_action: ({action, energy})->
    @options_update {energy: @options.energy - energy, actions: @options.actions.filter (a)-> a != action}


  toJSON: (user_id)->
    Object.assign(
      super ...arguments
      if @options.id isnt user_id then {actions: @options.actions.map -> ''}
    )
