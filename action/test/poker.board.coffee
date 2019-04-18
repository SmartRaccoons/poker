assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')


class PokerBoard
  constructor: (@options)->

PokerActionBoard = proxyquire('../poker.board', {
  '../poker/poker.board': { PokerBoard }
}).PokerActionBoard


describe 'PokerActionBoard', ->
  spy = null
  p = null
  beforeEach ->
    spy = sinon.spy()
    p = new PokerActionBoard({})
    p.options_update = sinon.spy()

  it 'default', ->
    assert.deepEqual([], p.options_default.actions)

  it 'turn_action', ->
    p.options.actions = [{action: 'b'}]
    p.turn_action {action: 'a', position: 2}
    assert.equal 1, p.options_update.callCount
    assert.deepEqual [{action: 'b'}, {action: 'a', position: 2}], p.options_update.getCall(0).args[0].actions

  it '_bet_raise_calc', ->
    p.options.blinds = [1, 3]
    assert.equal 5, p._bet_raise_calc(5)

  it 'toJSON', ->
    PokerBoard::toJSON = sinon.fake.returns {'a': 'b'}
    p.options.actions = 'ac'
    assert.deepEqual {a: 'b', actions: 'ac'}, p.toJSON()
