events = require('events')


module.exports.PokerBoard = class Board extends events.EventEmitter
  constructor: ->
    super()
    @_cards = []
    @_pot = []

  reset: (params)->
    @_blinds = params.blinds
    @_bet_max = 0
    @_bet_raise = @_blinds[1]
    @_cards = []
    @_pot = []
    @_bet_raise_position = -1
    @_show_first = params.show_first

  bet: ({bet, position})->
    if @_bet_max >= bet
      return
    bet_diff = bet - @_bet_max
    if bet_diff > 0
      @_bet_raise_position = position
    if bet_diff > @_bet_raise
      @_bet_raise = Math.ceil(bet_diff / @_blinds[1]) * @_blinds[1]
    @_bet_max = bet

  bet_max: -> @_bet_max

  bet_raise: -> @_bet_raise

  progress: ({cards})->
    @_bet_raise_position = -1
    @_cards = @_cards.concat(cards)

  pot: (bets)->
    @_bet_max = 0
    @_bet_raise = @_blinds[1]
    if bets.length is 0
      return
    bets.sort (p1, p2)-> p1.bet - p2.bet
    [0...bets.length]
      .map (i)=>
        if bets[i].fold
          @_pot.forEach (p)->
            index = p.positions.indexOf bets[i].position
            if index >= 0
              p.positions.splice(index, 1)
        bet = bets[i].bet
        if bet is 0
          return null
        pot = bets.reduce (acc, v, j)->
          if v.bet >= bet
            bets[j].bet -= bet
            acc.pot += bet
            acc.contributors.push({position: v.position, bet})
            if !v.fold
              acc.positions.push(v.position)
          return acc
        , {pot: 0, positions: [], contributors: []}
        pot.contributors.sort (c1, c2)-> c1.position - c2.position
        pot.positions.sort()
        return pot
      .filter (v)-> v isnt null
      .forEach (pot)=>
        if pot.contributors.length is 1
          return @emit 'pot:return', {pot: pot.pot, position: pot.positions[0]}
        for i in [0...@_pot.length]
          if pot.positions.join('') is @_pot[i].positions.join('')
            pot.contributors.forEach (cont)=>
              index = @_pot[i].contributors.findIndex( (c)-> c.position is cont.position )
              if index >= 0
                @_pot[i].contributors[index].bet += cont.bet
                return
              @_pot[i].contributors.push cont
            @_pot[i].pot += pot.pot
            return
        @_pot.push pot
    @emit 'pot:update', @_pot

  pot_devide: (winners_order)->
    winners_total = winners_order.reduce ((acc, v)-> acc + v.length), 0
    winners_all = winners_order.reduce ((acc, v)-> acc.concat(v)), []
    winners_index = (i)->
      for winners_list, j in winners_order
        if winners_list.indexOf(i) >= 0
          return j
      return winners_total + 1
    @_pot.map (pot)=>
      for winners_list, j in winners_order
        winners = pot.positions.filter (position)-> winners_list.indexOf(position) >= 0
        if winners.length is 0
          continue
        do ->
          total = winners.length
          win = Math.round( pot.pot / total )
          pot.winners = winners.map (position)-> {position, win}
          if total > 1
            pot.winners[0].win += pot.pot - win * total
        pot.showdown = []
        if winners_total <= 1 or pot.positions.length is 1
          return pot
        max_position = Math.max.apply(null, pot.positions)
        show = if pot.positions.indexOf(@_bet_raise_position) >= 0 then @_bet_raise_position else @_show_first
        last_best = winners_total
        while winners.indexOf(show) is -1
          if pot.positions.indexOf(show) >= 0 and last_best >= winners_index(show)
            last_best = winners_index(show)
            pot.showdown.push(show)
          show++
          if show > max_position
            show = 0
        pot.showdown = pot.showdown.concat(winners.filter (winner)-> pot.showdown.indexOf(winner) is -1 )
        return pot

  toJSON: -> {pot: @_pot, cards: @_cards}
