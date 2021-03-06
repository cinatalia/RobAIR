#!/bin/bash

if [ ! -f .robair ]; then
	echo "Vous devez être dans le répertoire root du dépot"
	echo "Et exécuter scripts/install.sh"
	exit
fi

export ROBAIR_HOME=`pwd`

##########################################
# Configuration du ~/bashrc
# et création des variables d'environement correspondantes
##########################################

testbash=`cat ~/.bashrc | grep ROBAIR`
if [[ -z $testbash ]]; then
	read -r -p "Configurer ~/bashrc ? [O/n] "
	if [[ $REPLY  =~ ^[Oo]$ ||  $REPLY =~ ^$ ]]; then
		echo "" >> ~/.bashrc
		echo "#ROBAIR SETTINGS" >> ~/.bashrc
		echo "export ROBAIR_HOME=$ROBAIR_HOME" >> ~/.bashrc
		echo "source \$ROBAIR_HOME/scripts/env.bash"  >> ~/.bashrc
	fi
fi

# Récupère l'IP actuel du Robair
export ROBAIR_IP=`ip route get 8.8.8.8 | awk 'NR==1 {print $NF}'`
export PATH="$PATH:$ROBAIR_HOME/scripts/"

# Met à jour ROBAIR_HOME dans les fichiers de configuration
./scripts/changehome.bash

if [ -z $http_proxy ]; then
	read -r -p "Veuillez entrer votre proxy ou tapez entrée si vous n'en avez pas:" response
	if [ ! -z "$response" ]; then
		export http_proxy=$response
		git config --global http.proxy $http_proxy
	fi
fi

if [ -z $https_proxy] && [ ! -z $http_proxy ]; then
	read -r -p "Votre proxy https est identique au proxy http ? [O/n] "
	if [[ $REPLY  =~ ^[Oo]$ ||  $REPLY =~ ^$ ]]; then
        	export https_proxy=$http_proxy
	fi
fi


echo "Veuillez entrer votre mot de passe pour installer les packages (sudo)"

sudo -E apt-get update


echo "$(tput setaf 1)Installation $(tput setab 7)coturn nodejs npm $(tput sgr0)"
sudo -E apt-get install coturn nodejs-legacy npm chromium-browser

cd $ROBAIR_HOME/interface
npm install

cd $ROBAIR_HOME

read -r -p "Voulez-vous générer une autorité de certification ? [O/n] " response
case $response in
	[nN])
		read -r -p "Copier les fichiers rootCA.crt rootCA.key dans $ROBAIR_HOME/ssl puis appuyer sur entrer " response
		;;
 	*)
		./scripts/createRootCA.bash
		;;
esac


read -r -p "Voulez-vous générer un certificat ssl ? [O/n] "
if [[ $REPLY  =~ ^[Oo]$ ||  $REPLY =~ ^$ ]]; then
	./scripts/createDeviceCRT.bash
fi


read -r -p "Installation ros kinetic ? [O/n] "
if [[ $REPLY  =~ ^[Oo]$ ||  $REPLY =~ ^$ ]]; then

	echo "$(tput setaf 1)Installation $(tput setab 7)ros kinetic$(tput sgr0)"

	sudo sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list'
	sudo -E apt-key adv --keyserver hkp://ha.pool.sks-keyservers.net:80 --recv-key 0xB01FA116
	sudo -E apt-get update
	sudo -E apt-get install ros-kinetic-ros-base
	source /opt/ros/kinetic/setup.bash
	sudo -E rosdep init
	rosdep update
	sudo -E apt-get install ros-kinetic-rosbridge-suite
	source /opt/ros/kinetic/setup.bash

fi

# Récupère les sous-modules
git submodule update --init

# Compile les packages ROS
(cd "$ROBAIR_HOME/catkin_ws" && catkin_make install)
source $ROBAIR_HOME/catkin_ws/devel/setup.bash

# Configure signalmaster
cp $ROBAIR_HOME/configs/signalmaster.json $ROBAIR_HOME/signalmaster/config/development.json
python $ROBAIR_HOME/scripts/editjson.py $ROBAIR_HOME/signalmaster/config/development.json server:key $ROBAIR_HOME/ssl/device.key
python $ROBAIR_HOME/scripts/editjson.py $ROBAIR_HOME/signalmaster/config/development.json server:cert $ROBAIR_HOME/ssl/device.crt
(cd $ROBAIR_HOME/signalmaster && npm install)

echo "$(tput setaf 1)Installation $(tput setab 7)Arduino$(tput sgr0)"
echo "Veuillez vous rendre à l'adresse https://www.arduino.cc/en/Main/Software et télécharger la dernière version de arduino"
echo "Une fois téléchargé veuillez modifier l'emplacement du carnet des croquis dans Fichier->Préférences par $ROBAIR_HOME/arduino"
read -r -p "Veuillez appuyer sur ENTRER une fois l'installation effectuée."
read -r -p "Voulez vous générer la librairie ros_lib pour arduino ? [O/n] "
if [[ $REPLY  =~ ^[Oo]$ ||  $REPLY =~ ^$ ]]; then
	echo "$(tput setaf 1)Genère $ROBAIR_HOME/arduino/libraries/ros_lib$(tput sgr0)"
	mkdir -p $ROBAIR_HOME/arduino/libraries
	cd $ROBAIR_HOME/arduino/libraries
	rm -rf ros_lib
	rosrun rosserial_arduino make_libraries.py .
fi


echo "$(tput setaf 1)Installation terminée$(tput sgr0)"
