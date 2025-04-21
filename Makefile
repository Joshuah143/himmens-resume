make build:
	typst compile new_ac.typ himmens_joshua_academic_resume.pdf
	typst compile new_biz.typ himmens_joshua_buisisness_resume.pdf

make test: build
	uv run python -m pytest -v