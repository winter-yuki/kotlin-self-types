\ProvidesClass{itmo-diploma}[2019/05/18 ITMO LaTeX diploma class]
\newcommand{\my@baseclass}{extarticle}
\newcommand{\my@fontsize}{14pt}
\LoadClass[a4paper,\my@fontsize]{\my@baseclass}

% Супиржрапхикс
\usepackage{tikz}
\usetikzlibrary{positioning, calc}
\usetikzlibrary{arrows.meta}
\usetikzlibrary{shapes,arrows}

% Поиск и копипаст по pdf
\usepackage{cmap}

% Русский язык
\usepackage[T2A]{fontenc}
\usepackage[utf8]{inputenc}
\usepackage[english,russian]{babel}
\selectlanguage{russian}

\usepackage[normalem]{ulem}
\useunder{\uline}{\ul}{}

\usepackage{pscyr}
\usepackage{subcaption}

% Альбомная ориентация
\usepackage{pdflscape}

% Times New Roman для русского языка
\renewcommand{\rmdefault}{ftm}

% Полуторный межстрочный интервал
\linespread{1.5}

% Правильные поля для диплома (есть какие-то доп. сдвиги, поэтому
% 20mm для левого края — это нормально)
\usepackage[top=20mm, bottom=20mm, left=25mm, right=10mm]{geometry}

\addto\captionsrussian{
% подпись "Рисунок", а не "Рис"
    \def\figurename{{Рисунок}}
    % СОДЕРЖАНИЕ прописными буквами
    \renewcommand{\contentsname}{СОДЕРЖАНИЕ}
}

% Содержание должно быть с отточием
\usepackage{titletoc}
\dottedcontents{section}[1.5em]{}{2.3em}{1pc}

% Дабы рисунок не уезжал в чужую секцию
\usepackage[section]{placeins}

% Максимальная вложенность содержания (только разделы, подразделы и
% "пункты")
\setcounter{tocdepth}{3}

% Содержание должно начинаться на 4 странице
\setcounter{page}{4}

% Возможность переопределять оглавление и его стиль
\usepackage[titles]{tocloft}

% Формат заголовков (\hspace должен совпадать с размером абзацного
% отступа)
\usepackage{titlesec}
\titleformat{\section}[block]{}
{\arabic{section}}{1ex}{}
\titleformat{\subsection}[block]{}
{\arabic{section}.\arabic{subsection}}{1ex}{}
\titleformat{\subsubsection}[block]{}
{\arabic{section}.\arabic{subsection}.\arabic{subsubsection}}{1ex}{}
\titleformat*{\section}{\centering\bfseries\large}
\titleformat*{\subsection}{\hspace{1.25cm}\bfseries\normalsize}
\titleformat*{\subsubsection}{\hspace{1.25cm}\bfseries\normalsize}
\titlespacing*{\section}      {0pt}{4.5ex plus 1ex minus .2ex}{4.5ex plus .2ex}
\titlespacing*{\subsection}   {0pt}{3.25ex plus 1ex minus .2ex}{1.5ex plus .2ex}
\titlespacing*{\subsubsection}{0pt}{3.25ex plus 1ex minus .2ex}{1.5ex plus .2ex}

% Номер страницы по середине страницы сверху
\usepackage{fancyhdr}
\pagestyle{fancy}
\fancyhf{}
\fancyhead[C]{\thepage}
\renewcommand{\headrulewidth}{0pt}

% Экзотические цвета (оранжевый, фиолетовый и др.)
\usepackage{xcolor}

% Поддержка гиперссылок внутри pdf
\usepackage[hyphens]{url}
\usepackage[pdftex, breaklinks]{hyperref}
\hypersetup{
    unicode=true,
    pdftitle={
        },
    pdfauthor={},
    pdfkeywords={
        },
    colorlinks,
    citecolor=black,
    filecolor=black,
    linkcolor=black,
    urlcolor=blue
}

% Цитатки, сжимающиеся из [1,2,3,4] в [1-4]
\usepackage[numbers,sort&compress]{natbib}

% Стиль нумерования в списке использованных источников: [1] -> 1.
\makeatletter
\renewcommand\@biblabel[1]{#1.}
\makeatother

% Пробел в качестве разделителя между [Таблица Х] и "Лэйбл таблицы"
% Нахера пробел-то если по требованиям длинное тире
\usepackage{caption}

\DeclareCaptionLabelSeparator{emdash}{ --- }
\captionsetup[figure]{labelsep=emdash}
\captionsetup[table]{labelsep=emdash, singlelinecheck=false}
% Нумерация таблиц и формул в пределах раздела
\makeatletter
\@addtoreset{equation}{section}
\@addtoreset{table}{section}
\makeatother
\renewcommand{\theequation}{\arabic{section}.\arabic{equation}}
\renewcommand{\thetable}{\arabic{table}}

% Нумерация изображений и таблиц сквозная
\renewcommand{\thefigure}{\arabic{figure}}
\renewcommand{\thetable}{\arabic{table}}

% Меняем везде перечисления на цифра.цифра
% \renewcommand{\theenumi}{\arabic{enumi}}
% \renewcommand{\labelenumi}{\arabic{enumi}}
% \renewcommand{\theenumii}{.\arabic{enumii}}
% \renewcommand{\labelenumii}{\arabic{enumi}.\arabic{enumii}}
% \renewcommand{\theenumiii}{.\arabic{enumiii}}
% \renewcommand{\labelenumiii}{\arabic{enumi}.\arabic{enumii}.\arabic{enumiii}}

% Красивый маркер списка в виде дефиса
\usepackage{enumitem}
\setlist[enumerate]{topsep=0pt,itemsep=0ex,partopsep=1ex,parsep=1ex}
\setlist[itemize]{itemsep=0ex}
\def\labelitemi{--}

% Использовать абзацный отступ и для первых абзацев в
% section/subsection
\usepackage{indentfirst}

% Абзацный отступ равен 1.25 см (где-то ещё есть хардкод с 1.25 см по
% преамбуле, так что менять нужно будет и тут, и там)
\parindent=1.25cm

% Возможность вставлять таблицы и рисунки непосредственно там, где
% они определены (аргумент [H])
\usepackage{float}

% Вставка листингов кода
\usepackage{minted}
\setminted{
    fontsize=\footnotesize,
    baselinestretch=1.2,
    linenos,
    frame=lines
}
\setminted[json]{
    fontsize=\footnotesize,
    baselinestretch=1.2,
    linenos=false,
    frame=lines
}

% Pandoc-specific
\def\tightlist{}
\usepackage{multirow}
\usepackage{longtable}
\usepackage{booktabs}

% Переносить слова иногда даже не по правилам, лишь бы поля
% соблюдались, ибо это важно
\tolerance 1414
\hbadness 1414
\emergencystretch 0em
\hfuzz 0.3pt
\widowpenalty=10000
\vfuzz \hfuzz
\raggedbottom

% Разрешить перенос слов в URL'ах после любой буквы
\expandafter\def\expandafter\UrlBreaks\expandafter{\UrlBreaks%  save the current one
\do\a\do\b\do\c\do\d\do\e\do\f\do\g\do\h\do\i\do\j%
\do\k\do\l\do\m\do\n\do\o\do\p\do\q\do\r\do\s\do\t%
\do\u\do\v\do\w\do\x\do\y\do\z\do\A\do\B\do\C\do\D%
\do\E\do\F\do\G\do\H\do\I\do\J\do\K\do\L\do\M\do\N%
\do\O\do\P\do\Q\do\R\do\S\do\T\do\U\do\V\do\W\do\X%
\do\Y\do\Z}
