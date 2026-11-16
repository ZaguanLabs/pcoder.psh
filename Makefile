.DEFAULT_GOAL := all
.PHONY: all setup native json check test test-fast test-visual benchmark benchmark-startup model-eval compile clean

all: compile
setup native json: check

check:
	psh -fc 'for f in pcoder.psh chat.sh lib/*.zsh scripts/*.zsh tests/*.zsh tests/fixtures/*.zsh; do psh -n "$$f" || exit $$?; done'

test: check
	psh -df tests/run.zsh

test-fast: check
	psh -df tests/run.zsh --fast

test-visual: check
	ZCODER_REQUIRE_VISUALS=1 psh -df tests/picker.zsh
	ZCODER_REQUIRE_VISUALS=1 psh -df tests/document.zsh

benchmark: check
	psh -df tests/benchmark.zsh
benchmark-startup: check
	psh -df tests/startup.zsh --benchmark
model-eval: check
	psh -df tests/model_eval.zsh
compile: check
	psh -fc 'for f in lib/*.zsh; do zcompile -R "$$f" || exit $$?; done'
clean:
	rm -f lib/*.zwc
