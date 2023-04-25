all:
	latexmk --xelatex -outdir=out -synctex=1 --shell-escape -bibtex -interaction=nonstopmode diploma.tex

preview: all
	evince out/diploma.pdf

clean:
	rm -rf ./out/
