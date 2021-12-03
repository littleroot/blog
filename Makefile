.PHONY: b pub s

b:
	bundle exec jekyll b

s:
	bundle exec jekyll s

pub:
	git add -A
	git commit -m "pub"
	git push
