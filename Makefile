changelog:
	-!(which conventional-changelog) && npm i -g conventional-changelog-cli
	conventional-changelog -p angular -i CHANGELOG.md -s -r 0

yard_server:
	open http://localhost:8808
	yard server --reload

.PHONY: all
