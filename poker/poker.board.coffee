events = require('events')


module.exports.PokerBoard = class Board extends events.EventEmitter
  reset: (params)->
    @_blinds = params.blinds
    @_bet_max = 0
    @_bet_raise = @_blinds[1]
    @_cards = []
    @_pot = []
    @_bet_raise_position = -1
    @_show_first = params.show_first

  bet: ({bet, position})->
    if @_bet_max < bet
      bet_diff = bet - @_bet_max
      if bet_diff > @_bet_raise
        @_bet_raise = Math.ceil(bet_diff / @_blinds[1]) * @_blinds[1]
        @_bet_raise_position = position
      @_bet_max = bet

  bet_max: -> @_bet_max

  bet_raise: -> @_bet_raise

  cards: (cards)->
    @_bet_raise_position = -1
    @_cards.push(cards)
    @emit 'card', cards

  pot: (bets)->
    @_bet_max = 0
    @_bet_raise = @_blinds[1]
    bets.sort (p1, p2)-> p1.bet - p2.bet
    pots = [0...bets.length]
      .map (i)->
        bet = bets[i].bet
        if bet is 0
          return null
        return bets.reduce (acc, v, j)->
          if v.bet >= bet
            bets[j].bet -= bet
            acc.pot += bet
            acc.positions.push(v.position)
            acc.positions.sort()
          return acc
        , {pot: 0, positions: []}
      .filter (v)-> v isnt null
    pots.forEach (pot)=>
      if pot.positions.length is 1
        return @emit 'pot:return', {pot: pot.pot, position: pot.positions[0]}
      for i in [0...@_pot.length]
        if pot.positions.join('') is @_pot[i].positions.join('')
          @_pot[i].pot += pot.pot
          return
      @_pot.push pot

  pot_devide: (winners_order)->
    winners_total = winners_order.reduce ((acc, v)-> acc + v.length), 0
    @_pot.map (pot)=>
      for winners_list, j in winners_order
        winners = pot.positions.filter (position)-> winners_list.indexOf(position) >= 0
        if winners.length is 0
          continue
        pot.winners = winners.slice(0)
        do ->
          if pot.winners.length is 1
            pot.winners_pot = [pot.pot]
            return
          pot_win = Math.round( pot.pot / pot.winners.length )
          pot.winners_pot = pot.winners.map -> pot_win
          pot.winners_pot[0] += pot.pot - (pot_win * pot.winners.length)
        pot.showdown = []
        if winners_total > 1
          max_position = Math.max.apply(null, pot.positions)
          show = if pot.positions.indexOf(@_bet_raise_position) >= 0 then @_bet_raise_position else @_show_first
          while winners.indexOf(show) is -1
            if pot.positions.indexOf(show) >= 0
              pot.showdown.push(show)
            show++
            if show > max_position
              show = 0
          pot.showdown = pot.showdown.concat(winners.filter (winner)-> pot.showdown.indexOf(winner) is -1 )
        return pot
