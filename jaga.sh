#!/bin/bash
#Loome skripti, mis etteantud parameetritega jagab kausta vastavale grupile

#Väljumiskoodid:
#exit 1 - skript ei käivitatud juurkasutaja õigustes
#exit 2 - kausta loomine ebaõnnestus
#exit 3 - grupi loomine ebaõnnestus
#exit 4 - kaust on juba välja jagatud
#exit 5 - smb.conf failis on viga
#exit 6 - vale sisestatud parameetrite arv
KAUST=$1
GRUPP=$2
JAGATUD_KAUST=${3-$KAUST}

#Skipt kontrollib, kas me oleme juurkasutaja õigustes
if [ "$UID" -ne "0" ]
    then
      echo "Skript tuleb käivitada juurkasutaja õigustes"
    exit 1
else
    echo "Oled juurkasutaja õigustes"
fi

#Skript kontrollib samba olemasolu ja paigaldab puudumisel selle 
command -v samba > /dev/null 2>&1
if [ "$?" -ne "0" ] 
  then
    echo "Installin Sambat"
    sudo apt-get update -q && sudo apt-get install -q samba
  else
    echo "Samba on installitud"
fi

#Skript kontrollib, kas sisetatud parameetrite arv on õige
if [ "$#" -lt "2" ] || [ "$#" -gt "3" ]
then
	echo "Kasutamine:"
	echo "$0 kaust grupp [jagatud kaust]"
	exit 6
fi

#Skrip kontrollib kausta olemasolu, mille puudumisel loob selle
if [ ! -d "$KAUST" ]
	then
		echo "Loon kausta $KAUST"
		mkdir $KAUST || ( echo "Kausta loomine ebaõnnestus!" && exit 2 )
	else
		echo "Kaust $KAUST on olemas"
fi

#Skript kontrollib, kas grupp on olemas. Puudumisel loob grupi.
if grep -q "^${GRUPP}:" /etc/group
  then
	  echo "Grupp $GRUPP on olemas" 
  else
    echo "Loon grupi $GRUPP"
	  groupadd $GRUPP || ( echo "Grupi loomine ebaõnnestus!" && exit 3 )
fi

#Konfifailist koopia tegemine
cp /etc/samba/smb.conf /etc/samba/smb.conf.old

#Jagatud kausta leidmise tee(kas kataloogialguses on / märk või ei ole) ja Samba konfifaili lisatavate ridade lisamine 
koopiafaili.
if [ "${KAUST:0:1}" != "/" ]
then
	ASUKOHT=$(pwd)
  #echo "path=$ASUKOHT/$KAUST"
cat >> /etc/samba/smb.conf.old << LOPP
[$JAGATUD_KAUST]
comment=JAGATUD KAUST
path=$ASUKOHT/$KAUST
writable=yes
valid users=@$GRUPP
force group=$GRUPP
browsable=yes
create mask=0664
directory mask=0775
LOPP
else	
	#echo "path=$KAUST"
cat >> /etc/samba/smb.conf.old << LOPP
[$JAGATUD_KAUST]
comment=JAGATUD KAUST
path=$ASUKOHT
writable=yes
valid users=@$GRUPP
force group=$GRUPP
browsable=yes
create mask=0664
directory mask=0775
LOPP
fi
#Kasutades testparm käsku konrollime, kas konfifaili tehtud muudatused on OK ja kas kaust on juba välja jagatud
testparm -s /etc/samba/smb.conf.old > /dev/null 2>&1
if [ $? -eq 0 ]
    then
        grep -Fq "[$JAGATUD_KAUST]" /etc/samba/smb.conf
        if [ $? -eq 0 ]
          then
             echo "Kaust $JAGATUD_KAUST on juba välja jagatud"
             exit 4
          else
            cp /etc/samba/smb.conf.old /etc/samba/smb.conf
            echo "Kirjutan muudatused /etc/samba/smb.conf faili"
        fi 
      
    else
      echo "Viga Samba konfifailis"
      exit 5 
fi

#Teeme teenusele Samba restardi
service smbd restart

