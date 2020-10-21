rm -f lista*

lftp <<FTP
open ediac.correios.com.br
user detokio Ab1234\>=
cd cedo
ls > lista 
exit
FTP 
