LATEX = pdflatex
TARGETS =  installation_windows.pdf
all:${TARGETS}

%.pdf: %.tex %.aux
	${LATEX} $<

%.aux: %.tex
	${LATEX} $<
installation_windows.pdf: installation_windows.tex

clean:
	rm -f *.aux *.log *.toc *.lof
	rm -f *.bbl *.blg
	rm -f *.nav *.out *.snm
	rm -f *.vrb

mrproper: clean
	rm -f ${TARGETS}

remake: mrproper all
