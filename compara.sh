rm -f baixar*

for nome in $(cat lista | awk '{ print $9}') 
    do buscaProcessado=`ls processado/$nome 2> /dev/null | wc -l`
    if [ $buscaProcessado -eq 0 ]
     then
        echo "get $nome " >> baixar
    fi    
done

if [ -f baixar ] 
 then
    echo "lftp <<FTP 
open ediac.correios.com.br
user detokio Ab1234\>=
cd cedo " > baixar_script
    cat baixar >> baixar_script
    echo "exit" >> baixar_script
fi

if [ -f baixar_script ] 
 then
    cd baixar_dir
    sh ../baixar_script
    rm -f ../tmp_devolucao 
    rm -f ../tmp_sqlUpdate
    rm -f ../moverProcessados
    for arquivo in $( ls )
        do var=`echo $arquivo | cut -d _ -f2 | cut -c1-8` 
        dia=`echo $var | cut -c1-2` 
        mes=`echo $var | cut -c3-4` 
        ano=`echo $var | cut -c5-8` 
        dataDevolucao=`echo  "$dia/$mes/$ano" `
        for conteudo in $( cat  $arquivo)
            do tipo=`echo $conteudo | cut -c 1,1 `
            if [ $tipo -eq 2 ] 
             then
                cif=` echo $conteudo | cut -c 2-35 `
                motivo=` echo $conteudo | cut -c 36-37 `
                descricaoMotivo=` cat ../motivosCedo | grep $motivo | cut -c4- `
                echo "select * from tokioCedo where CIF = '$cif';" > mysqlRodar
                linha=`mysql -h192.168.0.122 -uroot -pgrafica Tokio 2> /dev/null < mysqlRodar | grep -v CIF | sed "s/\t/|/g"`
                if [ ! -z "$linha" ]
                 then
                    parte1=`echo $linha | cut -d "|" -f 2,3 `
                    parte2=`echo $linha | cut -d "|" -f 5,6,7,8,9,10 `
                    parte3=`echo $linha | cut -d "|" -f 12,13 `
                    linhaRetorno=`echo "$parte1|$dataDevolucao|$parte2|$descricaoMotivo|$parte3" | sed "s/|/;/g" `
                    echo "update tokioCedo set dataDevolucao = '$dataDevolucao' , motivoDevolucao = '$descricaoMotivo' where CIF = '$cif' ;" >> ../tmp_sqlUpdate
                    echo $linhaRetorno >> ../tmp_devolucao 
                fi
                
              #  echo "cif = $cif motivo = $motivo  - $descricaoMotivo - $dataDevolucao "
            fi
        done
        echo "mv baixar_dir/$arquivo processado/$arquivo" >> ../moverProcessados
    done
    cd ..
fi 




if [ -f moverProcessados ]
 then
    mysql -h192.168.0.122 -uroot -pgrafica Tokio 2> /dev/null < tmp_sqlUpdate
    sh moverProcessados
fi

if [ -f tmp_devolucao ]
 then
    dataArquivo=$(date +"%Y%m%d")

    #Montando o acessp
        tentativas=0 
    	while [ ! -d "./remotoTokio/SAIDA" ] && [ $tentativas -lt 4 ] ;
    	do

    		mount.cifs //192.168.1.199/O0055TOKIOMARINE ./remotoTokio -o user=publico.meta,domain=metasolutions.local,pass=grafica*2015,uid=root,user,dir_mode=0777,file_mode=0777,rw
    		((tentativas=$tentativas + 1));

    	done 


 	 if  [ ! -d "./remotoTokio/SAIDA" ] #teste do acesso
    	  then 
      		# erro 
      		echo "falha na montagem" >> log_robo.htm 
    	 else
      		 mv tmp_devolucao Arquivo_devolucao_Meta_$dataArquivo.txt
		 cp Arquivo_devolucao_Meta_$dataArquivo.txt ./Backup/
		 mv Arquivo_devolucao_Meta_$dataArquivo.txt ./remotoTokio/SAIDA
	 fi	 
fi
