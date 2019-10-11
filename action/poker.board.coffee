PokerBoard = require('../poker/poker.board').PokerBoard
cloneDeep = require('lodash').cloneDeep


module.exports.PokerActionBoard = class PokerActionBoard extends PokerBoard
  options_default: Object.assign {}, PokerBoard::options_default, {
    actions: []
  }
  turn_action: ({position, action})->
    @options_update { actions: @options.actions.concat({position, action}) }

  _bet_raise_calc: (bet_diff)-> bet_diff

  toJSON: ->
    Object.assign super(), {actions: @options.actions}
