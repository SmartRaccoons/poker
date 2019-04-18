assert = require('assert')
sinon = require('sinon')
proxyquire = require('proxyquire')

Card = require('../card').CardParam


class PokerRank
  constructor: (@options)->


PokerActionRank = proxyquire('../rank', {
  '../poker/rank': { PokerRank }
}).PokerActionRank


describe 'PokerActionRank', ->
  p = null

  it 'default', ->
    c1 = new Card('1a')
    c2 = new Card('2b')
    c3 = new Card('3d')
    c1.check = sinon.fake.returns true
    c2.check = sinon.fake.returns false
    c3.check = sinon.fake.returns false
    p = new PokerActionRank([c1, c2, c3])
    assert.equal 1, c1.check.callCount
    assert.equal 'p', c1.check.getCall(0).args[0]
    assert.deepEqual ['2b', '3d'], p.options
