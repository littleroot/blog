.PHONY: b p s

b:
	bundle exec jekyll b

s:
	bundle exec jekyll s

p:
	git add -A
	git commit -m "auto-generated commit by 'make p'"
	git push
