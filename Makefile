test_server :
	 # --watch --watch-extensions coffee
	mocha --reporter dot --require coffee-script/register "./poker/test/*.coffee"
