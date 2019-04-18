test_server :
	 # --watch --watch-extensions coffee
	./node_modules/mocha/bin/mocha --reporter dot --require coffeescript/register "./poker/test/*.coffee"
	./node_modules/mocha/bin/mocha --reporter dot --require coffeescript/register "./action/test/*.coffee"
