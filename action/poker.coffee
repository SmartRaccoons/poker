Poker = require('../poker/poker').Poker
cloneDeep = require('lodash').cloneDeep
_pick = require('lodash').pick
_merge = require('lodash').merge
_findLastIndex = require('lodash').findLastIndex
PokerActionCards = require('./cards.action').PokerActionCards


_action_cards_assign = (ob)->
  Object.keys(PokerActionCards)
  .reduce (acc, action)->
    Object.assign acc, {[action]: Object.assign({}, PokerActionCards[action], ob[action]) }
  , {}


#card: 'Ah;p,a,r,a,m,s'
#p - removed board card
#w - additional board card
######a - (r - red and b - black)
######s - marked as seered
#k - protected board cards
#h -  hunted card
#i - allin protected board cards


module.exports.PokerAction = class PokerAction extends Poker
  Player: require('./poker.player').PokerActionPlayer
  Board: require('./poker.board').PokerActionBoard
  Cards: require('./cards').CardsParams
  _options_default: Object.assign {}, cloneDeep(Poker::_options_default), {
    timeout_action: 5
  }
  _actions: _action_cards_assign
    'p': #pirate - removes board card
      callbacks: [
        ->
          cards = @_board.options.cards
          indexes = [0...cards.length].filter (index)-> !cards[index].check(['p', 'k', 'i'])
          if indexes.length is 0
            return null
          indexes
        (index)->
          @_board.options.cards[index].mark 'p'
          @_board.options_update {cards: @_board.options.cards}, true
          {index}
      ]
    'w': #wizard - brings board card
      callbacks: [
        null
        ->
          card = @_cards.deal()[0]
          card.mark 'w'
          @_board.options_update {cards: @_board.options.cards.concat(card)}
          {card}
      ]
    'h': #hunter - pickups last board card before discarding one from hand
      callbacks: [
        ->
          cards = @_board.options.cards
          if cards.length is 0 or cards[cards.length - 1].check ['p', 'k']
            return false
          [0, 1]
        (index)->
          board_index = @_board.options.cards.length - 1
          @_board.options.cards[board_index].mark('h')
          @_players[@_waiting].options_update
            cards: (@_players[@_waiting].options.cards
              .filter (c, i)-> i isnt index
              .concat @_board.options.cards[board_index]
            )
          @_board.options_update
            cards: @_board.options.cards.filter (c, i)-> i isnt board_index
          [
            null
            {index}
          ]
      ]
#     'a': #alchemist - reads color of opponent cards
#       callbacks: [
#         ->
#           @_opponents()
#           .filter (p)-> !p.options.turn_a
#           .length > 0
#         ->
#           cards = @_opponents()
#           .forEach (p)->
#             p.options_update({turn_a: true})
#           .reduce (acc, p)->
#             Object.assign acc, {[p.options.id]: p.cards_color()}
#           , {}
#           cards
#       ]
    's': #seer - read next deck card
      callbacks: [
        null
        ->
          @_players[@_waiting].options_update
            actions_active: @_players[@_waiting].options.actions_active.concat('s')
          [
            null
            {card: @_cards.next()}
          ]
      ]
      active_on: ['deal']
      active: ->
        card = @_cards.next()
        positions = @players()
        .filter (p)-> 's' in p.options.actions_active
        .map (o)-> o.options.position
        if positions.length is 0
          return null
        [
          {positions}
          positions.reduce( (acc, position)=>
            Object.assign acc, {[@_players[position].options.id]: {card}}
          , {})
        ]
    'f': #frankenstein - gets 3rd card
      callbacks: [
        null
        ->
          card = @_cards.deal()[0]
          @_players[@_waiting].options_update {
            cards: @_players[@_waiting].options.cards.concat(card)
          }
          [
            null
            {card}
            [0, 1, 2]
          ]
        (index)->
          @_players[@_waiting].options_update {
            cards: @_players[@_waiting].options.cards.filter (c, i)-> i isnt index
          }
          [
            null
            {index}
          ]
      ]
    'k': #knight - protects board cards
      callbacks: [
        ->
          @_board.options.cards
          .filter (c)-> !c.check(['p', 'k'])
          .length > 0
        ->
          cards = @_board.options.cards
          [0...cards.length]
          .filter (i)-> !cards[i].check(['p', 'k'])
          .map (i)->
            cards[i].mark('k')
            i
      ]
    'v': #vampire - gets opponent energy
      callbacks: [
        ->
          positions = @_opponents()
          .filter (p)-> p.options.energy > 0
          .map (p)-> p.options.position
          if positions.length is 0
            return false
          positions
        (position)->
          energy = @_players[position].options.energy
          if energy > 3
            energy = 3
          @_players[position].options_update {energy: @_players[position].options.energy - energy}
          @_players[@_waiting].options_update {energy: @_players[@_waiting].options.energy + energy}
          {energy, position}
      ]
    'd': #doctor - gets previous used action card
      callbacks: [
        ->
          @_board.options.actions
          .filter (a)-> a.action isnt 'd' and !a.doctor?
          .length > 0
        ->
          actions = cloneDeep(@_board.options.actions)
          index = _findLastIndex actions, (a)-> a.action isnt 'd' and !a.doctor?
          action = actions[index].action
          actions[index].doctor = @_waiting
          @_board.options_update {actions}
          @_players[@_waiting].options_update {actions: @_players[@_waiting].options.actions.concat(action)}
          {action}
      ]
    't': #thief - steals opponent action card
      callbacks: [
        ->
          positions = @_opponents()
          .filter (p)-> p.options.actions.length > 0
          .map (p)-> p.options.position
          if positions.length is 0
            return false
          positions
        (position)->
          actions = @_players[position].options.actions
          index = Math.floor(Math.random() * actions.length)
          action = actions[index]
          @_players[@_waiting].options_update {actions: @_players[@_waiting].options.actions.concat(action) }
          @_players[position].options_update {actions: @_players[position].options.actions.filter (action, i)-> i isnt index }
          [
            {position}
            [
              [@_waiting, {action}]
              [position, {action}]
            ]
          ]
      ]

  constructor: ->
    super ...arguments
    @_cards.on 'deal', => @_action_active_emit('deal')

  _action_active_emit: (filter = null)->
    params = @_action_active filter
    if params
      @emit 'actions', params[0], params[1]

  _action_active: (filter = null)->
    common = null
    users = null
    Object.keys(@_actions)
    .filter (action)=>
      @_actions[action].active and (!filter or (@_actions[action].active_on and filter in @_actions[action].active_on))
    .forEach (action)=>
      params = @_actions[action].active.bind(@)()
      if !params
        return
      if params[0]
        common = Object.assign {}, common, {[action]: params[0]}
      if params[1]
        if !users
          users = {}
        Object.keys(params[1]).forEach (user)=>
          users[user] = Object.assign {}, users[user], {[action]: Object.assign({}, params[0], params[1][user]) }
    if !common and !users
      return null
    [common, users]

  _action_deal: (available, actions = [], count = 1, max = 1)->
    actions_dealt = []
    while (actions.length + actions_dealt.length) < max and actions_dealt.length < count
      action = available[Math.floor(Math.random() * available.length)]
      if !(action in actions.concat(actions_dealt))
        actions_dealt.push action
    actions_dealt

  _round_player_addon: (p)->
    Object.assign(
      super(...arguments)
      {
        actions: @_action_deal(
          p.options.actions_available,
          p.options.actions,
          if @_round_count is 1 then p.options.actions_start else 1,
          p.options.actions_max
        )
      }
    )

  _emit_round_params: ->
    params = super()
    @players().forEach (p)->
      params[0].players[p.options.position] = Object.assign {}, params[0].players[p.options.position], {
        energy_added: p.options.energy_added
        actions_added: p.options.actions_added.map -> ''
      }
    @players().forEach (p)->
      players_prev = if params[1][p.options.id] then cloneDeep(params[1][p.options.id].players) else []
      params[1][p.options.id] = {players: cloneDeep(params[0].players)}
      params[1][p.options.id].players[p.options.position] = Object.assign(
        {}
        params[0].players[p.options.position]
        players_prev[p.options.position]
        {actions_added: p.options.actions_added}
      )
    params

  _activity_action: ->
    left = @_activity_timeout_left()
    @_activity_clear()
    @_activity (@options.timeout_action + left) * 1000

  _opponents: (position_only = false)->
    opponents = @players({fold: false})
    .filter (p)=> p.options.position isnt @_waiting
    if !position_only
      return opponents
    opponents.map (p)-> p.options.position

  _waiting_commands: ->
    if @_action_required
      return { action_required: ['action', 'callback', 'params'].map (v)=> @_action_required[v] }
    Object.assign super(...arguments), {
      actions: @_actions_get().map (v)-> [v.action].concat( if v.params then [v.params] else [] )
    }

  _actions_get: ->
    energy = @_players[@_waiting].options.energy
    @_players[@_waiting].options.actions.reduce (acc, action)=>
      if energy < @_actions[action].energy
        return acc
      if @_actions[action].callbacks[0]
        params = @_actions[action].callbacks[0].bind(this)()
        if !params
          return acc
      acc.concat Object.assign({action}, if Array.isArray(params) then {params})
    , []

  _action_required_check: (param)->
    if !@_action_required
      return false
    @_activity_action()
    if @_action_required.params
      param = if @_action_required.params[param]? then @_action_required.params[param] else @_action_required.params[@_action_required.params.length - 1]
    params = @_actions[@_action_required.action].callbacks[@_action_required.callback].bind(@)(param)
    if !Array.isArray(params)
      params = [params]
    @emit 'turn_action', Object.assign({
      position: @_waiting
      # timeout: @_activity_timeout_left()
      action: @_action_required.action
      callback: @_action_required.callback
    }, if params[0] then {param: params[0]})
    , if params[1] then (if !Array.isArray(params[1][0]) then [ [null, params[1]] ] else params[1]).reduce( (acc, v)=>
      Object.assign acc, { [@_players[if v[0] is null then @_waiting else v[0]].options.id]: { param: Object.assign({}, params[0], v[1]) } }
    , {})
    @_action_required.callback++
    if @_actions[@_action_required.action].callbacks[@_action_required.callback]
      @_action_required.params = params[2]
    else
      @_action_required = null
    @emit.apply(@, ['ask'].concat(@_get_ask()))
    return true

  turn: ->
    if @_action_required_check()
      return
    super ...arguments

  turn_action: ({action, param})->
    if @_action_required_check(param)
      return
    action_params = @_actions_get().find (a)-> a.action is action
    if !action_params
      return
    @_players[@_waiting].turn_action({action, energy: @_actions[action].energy})
    @_board.turn_action({action, position: @_waiting})
    @_action_required = Object.assign(action_params, {callback: 1})
    @_action_required_check(param)

  toJSON: (user_id)->
    json = super ...arguments
    actions = @_action_active()
    if actions
      json.actions = _merge {}, actions[0], if actions[1] and user_id then actions[1][user_id]
    json
