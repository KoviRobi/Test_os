\def\centretable#1{ \hbox to \hsize {\hfill\vbox{
                    \offinterlineskip \tabskip=0pt \halign{#1} }\hfill} }
\def\techref{{\sl ARM1176JZF-S Technical Reference Manual}}
\def\techsec#1{{\sl ARM1176JZF-S Technical Reference Manual}\rm, section #1}

\font\largerm=cmr17

\def\desc#1. {\noindent{\bf#1.} }

% To disable box around verbatim text, use \verbboxfalse
\newif\ifverbbox
\def\vb#1{
\ifverbbox
    \leavevmode\hbox{\kern2pt\vrule\vtop{\vbox{\hrule
            \hbox{\strut\kern2pt\.{#1}\kern2pt}}
          \hrule}\vrule\kern2pt}
\else
    \leavevmode\hbox{\tentex %typewriter type
    \let\\=\BS % backslash in a string
    \let\{=\LB % left brace in a string
    \let\}=\RB % right brace in a string
    \let\~=\TL % tilde in a string
    %\let\ =\SP % space in a string
    \let\_=\UL % underline in a string
    \let\&=\AM % ampersand in a string
    \let\^=\CF % circumflex in a string
    #1}
\fi
} % verbatim string

% We automatically set \verbboxtrue after each section
\def\MN#1{\verbboxtrue\par % common code for \M, \N
  {\xdef\secstar{#1}\let\*=\empty\xdef\secno{#1}}% remove \* from section name
  \ifx\secno\secstar \onmaybe \else\ontrue \fi
  \mark{{{\tensy x}\secno}{\the\gdepth}{\the\gtitle}}}

% Just some hackery to get the typesetting look better. It was just
% determined experimentally, nothing exciting
@s __attribute__ static @s naked static @s aligned static
@s interrupt static @s asm static @s volatile static
@s uint8_t int @s int8_t int @s uint32_t int @s int32_t int
